import 'package:flutter/material.dart';

/// Brand palette shared with the website.
class BrandColors {
  static const turquoise = Color(0xFF18D9EA);
  static const teal = Color(0xFF0E9BB6);
  static const deepTeal = Color(0xFF2A9D8F);
  static const violet = Color(0xFF6366F1);
  static const deepViolet = Color(0xFF7C3AED);
  static const flame = Color(0xFFFF6F00);
  static const flameChip = Color(0xFFFFE0B2);
  static const sun = Color(0xFFE6B313);
}

/// Theme-dependent colours that Material's [ColorScheme] does not model.
class BrandTheme extends ThemeExtension<BrandTheme> {
  const BrandTheme({
    required this.cardBorder,
    required this.muted,
    required this.highlightSurface,
    required this.highlightBorder,
    required this.inverseSurface,
    required this.onInverseSurface,
    required this.assistantBubble,
    required this.userBubble,
    required this.onUserBubble,
    required this.accentGradient,
    required this.headlineGradient,
    required this.heroGradient,
  });

  final Color cardBorder;
  final Color muted;
  final Color highlightSurface;
  final Color highlightBorder;
  final Color inverseSurface;
  final Color onInverseSurface;
  final Color assistantBubble;
  final Color userBubble;
  final Color onUserBubble;
  final LinearGradient accentGradient;
  final LinearGradient headlineGradient;

  /// Backdrop of illustrations, as on the cards of the first app version.
  final LinearGradient heroGradient;

  static const light = BrandTheme(
    cardBorder: Color(0xFFE5E7EB),
    muted: Color(0xFF6B7280),
    highlightSurface: Color(0xFFF0FDFF),
    highlightBorder: Color(0xFFA5EEF5),
    inverseSurface: Color(0xFF0A0A0A),
    onInverseSurface: Colors.white,
    assistantBubble: Color(0xFFEDEDF2),
    userBubble: Color(0xFF0A0A0A),
    onUserBubble: Colors.white,
    accentGradient: _accent,
    headlineGradient: LinearGradient(
      colors: [BrandColors.teal, BrandColors.deepTeal],
    ),
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFA7AFF3), Color(0xFF84E4F0)],
    ),
  );

  static const dark = BrandTheme(
    cardBorder: Color(0xFF2A2A2A),
    muted: Color(0xFFA3A3A3),
    highlightSurface: Color(0xFF0F1A1D),
    highlightBorder: Color(0xFF1B5C68),
    inverseSurface: Colors.white,
    onInverseSurface: Color(0xFF0A0A0A),
    assistantBubble: Color(0xFF262626),
    userBubble: Colors.white,
    onUserBubble: Color(0xFF0A0A0A),
    accentGradient: _accent,
    headlineGradient: LinearGradient(
      colors: [BrandColors.turquoise, Color(0xFF3FC1B0)],
    ),
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF3B4387), Color(0xFF187884)],
    ),
  );

  static const _accent = LinearGradient(
    colors: [Color(0xFF22C1D6), BrandColors.deepTeal],
  );

  static BrandTheme of(BuildContext context) =>
      Theme.of(context).extension<BrandTheme>() ?? light;

  @override
  BrandTheme copyWith() => this;

  @override
  BrandTheme lerp(BrandTheme? other, double t) {
    if (other == null) return this;
    return BrandTheme(
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      highlightSurface: Color.lerp(
        highlightSurface,
        other.highlightSurface,
        t,
      )!,
      highlightBorder: Color.lerp(highlightBorder, other.highlightBorder, t)!,
      inverseSurface: Color.lerp(inverseSurface, other.inverseSurface, t)!,
      onInverseSurface: Color.lerp(
        onInverseSurface,
        other.onInverseSurface,
        t,
      )!,
      assistantBubble: Color.lerp(assistantBubble, other.assistantBubble, t)!,
      userBubble: Color.lerp(userBubble, other.userBubble, t)!,
      onUserBubble: Color.lerp(onUserBubble, other.onUserBubble, t)!,
      accentGradient: LinearGradient.lerp(
        accentGradient,
        other.accentGradient,
        t,
      )!,
      headlineGradient: LinearGradient.lerp(
        headlineGradient,
        other.headlineGradient,
        t,
      )!,
      heroGradient: LinearGradient.lerp(heroGradient, other.heroGradient, t)!,
    );
  }
}

class AppTheme {
  static final ThemeData light = _build(
    brightness: Brightness.light,
    brand: BrandTheme.light,
    scaffold: const Color(0xFFF9FAFB),
    surface: Colors.white,
    primary: BrandColors.teal,
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFDFF7FA),
    onPrimaryContainer: const Color(0xFF064E5A),
    onSurface: const Color(0xFF111827),
    surfaceVariant: const Color(0xFFF3F4F6),
  );

  static final ThemeData dark = _build(
    brightness: Brightness.dark,
    brand: BrandTheme.dark,
    scaffold: const Color(0xFF0A0A0A),
    surface: const Color(0xFF171717),
    primary: BrandColors.turquoise,
    onPrimary: const Color(0xFF00363C),
    primaryContainer: const Color(0xFF0F3A40),
    onPrimaryContainer: const Color(0xFFB8F1F7),
    onSurface: const Color(0xFFFAFAFA),
    surfaceVariant: const Color(0xFF262626),
  );

  static ThemeData _build({
    required Brightness brightness,
    required BrandTheme brand,
    required Color scaffold,
    required Color surface,
    required Color primary,
    required Color onPrimary,
    required Color primaryContainer,
    required Color onPrimaryContainer,
    required Color onSurface,
    required Color surfaceVariant,
  }) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: BrandColors.turquoise,
          brightness: brightness,
        ).copyWith(
          primary: primary,
          onPrimary: onPrimary,
          primaryContainer: primaryContainer,
          onPrimaryContainer: onPrimaryContainer,
          secondary: BrandColors.violet,
          surface: surface,
          onSurface: onSurface,
          onSurfaceVariant: brand.muted,
          surfaceContainerHighest: surfaceVariant,
          surfaceContainerHigh: surfaceVariant,
          surfaceContainer: surfaceVariant,
          surfaceContainerLow: surface,
          outline: brand.cardBorder,
          outlineVariant: brand.cardBorder,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      extensions: [brand],
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: brand.cardBorder,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: brand.cardBorder),
        ),
      ),
      dividerTheme: DividerThemeData(color: brand.cardBorder, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brand.inverseSurface,
          foregroundColor: brand.onInverseSurface,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          minimumSize: const Size.fromHeight(48),
          side: BorderSide(color: brand.cardBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: brand.cardBorder),
        backgroundColor: surface,
        selectedColor: primaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: TextStyle(color: onSurface, fontWeight: FontWeight.w600),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 13,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? onSurface
                : brand.muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 26,
            color: states.contains(WidgetState.selected)
                ? onSurface
                : brand.muted,
          ),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
