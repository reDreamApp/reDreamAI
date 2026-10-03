import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:redream_app/core/api/api_exception.dart';

typedef TokenProvider = String? Function();
typedef SessionRefresher = Future<void> Function();

/// JSON client for `apps/api`. Adds the bearer token, maps transport failures
/// to [NetworkException], non-2xx to [ApiException], and retries once after a
/// session refresh on 401.
/// Calls that wait on the LLM: the backend allows the AI service 90s.
const aiTimeout = Duration(seconds: 100);

class ApiClient {
  ApiClient({
    required String baseUrl,
    required TokenProvider tokenProvider,
    SessionRefresher? refreshSession,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 30),
  }) : _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
       _tokenProvider = tokenProvider,
       _refreshSession = refreshSession,
       _http = httpClient ?? http.Client(),
       _timeout = timeout;

  final String _baseUrl;
  final TokenProvider _tokenProvider;
  final SessionRefresher? _refreshSession;
  final http.Client _http;
  final Duration _timeout;

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) =>
      _map(_request('GET', path, query: query));

  Future<List<dynamic>> getList(String path, {Map<String, String>? query}) =>
      _list(_request('GET', path, query: query));

  /// [timeout] overrides the default for calls that wait on the LLM.
  Future<Map<String, dynamic>> post(
    String path, [
    Object? body,
    Duration? timeout,
  ]) => _map(_request('POST', path, body: body, timeout: timeout));

  Future<Map<String, dynamic>> put(String path, Object? body) =>
      _map(_request('PUT', path, body: body));

  Future<Map<String, dynamic>> patch(String path, [Object? body]) =>
      _map(_request('PATCH', path, body: body));

  Future<void> delete(String path) => _request('DELETE', path);

  Future<Object?> _request(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    Duration? timeout,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl${path.startsWith('/') ? '' : '/'}$path',
    ).replace(queryParameters: query == null || query.isEmpty ? null : query);

    var res = await _send(method, uri, body, timeout ?? _timeout);
    if (res.statusCode == 401 && _refreshSession != null) {
      try {
        await _refreshSession();
      } on Exception {
        return _decode(res);
      }
      res = await _send(method, uri, body, timeout ?? _timeout);
    }
    return _decode(res);
  }

  Future<http.Response> _send(
    String method,
    Uri uri,
    Object? body,
    Duration timeout,
  ) async {
    final token = _tokenProvider();
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
    final encoded = body == null ? null : jsonEncode(body);
    try {
      final future = switch (method) {
        'GET' => _http.get(uri, headers: headers),
        'POST' => _http.post(uri, headers: headers, body: encoded),
        'PUT' => _http.put(uri, headers: headers, body: encoded),
        'PATCH' => _http.patch(uri, headers: headers, body: encoded),
        'DELETE' => _http.delete(uri, headers: headers),
        _ => throw ArgumentError.value(method, 'method'),
      };
      return await future.timeout(timeout);
    } on http.ClientException catch (e) {
      throw NetworkException(e.message);
    } on SocketException catch (e) {
      throw NetworkException(e.message);
    } on TimeoutException {
      throw NetworkException('timeout');
    }
  }

  Object? _decode(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(
        res.statusCode,
        _errorMessage(res.body),
        retryAfterSeconds: int.tryParse(res.headers['retry-after'] ?? ''),
      );
    }
    if (res.body.isEmpty) return null;
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  Future<Map<String, dynamic>> _map(Future<Object?> pending) async {
    final decoded = await pending;
    if (decoded == null) return <String, dynamic>{};
    if (decoded is Map<String, dynamic>) return decoded;
    throw ApiException(200, 'Expected object, got ${decoded.runtimeType}');
  }

  Future<List<dynamic>> _list(Future<Object?> pending) async {
    final decoded = await pending;
    if (decoded is List) return decoded;
    throw ApiException(200, 'Expected list, got ${decoded.runtimeType}');
  }

  /// FastAPI puts the human-readable error under `detail`, either a string
  /// or (for validation errors) a list of `{loc, msg}` entries.
  static String _errorMessage(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      return body;
    }
    final detail = decoded is Map<String, dynamic> ? decoded['detail'] : null;
    if (detail is String) return detail;
    if (detail is List) {
      final messages = detail
          .whereType<Map<String, dynamic>>()
          .map((e) => e['msg'])
          .whereType<String>()
          .join('; ');
      if (messages.isNotEmpty) return messages;
    }
    return body;
  }
}
