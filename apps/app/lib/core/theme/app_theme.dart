import 'package:flutter/material.dart';

class BrandColors {
  static const Color turquoise = Color(0xFF18d9ea);
  static const Color violet = Color(0xFF6366f1);
  static const Color deepViolet = Color(0xFF7c3aed);

  static const Color bgPrimaryDark = Color(0xFF0c0a1a);
  static const Color bgPrimaryLight = Color(0xFFf9fafb);

  /// Scaffold background gradient, matching the website (ported from legacy).
  static LinearGradient backgroundGradient(bool isDarkMode) {
    if (isDarkMode) {
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x3318d9ea),
          Color(0x2e0e9bb6),
          Color(0x296366f1),
          Color(0x337c3aed),
        ],
      );
    }
    return const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0x66e0f7fa),
        Color(0x338cfafd),
        Color(0x196366f1),
        Color(0x1900d4ff),
      ],
    );
  }

  /// Brand accent gradient (buttons, highlight cards).
  static LinearGradient brandGradient({
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) {
    return LinearGradient(colors: const [violet, turquoise], begin: begin, end: end);
  }
}

class AppTheme {
  static ThemeData light = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: BrandColors.turquoise,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: BrandColors.bgPrimaryLight,
  );

  static ThemeData dark = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: BrandColors.turquoise,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: BrandColors.bgPrimaryDark,
  );
}
