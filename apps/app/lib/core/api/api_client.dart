import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

typedef TokenProvider = String? Function();

class ApiClient {
  ApiClient({
    required String baseUrl,
    required TokenProvider tokenProvider,
    http.Client? httpClient,
  }) : _baseUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl,
       _tokenProvider = tokenProvider,
       _http = httpClient ?? http.Client();

  final String _baseUrl;
  final TokenProvider _tokenProvider;
  final http.Client _http;

  Future<Map<String, dynamic>> get(String path) async {
    final res = await _http.get(_uri(path), headers: _headers());
    return _decode(res);
  }

  Future<Map<String, dynamic>> post(String path, Object? body) async {
    final res = await _http.post(
      _uri(path),
      headers: _headers(json: true),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> put(String path, Object? body) async {
    final res = await _http.put(
      _uri(path),
      headers: _headers(json: true),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> patch(String path, Object? body) async {
    final res = await _http.patch(
      _uri(path),
      headers: _headers(json: true),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(res);
  }

  Future<void> delete(String path) async {
    final res = await _http.delete(_uri(path), headers: _headers());
    _decodeRaw(res);
  }

  Future<List<dynamic>> getList(String path) async {
    final res = await _http.get(_uri(path), headers: _headers());
    final decoded = _decodeRaw(res);
    if (decoded is! List) {
      throw ApiException(res.statusCode, 'Expected list, got ${decoded.runtimeType}');
    }
    return decoded;
  }

  Uri _uri(String path) {
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$_baseUrl$p');
  }

  Map<String, String> _headers({bool json = false}) {
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (json) headers['Content-Type'] = 'application/json';
    final token = _tokenProvider();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Map<String, dynamic> _decode(http.Response res) {
    final raw = _decodeRaw(res);
    if (raw is! Map<String, dynamic>) {
      throw ApiException(res.statusCode, 'Expected object, got ${raw.runtimeType}');
    }
    return raw;
  }

  dynamic _decodeRaw(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return <String, dynamic>{};
      return jsonDecode(res.body);
    }
    String message = res.body;
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['detail'] is String) {
        message = decoded['detail'] as String;
      }
    } catch (_) {}
    final retryAfter = int.tryParse(res.headers['retry-after'] ?? '');
    throw ApiException(res.statusCode, message, retryAfterSeconds: retryAfter);
  }
}
