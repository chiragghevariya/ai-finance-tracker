import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../models/transaction.dart';
import '../providers/transaction_provider.dart';
import '../utils/color_utils.dart';
import '../utils/formatters.dart';

/// Screen displaying the full details of a selected transaction.
/// Shows description, type, category, date, extra notes, and the scanned receipt photo.
class TransactionDetailScreen extends StatelessWidget {
  final TransactionModel transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  static void navigate(BuildContext context, TransactionModel transaction) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TransactionDetailScreen(transaction: transaction),
      ),
    );
  }

  Future<void> _confirmAndDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.expense)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final provider = context.read<TransactionProvider>();
      await provider.deleteTransaction(transaction.id);
      if (context.mounted) {
        Navigator.of(context).pop(); // Go back to transactions list
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction deleted')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.isIncome;
    final amountColor = isIncome ? AppColors.income : AppColors.expense;
    final category = transaction.category;
    final circleColor = hexToColor(category?.color);
    final imageUrl = transaction.receiptImageUrl;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.expense),
            tooltip: 'Delete transaction',
            onPressed: () => _confirmAndDelete(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Core Transaction Info Card ---
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    // Large Category Icon
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: circleColor.withOpacity(0.15),
                      child: Text(
                        category?.icon ?? '💼',
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Amount
                    Text(
                      formatSignedMoney(transaction.amount, isIncome: isIncome),
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: amountColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Description
                    Text(
                      transaction.description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    // Metadata Row (Category & Date)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _infoItem(
                          icon: Icons.grid_view_outlined,
                          title: 'Category',
                          value: category?.name ?? 'Uncategorized',
                        ),
                        _infoItem(
                          icon: Icons.calendar_today_outlined,
                          title: 'Date',
                          value: formatDate(transaction.date),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // --- Notes Section ---
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.notes, size: 20, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text(
                          'Notes',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      (transaction.note != null && transaction.note!.trim().isNotEmpty)
                          ? transaction.note!
                          : 'No extra notes added for this transaction.',
                      style: TextStyle(
                        fontSize: 14,
                        color: (transaction.note != null && transaction.note!.trim().isNotEmpty)
                            ? AppColors.textDark
                            : AppColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // --- Receipt Section ---
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 20, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text(
                          'Scanned Receipt',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (imageUrl != null)
                      GestureDetector(
                        onTap: () => _viewFullReceipt(context, imageUrl),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const SizedBox(
                              height: 220,
                              child: Center(child: CircularProgressIndicator()),
                            ),
                            errorWidget: (context, url, error) => Container(
                              height: 220,
                              color: Colors.grey.shade100,
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image_outlined, size: 48, color: AppColors.textMuted),
                                  SizedBox(height: 8),
                                  Text(
                                    'Could not load receipt image',
                                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.camera_alt_outlined, size: 36, color: AppColors.textMuted),
                            SizedBox(height: 8),
                            Text(
                              'No receipt photo attached',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoItem({required IconData icon, required String title, required String value}) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.textMuted),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  void _viewFullReceipt(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('Receipt Photo'),
            leading: const CloseButton(),
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => const CircularProgressIndicator(),
                errorWidget: (context, url, error) => const Icon(Icons.broken_image),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
