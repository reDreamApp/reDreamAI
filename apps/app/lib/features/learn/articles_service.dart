import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:redream_app/core/env.dart';
import 'package:redream_app/features/learn/article.dart';

/// Reads the website's blog metadata; article bodies open in the browser.
class ArticlesService {
  ArticlesService({http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final http.Client _http;

  Future<List<Article>> fetch({required String language}) async {
    final res = await _http.get(
      Uri.parse(Env.blogMetaUrl),
      headers: {'Cache-Control': 'no-cache'},
    );
    if (res.statusCode != 200) throw Exception('blog meta ${res.statusCode}');
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    final posts = decoded is Map ? decoded['posts'] : null;
    if (posts is! List) return const [];
    return [
      for (final p in posts)
        if (p is Map<String, dynamic>) ?_parse(p, language),
    ];
  }

  static Article? _parse(Map<String, dynamic> post, String lang) {
    final title = _localized(post['title'], lang);
    final urls = _urls(post['post_url'], lang);
    if (title.isEmpty || urls.isEmpty) return null;
    return Article(
      slug: post['slug']?.toString() ?? title,
      title: title,
      excerpt: _localized(post['excerpt'], lang),
      urls: urls,
    );
  }

  static String _localized(Object? value, String lang) {
    if (value is String) return value.trim();
    if (value is Map) {
      final v = value[lang] ?? value['en'] ?? value['de'];
      return v?.toString().trim() ?? '';
    }
    return '';
  }

  static Map<String, String> _urls(Object? value, String lang) {
    if (value is! Map) return const {};
    final byLang = value[lang] ?? value['en'] ?? value['de'];
    if (byLang is! Map) return const {};
    return {
      for (final theme in ['light', 'dark'])
        if (byLang[theme] case final String url when url.isNotEmpty) theme: url,
    };
  }
}
