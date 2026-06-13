import 'package:flutter/material.dart';

/// Educational article metadata, ported from the legacy
/// models/educational_article.dart. Article bodies live on the website
/// (light/dark post URLs per language); the app shows title/excerpt/tags.
class EducationalArticle {
  const EducationalArticle({
    required this.title,
    required this.subtitle,
    required this.postUrls,
    required this.tags,
  });

  final String title;
  final String subtitle;

  /// 'light'/'dark' → themed post URL.
  final Map<String, String> postUrls;
  final List<String> tags;

  String urlForBrightness(Brightness brightness) {
    final key = brightness == Brightness.dark ? 'dark' : 'light';
    return postUrls[key] ?? postUrls.values.first;
  }
}

class TagStyle {
  const TagStyle({required this.label, required this.color});

  final String label;
  final Color color;
}

/// Deterministic tag color derived from the tag text. Tags are guaranteed
/// non-empty by LearnService parsing; an empty tag falls back to gray.
TagStyle tagStyleFor(String tag) {
  final cleaned = tag.trim();
  if (cleaned.isEmpty) {
    return const TagStyle(label: '–', color: Color(0xFF9CA3AF));
  }
  final hash = cleaned.toLowerCase().codeUnits.fold<int>(
    0,
    (sum, c) => sum + c,
  );
  final hue = (hash * 37) % 360;
  final color = HSLColor.fromAHSL(1.0, hue.toDouble(), 0.55, 0.55).toColor();
  return TagStyle(label: cleaned, color: color);
}

/// Ported from the legacy color_extensions.dart (used for tag label shades).
extension TagColorShade on Color {
  Color darken([double amount = 0.2]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final lightness = (hsl.lightness - amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }
}
