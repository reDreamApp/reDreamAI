import 'package:flutter/material.dart';

class Article {
  const Article({
    required this.slug,
    required this.title,
    required this.excerpt,
    required this.tags,
    required this.urls,
  });

  final String slug;
  final String title;
  final String excerpt;
  final List<String> tags;

  /// `light` / `dark` → article URL.
  final Map<String, String> urls;

  String? urlFor(Brightness brightness) =>
      urls[brightness == Brightness.dark ? 'dark' : 'light'] ??
      urls.values.firstOrNull;
}

/// Colour derived from the tag text so the same topic always looks the same.
Color tagColor(String tag) {
  if (tag.trim().isEmpty) return const Color(0xFF9CA3AF);
  final hash = tag.toLowerCase().codeUnits.fold(0, (a, b) => a + b);
  return HSLColor.fromAHSL(
    1,
    ((hash * 37) % 360).toDouble(),
    0.55,
    0.55,
  ).toColor();
}
