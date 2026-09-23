import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

typedef TokenProvider = String? Function();

class ApiClient {
  ApiClient({
    required String baseUrl,
    required TokenProvider tokenProvider,
    http.Client? httpClient,
  }) : _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
       _tokenProvider = tokenProvider,
       _http = httpClient ?? http.Client();

  final String _baseUrl;
  final TokenProvider _tokenProvider;
  final http.Client _http;

  Future<Map<String, dynamic>> get(String path) => _send('GET', path);

  Future<List<dynamic>> getList(String path) => _send('GET', path);

  Future<Map<String, dynamic>> post(String path, Object? body) =>
      _send('POST', path, body: body);

  Future<T> _send<T>(String method, String path, {Object? body}) async {
    final uri = Uri.parse('$_baseUrl${path.startsWith('/') ? '' : '/'}$path');
    final token = _tokenProvider();
    final headers = <String, String>{
      'Accept': 'application/json',
      if (method == 'POST') 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    final res = method == 'GET'
        ? await _http.get(uri, headers: headers)
        : await _http.post(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(
        res.statusCode,
        _errorMessage(res.body),
        retryAfterSeconds: int.tryParse(res.headers['retry-after'] ?? ''),
      );
    }

    final decoded = res.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(res.body);
    if (decoded is! T) {
      throw ApiException(
        res.statusCode,
        'Expected $T, got ${decoded.runtimeType}',
      );
    }
    return decoded;
  }

  /// FastAPI puts the human-readable error under `detail`; fall back to the
  /// raw body when the response isn't the shape we expect.
  String _errorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['detail'] is String) {
        return decoded['detail'] as String;
      }
    } catch (_) {}
    return body;
  }
}
