import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeProvider extends ChangeNotifier {
  AppThemeProvider(
      {SharedPreferences? prefs, ThemeMode initialMode = ThemeMode.system})
      : _prefs = prefs,
        _themeMode = initialMode;

  static const String _key = 'app_theme_mode';
  final SharedPreferences? _prefs;
  ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;

  static Future<AppThemeProvider> create() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    final mode = switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    return AppThemeProvider(prefs: prefs, initialMode: mode);
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    _saveThemeMode(mode);
  }

  Future<void> _saveThemeMode(ThemeMode mode) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}
