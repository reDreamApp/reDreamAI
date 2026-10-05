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

const _topicBlue = Color(0xFF63B5F5);
const _topicGreen = Color(0xFF7FC782);
const _topicPink = Color(0xFFEE6291);

/// Topics with a fixed colour, in both languages, so a topic looks the same
/// whichever language the articles are shown in.
const Map<String, Color> _topicColors = {
  'science': _topicBlue,
  'wissenschaft': _topicBlue,
  'sleep': _topicBlue,
  'schlaf': _topicBlue,
  'app': _topicGreen,
  'mental health': _topicPink,
  'psychische gesundheit': _topicPink,
  'dreams': _topicPink,
  'träume': _topicPink,
};

/// One of three topic colours; an unknown topic always gets the same one.
Color tagColor(String tag) {
  final key = tag.trim().toLowerCase();
  if (key.isEmpty) return const Color(0xFF9CA3AF);
  const palette = [_topicBlue, _topicGreen, _topicPink];
  return _topicColors[key] ??
      palette[key.codeUnits.fold(0, (a, b) => a + b) % palette.length];
}

/// [tagColor] dark or light enough to read as text on its own tint.
Color tagInk(String tag, Brightness brightness) => HSLColor.fromColor(
  tagColor(tag),
).withLightness(brightness == Brightness.dark ? 0.78 : 0.32).toColor();
