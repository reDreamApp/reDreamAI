import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Light/dark mode selection, persisted across launches (ported from legacy).
class ThemeProvider extends ChangeNotifier {
  static const _prefsKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  bool isDarkMode(BuildContext context) {
    if (_themeMode == ThemeMode.system) {
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  void toggleTheme(BuildContext context) {
    _themeMode = isDarkMode(context) ? ThemeMode.light : ThemeMode.dark;
    _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _themeMode.name);
  }

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    if (stored == null) return;
    _themeMode = ThemeMode.values.asNameMap()[stored] ?? ThemeMode.system;
    notifyListeners();
  }
}
