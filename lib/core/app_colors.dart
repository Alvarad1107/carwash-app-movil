import 'package:flutter/material.dart';

/// Colores de la aplicación Sprint Wash.
class AppColors {
  AppColors._();

  // Color principal de la marca
  static const Color kRoyalBlue = Color(0xFF1422B8);
  static const Color kRoyalBlueDark = Color(0xFF0C178C);

  // Colores de fondo
  static const Color background = Colors.white;
  static const Color surfaceLight = Color(0xFFF9FAFB);
  static const Color surfaceGrey = Color(0xFFF3F4F6);

  // Colores de texto
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);

  // Bordes
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderLight = Color(0xFFD1D5DB);

  // Colores de fase/estado
  static const List<Color> coloresFase = [
    Color(0xFFF59E0B), // Pendiente (amber)
    Color(0xFF2563EB), // En proceso (blue)
    Color(0xFF16A34A), // Terminado (green)
  ];

  static const List<Color> fondosFase = [
    Color(0xFFFEF3C7), // Pendiente fondo
    Color(0xFFDBEAFE), // En proceso fondo
    Color(0xFFDCFCE7), // Terminado fondo
  ];

  // Estado colores
  static const Color success = Color(0xFF16A34A);
  static const Color successDark = Color(0xFF15803D);
  static const Color successText = Color(0xFF166534);
  static const Color warning = Color(0xFFB45309);
  static const Color error = Colors.redAccent;
  static const Color errorBg = Color(0xFFFDF2F2);
  static const Color errorText = Color(0xFF991B1B);

  // Bahías
  static const Color bahiaOcupada = Color(0xFFD93829);
  static const Color bahiaLibre = Color(0xFF1E8E3E);
}
