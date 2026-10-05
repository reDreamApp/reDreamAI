import 'package:flutter/material.dart';
import 'package:redream_app/l10n/generated/app_localizations.dart';

class Article {
  const Article({
    required this.slug,
    required this.title,
    required this.excerpt,
    required this.urls,
  });

  /// The team's study in Somnologie (2026). It is a journal article, not a
  /// post on the website, so the website's list does not carry it.
  factory Article.ownStudy(AppLocalizations l10n) => Article(
    slug: 'study-somnologie-2026',
    title: l10n.learnStudyTitle,
    excerpt: l10n.learnStudyExcerpt,
    urls: const {
      'light': 'https://link.springer.com/article/10.1007/s11818-026-00550-w',
    },
  );

  final String slug;
  final String title;
  final String excerpt;

  /// `light` / `dark` → article URL.
  final Map<String, String> urls;

  String? urlFor(Brightness brightness) =>
      urls[brightness == Brightness.dark ? 'dark' : 'light'] ??
      urls.values.firstOrNull;
}
