import '../utils/parsers.dart';

/// A logged-in user, as returned by /api/me, /api/login, /api/register.
class User {
  final int id;
  final String name;
  final String email;

  /// The user's overall monthly budget. May be null if they never set one.
  /// The API sends this as a string like "1500.00", so we parse it carefully.
  final double? monthlyBudget;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.monthlyBudget,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: toInt(json['id']),
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      monthlyBudget: toDoubleOrNull(json['monthly_budget']),
    );
  }

  /// Returns a copy with some fields changed (handy for local edits).
  User copyWith({String? name, double? monthlyBudget}) {
    return User(
      id: id,
      name: name ?? this.name,
      email: email,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
    );
  }
}
