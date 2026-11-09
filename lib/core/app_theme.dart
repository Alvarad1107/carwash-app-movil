import 'package:flutter/material.dart';

/// Tema y configuración visual centralizada de Sprint Wash.
class AppTheme {
  AppTheme._();

  /// Color principal de la marca (Royal Blue).
  static const Color kRoyalBlue = Color(0xFF1422B8);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorSchemeSeed: kRoyalBlue,
      scaffoldBackgroundColor: Colors.white,
    );
  }
}
