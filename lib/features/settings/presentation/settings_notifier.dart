import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsNotifier extends ChangeNotifier {
  SettingsNotifier._();
  static final SettingsNotifier instance = SettingsNotifier._();

  static const String keyShowDrawerHint = 'show_drawer_hint';
  static const String keyThemeMode = 'theme_mode';

  bool _isLoaded = false;
  bool _showDrawerHint = true;
  ThemeMode _themeMode = ThemeMode.system;

  bool get isLoaded => _isLoaded;
  bool get showDrawerHint => _showDrawerHint;
  ThemeMode get themeMode => _themeMode;

  Future<void> loadSettings() async {
    if (_isLoaded) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _showDrawerHint = prefs.getBool(keyShowDrawerHint) ?? true;

      final themeString = prefs.getString(keyThemeMode) ?? 'system';
      _themeMode = _parseThemeMode(themeString);

      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint("SettingsNotifier: Failed to load settings: $e");
    }
  }

  Future<void> updateShowDrawerHint(bool value) async {
    _showDrawerHint = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyShowDrawerHint, value);
    } catch (e) {
      debugPrint("SettingsNotifier: Failed to save setting: $e");
    }
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        keyThemeMode,
        mode.name,
      ); // stored as 'system', 'light', 'dark'
    } catch (e) {
      debugPrint("SettingsNotifier: Failed to save theme: $e");
    }
  }

  ThemeMode _parseThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}
