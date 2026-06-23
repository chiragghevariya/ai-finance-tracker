/// Small helpers to safely read values from JSON.
///
/// The Laravel API sends some numbers as strings (e.g. amount = "25.50",
/// monthly_budget = "1500.00") because of how money is stored. These helpers
/// turn whatever we get (String, num, or null) into the Dart type we want,
/// without crashing.

/// Parse to a double, or null if it can't be parsed.
double? toDoubleOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

/// Parse to a double, defaulting to 0.0 if missing/invalid.
double toDouble(dynamic value) => toDoubleOrNull(value) ?? 0.0;

/// Parse to an int, or null if missing/invalid.
int? toIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

/// Parse to an int, defaulting to 0 if missing/invalid.
int toInt(dynamic value) => toIntOrNull(value) ?? 0;
