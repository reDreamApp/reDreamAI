import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App + chat language ('en' / 'de'), persisted across launches.
///
/// Drives both the MaterialApp locale override and the `language` field sent
/// on `POST /chats/start` — the backend AI replies in this language.
class LanguageProvider extends ChangeNotifier {
  static const _prefsKey = 'selected_language';
  static const supported = ['en', 'de'];

  String? _selected; // null = follow system locale

  /// Effective chat/app language code.
  String get selectedLanguage {
    if (_selected != null) return _selected!;
    final system = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return supported.contains(system) ? system : 'en';
  }

  /// Locale override for MaterialApp, or null to follow the system.
  Locale? get localeOverride => _selected == null ? null : Locale(_selected!);

  Future<void> setLanguage(String? code) async {
    assert(code == null || supported.contains(code));
    _selected = code;
    final prefs = await SharedPreferences.getInstance();
    if (code == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, code);
    }
    notifyListeners();
  }

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    if (stored != null && supported.contains(stored)) {
      _selected = stored;
      notifyListeners();
    }
  }
}
