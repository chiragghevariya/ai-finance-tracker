import '../utils/parsers.dart';

/// A spending/income category, e.g. "Food 🍔".
/// Returned by /api/categories and nested inside each transaction.
class Category {
  final int id;
  final String name;
  final String color; // hex string, e.g. "#FF7043"
  final String icon; // emoji, e.g. "🍔"
  final bool isDefault;

  Category({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
    required this.isDefault,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: toInt(json['id']),
      name: json['name']?.toString() ?? 'Unknown',
      color: json['color']?.toString() ?? '#9E9E9E',
      icon: json['icon']?.toString() ?? '💼',
      isDefault: json['is_default'] == true,
    );
  }
}
