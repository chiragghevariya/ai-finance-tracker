import 'package:intl/intl.dart';

/// Formatting helpers for money and dates, used across the UI.

final NumberFormat _money = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

/// 1234.5  ->  "$1,234.50"
String formatMoney(double value) => _money.format(value);

/// A signed money string, e.g. "+$50.00" / "-$12.00".
String formatSignedMoney(double value, {required bool isIncome}) {
  final sign = isIncome ? '+' : '-';
  return '$sign${formatMoney(value.abs())}';
}

/// DateTime -> "Jun 5, 2026"
String formatDate(DateTime date) => DateFormat('MMM d, yyyy').format(date);

/// month/year -> "June 2026"
String formatMonthYear(int month, int year) =>
    DateFormat('MMMM yyyy').format(DateTime(year, month));
