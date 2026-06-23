import '../utils/parsers.dart';

/// One row of the "spending by category" breakdown returned inside the summary.
class CategorySummary {
  final int? categoryId;
  final String name;
  final String? color; // hex string
  final String? icon; // emoji
  final double total;
  final int count;
  final double percentage; // 0..100

  // categoryId/color/icon can be null (e.g. for uncategorized expenses), so
  // they're optional rather than required.
  CategorySummary({
    this.categoryId,
    required this.name,
    this.color,
    this.icon,
    required this.total,
    required this.count,
    required this.percentage,
  });

  factory CategorySummary.fromJson(Map<String, dynamic> json) {
    return CategorySummary(
      categoryId: toIntOrNull(json['category_id']),
      name: json['name']?.toString() ?? 'Uncategorized',
      color: json['color']?.toString(),
      icon: json['icon']?.toString(),
      total: toDouble(json['total']),
      count: toInt(json['count']),
      percentage: toDouble(json['percentage']),
    );
  }
}

/// The whole monthly summary returned by GET /api/transactions/summary.
class MonthlySummary {
  final int month;
  final int year;
  final double totalIncome;
  final double totalExpense;
  final double balance;
  final List<CategorySummary> byCategory;

  MonthlySummary({
    required this.month,
    required this.year,
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
    required this.byCategory,
  });

  factory MonthlySummary.fromJson(Map<String, dynamic> json) {
    final list = (json['by_category'] as List<dynamic>? ) ?? [];
    return MonthlySummary(
      month: toInt(json['month']),
      year: toInt(json['year']),
      totalIncome: toDouble(json['total_income']),
      totalExpense: toDouble(json['total_expense']),
      balance: toDouble(json['balance']),
      byCategory: list
          .map((e) => CategorySummary.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// An empty summary, used before any data has loaded.
  factory MonthlySummary.empty(int month, int year) => MonthlySummary(
        month: month,
        year: year,
        totalIncome: 0,
        totalExpense: 0,
        balance: 0,
        byCategory: const [],
      );
}
