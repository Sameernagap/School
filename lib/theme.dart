import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colours shared with the Odoo back office: one colour per module.
class AppColors {
  static const indigo = Color(0xFF4338CA);
  static const night = Color(0xFF1B1F3B);
  static const ground = Color(0xFFE8EAFE);
  static const dots = Color(0xFFC3C8F4);
  static const ink = Color(0xFF1B1F3B);
  static const muted = Color(0xFF5B6178);
  static const line = Color(0xFFE3E5F3);
  static const sun = Color(0xFFFFC93C);
  static const coral = Color(0xFFFF8A7A);
  static const teacher = Color(0xFF0F766E);
  static const teacherGround = Color(0xFFDCEFEB);
  static const teacherDots = Color(0xFFA9D6CE);

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
    textTheme: GoogleFonts.nunitoSansTextTheme().apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
    appBarTheme: AppBarTheme(
      titleTextStyle: GoogleFonts.baloo2(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: const BorderSide(color: AppColors.line, width: 1.5),
        backgroundColor: Colors.white,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.sun,
      foregroundColor: AppColors.ink,
    ),
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


/// Rounded display font used for headings (Baloo 2).
TextStyle headingStyle({double size = 20, Color color = AppColors.ink, FontWeight weight = FontWeight.w800}) =>
    GoogleFonts.baloo2(fontSize: size, fontWeight: weight, color: color, height: 1.15);

/// Soft dotted background used behind every screen.
class DottedBackground extends StatelessWidget {
  const DottedBackground({super.key, required this.child, this.teacher = false});

  final Widget child;
  final bool teacher;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: teacher ? AppColors.teacherGround : AppColors.ground),
      child: CustomPaint(
        painter: _DotsPainter(teacher ? AppColors.teacherDots : AppColors.dots),
        child: child,
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  _DotsPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const gap = 18.0;
    for (double y = 9; y < size.height; y += gap) {
      for (double x = 9; x < size.width; x += gap) {
        canvas.drawCircle(Offset(x, y), 1.3, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotsPainter old) => old.color != color;
}
