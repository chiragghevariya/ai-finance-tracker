import '../config/api_config.dart';
import '../utils/parsers.dart';
import 'category.dart';

/// A single income or expense entry.
/// Named `TransactionModel` to avoid confusion with database "transactions".
class TransactionModel {
  final int id;
  final int? categoryId;
  final String type; // 'income' or 'expense'
  final double amount; // always positive; `type` tells us the direction
  final String description;
  final String? note;
  final DateTime date;
  final String? receiptImage;

  /// The full category object, when the API includes it (it usually does).
  final Category? category;

  // Nullable fields (categoryId, note, receiptImage, category) are optional —
  // they simply default to null when the API omits them.
  TransactionModel({
    required this.id,
    this.categoryId,
    required this.type,
    required this.amount,
    required this.description,
    this.note,
    required this.date,
    this.receiptImage,
    this.category,
  });

  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';

  String? get receiptImageUrl {
    if (receiptImage == null || receiptImage!.isEmpty) return null;
    if (receiptImage!.startsWith('http')) return receiptImage;
    // Replace "/api" suffix with "/storage" to get Laravel public storage path
    final base = ApiConfig.baseUrl.replaceAll('/api', '/storage');
    return '$base/$receiptImage';
  }

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: toInt(json['id']),
      categoryId: toIntOrNull(json['category_id']),
      type: json['type']?.toString() ?? 'expense',
      amount: toDouble(json['amount']),
      description: json['description']?.toString() ?? '',
      note: json['note']?.toString(),
      // Dates arrive as ISO strings like "2026-06-05T00:00:00.000000Z".
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      receiptImage: json['receipt_image']?.toString(),
      category: json['category'] is Map<String, dynamic>
          ? Category.fromJson(json['category'] as Map<String, dynamic>)
          : null,
    );
  }
}
