import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'draft_models.dart';

/// Persistence boundary for local dream drafts.
///
/// Behind an interface so screens stay free of storage logic and the
/// implementation can be faked in widget/unit tests.
abstract class IDraftRepository {
  /// All drafts, newest [DreamDraft.updatedAt] first.
  Future<List<DreamDraft>> list();

  Future<DreamDraft?> getById(String id);

  /// Inserts or updates [draft] (matched by id) and stamps [DreamDraft.updatedAt].
  Future<DreamDraft> save(DreamDraft draft);

  Future<void> delete(String id);

  Future<void> clear();
}

/// `shared_preferences`-backed [IDraftRepository] storing a JSON list under a
/// single key. Adapted from legacy's Drift `DreamDraftRepository`.
class SharedPrefsDraftRepository implements IDraftRepository {
  SharedPrefsDraftRepository({SharedPreferences? prefs}) : _injectedPrefs = prefs;

  static const String storageKey = 'dream_drafts_v1';

  final SharedPreferences? _injectedPrefs;

  Future<SharedPreferences> get _prefs async =>
      _injectedPrefs ?? await SharedPreferences.getInstance();

  Future<List<DreamDraft>> _readAll() async {
    final prefs = await _prefs;
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return <DreamDraft>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <DreamDraft>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(DreamDraft.fromJson)
          .toList();
    } on Object {
      // Corrupt/legacy payload — start clean rather than crash the tab.
      return <DreamDraft>[];
    }
  }

  Future<void> _writeAll(List<DreamDraft> drafts) async {
    final prefs = await _prefs;
    final raw = jsonEncode(drafts.map((d) => d.toJson()).toList());
    await prefs.setString(storageKey, raw);
  }

  @override
  Future<List<DreamDraft>> list() async {
    final drafts = await _readAll()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return drafts;
  }

  @override
  Future<DreamDraft?> getById(String id) async {
    final drafts = await _readAll();
    for (final draft in drafts) {
      if (draft.id == id) return draft;
    }
    return null;
  }

  @override
  Future<DreamDraft> save(DreamDraft draft) async {
    final drafts = await _readAll();
    final stamped = draft.copyWith(updatedAt: DateTime.now());
    final index = drafts.indexWhere((d) => d.id == stamped.id);
    if (index >= 0) {
      drafts[index] = stamped;
    } else {
      drafts.add(stamped);
    }
    await _writeAll(drafts);
    return stamped;
  }

  @override
  Future<void> delete(String id) async {
    final drafts = await _readAll()..removeWhere((d) => d.id == id);
    await _writeAll(drafts);
  }

  @override
  Future<void> clear() async {
    final prefs = await _prefs;
    await prefs.remove(storageKey);
  }
}
