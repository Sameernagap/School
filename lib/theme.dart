import 'package:flutter/material.dart';

/// Colours shared with the Odoo back office: one colour per module.
class AppColors {
  static const indigo = Color(0xFF4F46E5);
  static const night = Color(0xFF1E1B4B);
  static const ground = Color(0xFFF5F5FB);
  static const ink = Color(0xFF1E293B);
  static const muted = Color(0xFF64748B);
  static const line = Color(0xFFE5E7EB);

  static const violet = Color(0xFF7C3AED);
  static const emerald = Color(0xFF059669);
  static const sky = Color(0xFF0284C7);
  static const orange = Color(0xFFEA580C);
  static const pink = Color(0xFFDB2777);
  static const amber = Color(0xFFD97706);
  static const teal = Color(0xFF0D9488);
  static const purple = Color(0xFF9333EA);
  static const lime = Color(0xFF65A30D);
  static const brown = Color(0xFFA16207);
  static const rose = Color(0xFFE11D48);
  static const slate = Color(0xFF475569);
  static const cyan = Color(0xFF0891B2);

  static Color soft(Color c) => c.withAlpha(28);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.indigo, brightness: Brightness.light).copyWith(
    primary: AppColors.indigo,
    surface: Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.ground,
    fontFamily: null,
    visualDensity: VisualDensity.standard,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.line)),
      enabledBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.line)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.indigo, width: 1.6)),
    ),
  );
}

/// Status values from the API -> colour
Color statusColor(String? status) {
  switch (status) {
    case 'present':
    case 'paid':
    case 'approved':
    case 'checked':
    case 'pass':
    case 'returned':
    case 'done':
    case 'submitted':
      return AppColors.emerald;
    case 'absent':
    case 'rejected':
    case 'fail':
    case 'missed':
    case 'lost':
      return AppColors.rose;
    case 'late':
    case 'half_day':
    case 'partial':
    case 'to_approve':
    case 'pending':
    case 'invoiced':
      return AppColors.amber;
    case 'leave':
    case 'upcoming':
    case 'issued':
    case 'draft':
      return AppColors.sky;
    default:
      return AppColors.slate;
  }
}
