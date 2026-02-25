import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsNotifier extends ChangeNotifier {
  SettingsNotifier._();
  static final SettingsNotifier instance = SettingsNotifier._();

  static const String keyShowDrawerHint = 'show_drawer_hint';
  static const String keyThemeMode = 'theme_mode';
  static const String keyInactivityTimeout = 'inactivity_timeout';
  static const String keyNotificationsEnabled = 'notifications_enabled';
  // Key for medical records lock persistence
  static const String keyMedicalRecordsLocked = 'medical_records_locked';

  bool _isLoaded = false;
  bool _showDrawerHint = true;
  ThemeMode _themeMode = ThemeMode.system;

  // Note: 0 ms represents "Off", 3600000 ms represents "1 Hour"
  int _inactivityTimeoutMs = 300000; // default 5 minutes
  bool _notificationsEnabled = true;
  // Internal state for medical records lock
  bool _medicalRecordsLocked = false;

  bool get isLoaded => _isLoaded;
  bool get showDrawerHint => _showDrawerHint;
  ThemeMode get themeMode => _themeMode;
  int get inactivityTimeoutMs => _inactivityTimeoutMs;
  bool get notificationsEnabled => _notificationsEnabled;
  // Getter for the medical records lock state
  bool get medicalRecordsLocked => _medicalRecordsLocked;

  Future<void> loadSettings() async {
    if (_isLoaded) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      _showDrawerHint = prefs.getBool(keyShowDrawerHint) ?? true;

      final themeString = prefs.getString(keyThemeMode) ?? 'system';
      _themeMode = _parseThemeMode(themeString);

      _inactivityTimeoutMs = prefs.getInt(keyInactivityTimeout) ?? 300000;
      _notificationsEnabled = prefs.getBool(keyNotificationsEnabled) ?? true;

      // Load the saved medical records lock state
      _medicalRecordsLocked = prefs.getBool(keyMedicalRecordsLocked) ?? false;

      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint("SettingsNotifier: Failed to load settings: $e");
    }
  }

  // Method to update and persist the medical records lock state
  Future<void> updateMedicalRecordsLock(bool value) async {
    _medicalRecordsLocked = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyMedicalRecordsLocked, value);
    } catch (e) {
      debugPrint("SettingsNotifier: Failed to save records lock setting: $e");
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

  Future<void> updateInactivityTimeout(int ms) async {
    _inactivityTimeoutMs = ms;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(keyInactivityTimeout, ms);
    } catch (e) {
      debugPrint("SettingsNotifier: Failed to save timeout: $e");
    }
  }

  Future<void> updateNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyNotificationsEnabled, enabled);
    } catch (e) {
      debugPrint("SettingsNotifier: Failed to save notifications: $e");
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

  /// Clear state on logout.
  void clear() {
    _isLoaded = false;
    _showDrawerHint = true;
    _themeMode = ThemeMode.system;
    _inactivityTimeoutMs = 300000;
    _notificationsEnabled = true;
    _medicalRecordsLocked = false; // Reset lock on logout
    notifyListeners();
  }
}
