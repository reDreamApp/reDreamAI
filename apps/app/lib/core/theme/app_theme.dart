import 'package:flutter/material.dart';

class BrandColors {
  static const Color turquoise = Color(0xFF18d9ea);
  static const Color violet = Color(0xFF6366f1);
  static const Color deepViolet = Color(0xFF7c3aed);

  static const Color bgPrimaryDark = Color(0xFF0c0a1a);
  static const Color bgPrimaryLight = Color(0xFFf9fafb);
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
