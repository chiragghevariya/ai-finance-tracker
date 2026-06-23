import 'package:flutter/material.dart';

/// Converts a hex colour string from the API (e.g. "#FF7043" or "FF7043")
/// into a Flutter [Color]. Falls back to grey if the string is invalid.
Color hexToColor(String? hex, {Color fallback = const Color(0xFF9E9E9E)}) {
  if (hex == null) return fallback;

  var value = hex.replaceAll('#', '').trim();
  if (value.length == 6) {
    value = 'FF$value'; // add full opacity (alpha) if it wasn't provided
  }
  if (value.length != 8) return fallback;

  final parsed = int.tryParse(value, radix: 16);
  return parsed == null ? fallback : Color(parsed);
}
