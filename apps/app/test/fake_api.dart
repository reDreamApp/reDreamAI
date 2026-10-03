import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:redream_app/core/api/api_client.dart';

typedef Handler =
    Object? Function(http.Request request, Map<String, dynamic> body);

/// In-memory stand-in for `apps/api`. Routes are `'METHOD /path'`; a handler
/// returns the JSON body (or null for 204), or throws to fail the request.
class FakeApi {
  FakeApi({this.offline = false});

  bool offline;
  final routes = <String, Handler>{};
  final calls = <String>[];
  String? lastToken;

  void on(String route, Handler handler) => routes[route] = handler;

  ApiClient client({Future<void> Function()? refreshSession, String? token}) =>
      ApiClient(
        baseUrl: 'http://fake',
        tokenProvider: () => token,
        refreshSession: refreshSession,
        httpClient: MockClient(_handle),
      );

  Future<http.Response> _handle(http.Request request) async {
    if (offline) throw http.ClientException('offline', request.url);
    lastToken = request.headers['Authorization'];
    final key = '${request.method} ${request.url.path}';
    calls.add(key);
    final handler =
        routes[key] ??
        routes.entries
            .where((e) => _matches(e.key, key))
            .map((e) => e.value)
            .firstOrNull;
    if (handler == null) {
      return http.Response(jsonEncode({'detail': 'not found'}), 404);
    }
    final body = request.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(request.body) as Map<String, dynamic>;
    try {
      final result = handler(request, body);
      if (result == null) return http.Response('', 204);
      return http.Response(
        jsonEncode(result),
        request.method == 'POST' ? 201 : 200,
        headers: {'content-type': 'application/json'},
      );
    } on FakeApiError catch (e) {
      return http.Response(
        jsonEncode({'detail': e.message}),
        e.status,
        headers: e.headers,
      );
    }
  }

  static bool _matches(String pattern, String key) {
    final p = pattern.split('/');
    final k = key.split('/');
    if (p.length != k.length) return false;
    for (var i = 0; i < p.length; i++) {
      if (p[i] != k[i] && !p[i].startsWith('{')) return false;
    }
    return true;
  }
}

class FakeApiError implements Exception {
  FakeApiError(this.status, this.message, {this.headers = const {}});
  final int status;
  final String message;
  final Map<String, String> headers;
}

Map<String, dynamic> dreamJson(
  int id, {
  String title = 'Lost in Dark Forest',
  bool nightmare = true,
  String? rewritten = 'I found the way home.',
  int? intensity = 8,
  List<String> practices = const [],
  bool current = false,
  String? sessionId,
}) => {
  'id': id,
  'title': title,
  'original_dream': 'I was lost in a forest.',
  'rewritten_dream': rewritten,
  'intensity': intensity,
  'is_nightmare': nightmare,
  'created_at': '2025-11-03T10:00:00Z',
  'last_edited': '2025-11-03T10:00:00Z',
  'practice_timestamps': practices,
  'is_current_dream': current,
  'image_url': null,
  'session_id': sessionId,
  'source': 'manual',
  'rehearsal_audio_url': null,
  'rehearsal_script': null,
  'rehearsal_duration': null,
  'rehearsal_language': null,
  'rehearsal_generated_at': null,
};

Map<String, dynamic> messageJson(
  String id, {
  required String role,
  required String content,
  String stage = 'recording',
}) => {
  'id': id,
  'role': role,
  'content': content,
  'stage': stage,
  'visibility_status': 'visible',
  'created_at': '2025-11-03T14:45:00Z',
};

Map<String, dynamic> chatJson(int id, {bool done = false, String? title}) => {
  'id': id,
  'language': 'en',
  'current_stage': done ? 'final' : 'recording',
  'is_done': done,
  'is_nightmare': done ? true : null,
  'title': title,
  'created_at': '2025-11-03T14:45:00Z',
  'updated_at': '2025-11-03T14:46:00Z',
};

Map<String, dynamic> statsJson({
  int streak = 2,
  int dreams = 2,
  int treated = 1,
  String? mood,
}) => {
  'rehearsal_streak': streak,
  'average_intensity': 7.0,
  'average_mood': 4.0,
  'today_mood': mood,
  'dreams_logged': dreams,
  'nightmares_treated': treated,
};
