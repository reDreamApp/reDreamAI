import 'package:flutter/material.dart';

class Article {
  const Article({
    required this.slug,
    required this.title,
    required this.excerpt,
    required this.urls,
  });

  final String slug;
  final String title;
  final String excerpt;

  /// `light` / `dark` → article URL.
  final Map<String, String> urls;

  String? urlFor(Brightness brightness) =>
      urls[brightness == Brightness.dark ? 'dark' : 'light'] ??
      urls.values.firstOrNull;
}
