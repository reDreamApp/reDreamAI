import 'dart:convert';

import 'package:http/http.dart' as http;

import 'educational_article.dart';

/// Fetches the educational articles metadata (feature-local service).
///
/// The article catalog is the website's blog meta.json (public, no auth) —
/// same source as the legacy app. Bodies open on the website.
abstract class ILearnService {
  /// [languageCode] is normalized to 'en'/'de'.
  Future<List<EducationalArticle>> fetchArticles(String languageCode);
}

class LearnService implements ILearnService {
  LearnService({http.Client? httpClient, String metaUrl = _defaultMetaUrl})
      : _http = httpClient ?? http.Client(),
        _metaUrl = metaUrl;

  static const String _defaultMetaUrl =
      'https://www.redreamai.com/content/blog/posts/meta.json';

  final http.Client _http;
  final String _metaUrl;

  @override
  Future<List<EducationalArticle>> fetchArticles(String languageCode) async {
    final lang = _normalizeLanguage(languageCode);
    final response = await _http.get(
      Uri.parse(_metaUrl),
      headers: const {'Cache-Control': 'no-cache'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load blog metadata (${response.statusCode})');
    }
    final data = jsonDecode(response.body);
    if (data is! Map) return const [];
    final posts = data['posts'];
    if (posts is! List) return const [];

    final articles = <EducationalArticle>[];
    for (final rawPost in posts) {
      if (rawPost is! Map) continue;
      final post = Map<String, dynamic>.from(rawPost);
      final title = _pickLocalized(_asStringMap(post['title']), lang).trim();
      if (title.isEmpty) continue;
      final subtitle =
          _pickLocalized(_asStringMap(post['excerpt']), lang).trim();
      final postUrls = _parsePostUrls(post['post_url'], lang);
      if (postUrls.isEmpty) continue;
      articles.add(
        EducationalArticle(
          title: title,
          subtitle: subtitle,
          postUrls: postUrls,
          tags: _parseTags(post['tags'], lang),
        ),
      );
    }
    return articles;
  }

  String _normalizeLanguage(String languageCode) {
    return languageCode.toLowerCase().startsWith('de') ? 'de' : 'en';
  }

  Map<String, dynamic> _asStringMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _pickLocalized(Map<String, dynamic> data, String lang) {
    final value = data[lang] ?? data['en'] ?? data['de'] ?? '';
    return value is String ? value : value.toString();
  }

  List<String> _normalizeTags(List<dynamic> rawTags) {
    final seen = <String>{};
    final tags = <String>[];
    for (final raw in rawTags) {
      final tag = raw.toString().trim();
      if (tag.isEmpty) continue;
      if (seen.add(tag.toLowerCase())) tags.add(tag);
    }
    return tags;
  }

  List<String> _parseTags(dynamic raw, String lang) {
    if (raw is List) return _normalizeTags(raw);
    final map = _asStringMap(raw);
    if (map.isNotEmpty) {
      final localized = map[lang] ?? map['en'] ?? map['de'];
      if (localized is List) return _normalizeTags(localized);
    }
    return const [];
  }

  Map<String, String> _parsePostUrls(dynamic raw, String lang) {
    final map = _asStringMap(raw);
    if (map.isEmpty) return const {};
    final localized = _asStringMap(map[lang] ?? map['en'] ?? map['de']);
    if (localized.isEmpty) return const {};
    final urls = <String, String>{};
    for (final entry in localized.entries) {
      final value = entry.value;
      if (value is String && value.isNotEmpty) {
        urls[entry.key] = value;
      }
    }
    return urls;
  }
}
