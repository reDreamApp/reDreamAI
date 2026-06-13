import '../api/api_client.dart';
import '../models/dream.dart';

/// CRUD + practice/rehearsal against the backend's /api/v1/dreams routes.
abstract class IDreamService {
  Future<List<Dream>> list();
  Future<Dream> getById(int id);
  Future<Dream> create({
    required String title,
    required String originalDream,
    String? rewrittenDream,
    int? intensity,
    bool isNightmare,
  });
  Future<Dream> update(int id, Map<String, dynamic> fields);
  Future<void> delete(int id);

  /// Marks this dream as the user's current practice dream (clears others).
  Future<Dream> setCurrent(int id);
  Future<Dream> recordPractice(int id);
  Future<Dream> generateRehearsal(int id, {required String language});
}

class DreamService implements IDreamService {
  DreamService(this._api);
  final ApiClient _api;

  static const _base = '/api/v1/dreams';

  @override
  Future<List<Dream>> list() async {
    final raw = await _api.getList(_base);
    return raw.map((e) => Dream.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<Dream> getById(int id) async => Dream.fromJson(await _api.get('$_base/$id'));

  @override
  Future<Dream> create({
    required String title,
    required String originalDream,
    String? rewrittenDream,
    int? intensity,
    bool isNightmare = false,
  }) async {
    final json = await _api.post(_base, {
      'title': title,
      'original_dream': originalDream,
      if (rewrittenDream != null) 'rewritten_dream': rewrittenDream,
      if (intensity != null) 'intensity': intensity,
      'is_nightmare': isNightmare,
      'source': 'manual',
    });
    return Dream.fromJson(json);
  }

  @override
  Future<Dream> update(int id, Map<String, dynamic> fields) async {
    return Dream.fromJson(await _api.put('$_base/$id', fields));
  }

  @override
  Future<void> delete(int id) => _api.delete('$_base/$id');

  @override
  Future<Dream> setCurrent(int id) async {
    return Dream.fromJson(await _api.patch('$_base/$id/favorite', null));
  }

  @override
  Future<Dream> recordPractice(int id) async {
    return Dream.fromJson(await _api.post('$_base/$id/practice', null));
  }

  @override
  Future<Dream> generateRehearsal(int id, {required String language}) async {
    return Dream.fromJson(
      await _api.post('$_base/$id/rehearsal', {'language': language}),
    );
  }
}
