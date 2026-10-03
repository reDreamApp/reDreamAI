import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Small key/value store for settings, caches and offline queues.
class LocalStore {
  LocalStore(this._prefs);

  static Future<LocalStore> open() async =>
      LocalStore(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  String? getString(String key) => _prefs.getString(key);
  bool? getBool(String key) => _prefs.getBool(key);
  int? getInt(String key) => _prefs.getInt(key);

  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);
  Future<void> setBool(String key, {required bool value}) =>
      _prefs.setBool(key, value);
  Future<void> setInt(String key, int value) => _prefs.setInt(key, value);
  Future<void> remove(String key) => _prefs.remove(key);

  Object? getJson(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  Future<void> setJson(String key, Object? value) =>
      value == null ? remove(key) : setString(key, jsonEncode(value));

  /// Removes every key that belongs to [userId] (keys end in `:<userId>`).
  Future<void> clearUser(String userId) async {
    for (final key in _prefs.getKeys().where((k) => k.endsWith(':$userId'))) {
      await _prefs.remove(key);
    }
  }
}
