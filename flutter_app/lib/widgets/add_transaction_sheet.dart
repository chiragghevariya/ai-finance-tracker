import 'dart:async'; // Timer (for the auto-categorize debounce)
import 'dart:convert'; // base64Encode (for the receipt image)
import 'dart:typed_data'; // Uint8List (the picked image bytes)

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../models/category.dart';
import '../providers/transaction_provider.dart';
import '../services/api_service.dart';
import '../utils/formatters.dart';

/// The bottom sheet for adding a new transaction.
///
/// Phase 4 adds two AI helpers:
///   • a receipt scanner (camera/gallery -> /api/receipt/scan -> auto-fill), and
///   • auto-categorize: 1s after you stop typing the description, it asks the AI
///     to pick a category and shows an "AI suggested" label.
///
/// Open it with `AddTransactionSheet.show(context)`.
class AddTransactionSheet extends StatefulWidget {
  const AddTransactionSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true, // lets the sheet grow above the keyboard
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const AddTransactionSheet(),
    );
  }

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String _type = 'expense'; // 'expense' or 'income'
  DateTime _date = DateTime.now();
  int? _categoryId;
  bool _saving = false;

  // Receipt scanning state
  Uint8List? _receiptBytes; // the picked image (also used for the preview)
  bool _scanning = false;

  // Auto-categorize state
  Timer? _debounce; // fires 1s after the user stops typing the description
  bool _autoCategorizing = false;
  bool _aiSuggested = false; // true when the current category came from the AI

  @override
  void dispose() {
    _debounce?.cancel(); // very important: stop the timer when the sheet closes
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- date

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  // ------------------------------------------------------------ receipt scan

  /// Ask whether to use the camera or the gallery, then pick an image.
  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    // imageQuality + maxWidth keep the upload small.
    final XFile? picked =
        await _picker.pickImage(source: source, imageQuality: 70, maxWidth: 1600);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() => _receiptBytes = bytes);
  }

  /// Send the picked image to the AI and auto-fill the form from the result.
  Future<void> _scanReceipt() async {
    final bytes = _receiptBytes;
    if (bytes == null) return;

    setState(() => _scanning = true);
    final provider = context.read<TransactionProvider>();
    try {
      final base64Image = base64Encode(bytes);
      final data = await provider.scanReceipt(base64Image);
      if (!mounted) return;
      _applyReceiptData(data, provider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt scanned ✓ — review and save')),
      );
    } on ApiException catch (e) {
      // e.g. 503 when the backend's OPENAI_API_KEY isn't set.
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read the receipt.')),
        );
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  /// Fill the form fields from the parsed receipt JSON.
  void _applyReceiptData(Map<String, dynamic> data, TransactionProvider provider) {
    final amount = double.tryParse('${data['total_amount'] ?? ''}');
    final merchant = '${data['merchant_name'] ?? ''}'.trim();
    final parsedDate = DateTime.tryParse('${data['date'] ?? ''}');
    final suggestedId = data['suggested_category_id'];
    final categoryId =
        suggestedId is int ? suggestedId : int.tryParse('${suggestedId ?? ''}');

    setState(() {
      // A receipt is always an expense.
      _type = 'expense';
      if (amount != null) _amountController.text = amount.toStringAsFixed(2);
      if (merchant.isNotEmpty) _descriptionController.text = merchant;
      if (parsedDate != null) _date = parsedDate;
      // Only select the category if it's actually in the user's dropdown list.
      if (categoryId != null && provider.categoryExists(categoryId)) {
        _categoryId = categoryId;
        _aiSuggested = true;
      }
    });
  }

  // -------------------------------------------------------- auto-categorize

  /// Called on every description keystroke: (re)start a 1-second timer.
  void _onDescriptionChanged(String value) {
    _debounce?.cancel();
    final text = value.trim();
    if (text.isEmpty) return;
    _debounce = Timer(const Duration(seconds: 1), () => _autoCategorize(text));
  }

  /// After the debounce, ask the AI to suggest a category.
  /// Fails silently — auto-suggest is just a convenience.
  Future<void> _autoCategorize(String description) async {
    if (!mounted) return;
    setState(() => _autoCategorizing = true);
    final provider = context.read<TransactionProvider>();
    try {
      final id = await provider.suggestCategory(description);
      if (!mounted) return;
      if (id != null && provider.categoryExists(id)) {
        setState(() {
          _categoryId = id;
          _aiSuggested = true;
        });
      }
    } catch (_) {
      // Ignore (e.g. AI not configured) — the user can still pick manually.
    } finally {
      if (mounted) setState(() => _autoCategorizing = false);
    }
  }

  // ------------------------------------------------------------------- save

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final provider = context.read<TransactionProvider>();
    final success = await provider.addTransaction(
      type: _type,
      amount: double.parse(_amountController.text.trim()),
      description: _descriptionController.text.trim(),
      date: _date,
      categoryId: _categoryId,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction saved')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Could not save')),
      );
    }
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<TransactionProvider>().categories;

    return Padding(
      // Push the sheet above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title + camera (receipt scanner) button
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Add transaction',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: _scanning ? null : _pickImage,
                    icon: const Icon(Icons.camera_alt_outlined),
                    tooltip: 'Scan a receipt',
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Receipt image preview + "Scan Receipt" button
              if (_receiptBytes != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _receiptBytes!,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _scanning ? null : _scanReceipt,
                        icon: _scanning
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.document_scanner_outlined),
                        label: Text(_scanning
                            ? 'Reading receipt with AI…'
                            : 'Scan Receipt'),
                      ),
                    ),
                    IconButton(
                      onPressed:
                          _scanning ? null : () => setState(() => _receiptBytes = null),
                      icon: const Icon(Icons.close),
                      tooltip: 'Remove image',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Expense / Income toggle
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                      value: 'expense',
                      label: Text('Expense'),
                      icon: Icon(Icons.arrow_upward)),
                  ButtonSegment(
                      value: 'income',
                      label: Text('Income'),
                      icon: Icon(Icons.arrow_downward)),
                ],
                selected: {_type},
                onSelectionChanged: (selected) =>
                    setState(() => _type = selected.first),
              ),
              const SizedBox(height: 16),

              // Amount
              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '\$ ',
                ),
                validator: (value) {
                  final parsed = double.tryParse(value?.trim() ?? '');
                  if (parsed == null) return 'Enter a valid amount';
                  if (parsed <= 0) return 'Amount must be greater than 0';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description (typing here triggers auto-categorize after 1s)
              TextFormField(
                controller: _descriptionController,
                textCapitalization: TextCapitalization.sentences,
                onChanged: _onDescriptionChanged,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: "e.g. Lunch at McDonald's",
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter a description'
                    : null,
              ),
              const SizedBox(height: 16),

              // Date picker
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(formatDate(_date)),
                ),
              ),
              const SizedBox(height: 16),

              // Category label + AI indicator
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Text('Category',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 13)),
                    const Spacer(),
                    if (_autoCategorizing)
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                              height: 12,
                              width: 12,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 6),
                          Text('Finding…',
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 12)),
                        ],
                      )
                    else if (_aiSuggested)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome,
                                size: 13, color: AppColors.primary),
                            SizedBox(width: 4),
                            Text('AI suggested',
                                style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // Category dropdown
              DropdownButtonFormField<int?>(
                value: _categoryId,
                isExpanded: true,
                decoration: const InputDecoration(hintText: 'Select a category'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('No category'),
                  ),
                  ...categories.map(
                    (Category c) => DropdownMenuItem<int?>(
                      value: c.id,
                      child: Text('${c.icon}  ${c.name}'),
                    ),
                  ),
                ],
                // Manually changing the category clears the "AI suggested" label.
                onChanged: (value) => setState(() {
                  _categoryId = value;
                  _aiSuggested = false;
                }),
              ),
              const SizedBox(height: 24),

              // Save
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text('Save transaction'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
