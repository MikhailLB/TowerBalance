import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Visual constants for buttons, panels and overlays. The cartoon-y palette
/// matches the painted assets (warm wood + bright sky).
class AppColors {
  static const sky = Color(0xFF87CEEB);
  static const skyDark = Color(0xFF4DA8C7);
  static const wood = Color(0xFF8B5A2B);
  static const woodDark = Color(0xFF5C3A1A);
  static const accent = Color(0xFFFFC233);
  static const danger = Color(0xFFE74C3C);
  static const panel = Color(0xCC1F1F2E);
  static const panelLight = Color(0xFFFFF5DA);
  static const text = Color(0xFFFFF5DA);
  static const textDark = Color(0xFF3B2410);
}

class AppTextStyles {
  static TextStyle title({double size = 38, Color color = AppColors.text}) =>
      GoogleFonts.bangers(
        fontSize: size,
        color: color,
        letterSpacing: 1.2,
        shadows: const [
          Shadow(blurRadius: 4, color: Colors.black54, offset: Offset(2, 2)),
        ],
      );

  static TextStyle button({double size = 22, Color color = AppColors.text}) =>
      GoogleFonts.bangers(
        fontSize: size,
        color: color,
        letterSpacing: 1.5,
        shadows: const [
          Shadow(blurRadius: 2, color: Colors.black45, offset: Offset(1, 1)),
        ],
      );

  static TextStyle body({double size = 16, Color color = AppColors.text}) =>
      GoogleFonts.fredoka(
        fontSize: size,
        color: color,
        fontWeight: FontWeight.w500,
      );

  static TextStyle score({double size = 28, Color color = AppColors.text}) =>
      GoogleFonts.bangers(
        fontSize: size,
        color: color,
        letterSpacing: 1.0,
        shadows: const [
          Shadow(blurRadius: 6, color: Colors.black87, offset: Offset(2, 2)),
        ],
      );
}
