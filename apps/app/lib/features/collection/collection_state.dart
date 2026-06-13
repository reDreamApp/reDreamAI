import 'package:flutter/foundation.dart';

import '../../core/models/dream.dart';
import '../../core/services/dream_service.dart';

/// Shared dream-collection state.
///
/// PUBLIC API IS A CROSS-FEATURE CONTRACT: the chat feature calls `refresh()`
/// when a session finishes, the record feature after creating a dream. Extend
/// freely, but keep `dreams`, `isLoading`, `error`, `preload()`, `refresh()`.
class DreamCollectionState extends ChangeNotifier {
  DreamCollectionState(this._service);

  final IDreamService _service;

  List<Dream> _dreams = const [];
  bool _isLoading = false;
  String? _error;
  bool _loadedOnce = false;

  List<Dream> get dreams => _dreams;
  bool get isLoading => _isLoading;
  String? get error => _error;

  IDreamService get service => _service;

  /// Loads once; later calls are no-ops (use [refresh] to force).
  Future<void> preload() async {
    if (_loadedOnce || _isLoading) return;
    await refresh();
  }

  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _dreams = await _service.list();
      _loadedOnce = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void resetForUserChange() {
    _dreams = const [];
    _loadedOnce = false;
    _error = null;
    notifyListeners();
  }

  /// The current in-memory copy of a dream, or null if it's gone.
  Dream? dreamById(int id) {
    for (final d in _dreams) {
      if (d.id == id) return d;
    }
    return null;
  }

  /// Persists [fields] (snake_case JSON keys) and updates the local copy.
  Future<Dream> updateDream(int id, Map<String, dynamic> fields) async {
    final updated = await _service.update(id, fields);
    _replace(updated);
    return updated;
  }

  Future<void> deleteDream(int id) async {
    await _service.delete(id);
    _dreams = _dreams.where((d) => d.id != id).toList(growable: false);
    notifyListeners();
  }

  /// Marks [id] as the current practice dream. The backend clears the flag on
  /// other dreams, so we refresh the whole list afterwards.
  Future<void> setCurrentDream(int id) async {
    await _service.setCurrent(id);
    await refresh();
  }

  Future<Dream> recordPractice(int id) async {
    final updated = await _service.recordPractice(id);
    _replace(updated);
    return updated;
  }

  Future<Dream> generateRehearsal(int id, {required String language}) async {
    final updated = await _service.generateRehearsal(id, language: language);
    _replace(updated);
    return updated;
  }

  void _replace(Dream updated) {
    _dreams = [
      for (final d in _dreams)
        if (d.id == updated.id) updated else d,
    ];
    notifyListeners();
  }
}
