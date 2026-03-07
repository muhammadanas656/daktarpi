import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsNotifier extends ChangeNotifier {
  SettingsNotifier._();
  static final SettingsNotifier instance = SettingsNotifier._();

  static const String keyShowDrawerHint = 'show_drawer_hint';
  static const String keyThemeMode = 'theme_mode';
  static const String keyInactivityTimeout = 'inactivity_timeout';
  static const String keyNotificationsEnabled = 'notifications_enabled';
  static const String keyMedicalRecordsLocked = 'medical_records_locked';

  static const String keyHasBiometricHardware = 'has_biometric_hardware';
  static const String keyIsBiometricEnabled = 'is_biometric_enabled';

  // NEW: Persistence keys for security status caching
  static const String key2FAEnabled = 'is_2fa_enabled';

  bool _isLoaded = false;
  bool _showDrawerHint = true;
  ThemeMode _themeMode = ThemeMode.system;

  int _inactivityTimeoutMs = 300000; // default 5 minutes
  bool _notificationsEnabled = true;
  // Internal state for medical records lock
  bool _medicalRecordsLocked = false;

  // Cached biometric state for instant UI rendering
  bool _hasBiometricHardware = false;
  bool _isBiometricEnabled = false;

  // NEW: Internal state for instantaneous UI rendering
  bool _is2FAEnabled = false;

  bool get isLoaded => _isLoaded;
  bool get showDrawerHint => _showDrawerHint;
  ThemeMode get themeMode => _themeMode;
  int get inactivityTimeoutMs => _inactivityTimeoutMs;
  bool get notificationsEnabled => _notificationsEnabled;
  // Getter for the medical records lock state
  bool get medicalRecordsLocked => _medicalRecordsLocked;

  bool get hasBiometricHardware => _hasBiometricHardware;
  bool get isBiometricEnabled => _isBiometricEnabled;

  // NEW: Getters for the UI to read immediately from memory
  bool get is2FAEnabled => _is2FAEnabled;

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

      _hasBiometricHardware = prefs.getBool(keyHasBiometricHardware) ?? false;
      _isBiometricEnabled = prefs.getBool(keyIsBiometricEnabled) ?? false;

      // NEW: Load cached security statuses from disk
      _is2FAEnabled = prefs.getBool(key2FAEnabled) ?? false;

      // Enforce security dependency on medical records lock
      final hasSecurityConfigured = _is2FAEnabled || _isBiometricEnabled;
      if (!hasSecurityConfigured) {
        _medicalRecordsLocked = false;
        await prefs.setBool(keyMedicalRecordsLocked, false);
      }

      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint("SettingsNotifier: Failed to load settings: $e");
    }
  }

  // NEW: Method to update and persist 2FA status
  Future<void> update2FAEnabled(bool value) async {
    if (_is2FAEnabled == value) return;
    _is2FAEnabled = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key2FAEnabled, value);

      // If turning off 2FA and biometrics is also off, unlock records
      if (!value && !_isBiometricEnabled) {
        await updateMedicalRecordsLock(false);
      }
    } catch (e) {
      debugPrint("SettingsNotifier: Failed to save 2FA status: $e");
    }
  }

  // NEW: Method to update and persist Biometric status
  Future<void> updateBiometricState(bool hasHardware, bool isEnabled) async {
    _hasBiometricHardware = hasHardware;
    _isBiometricEnabled = isEnabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyHasBiometricHardware, hasHardware);
      await prefs.setBool(keyIsBiometricEnabled, isEnabled);

      // If turning off biometrics and 2FA is also off, unlock records
      if (!isEnabled && !_is2FAEnabled) {
        await updateMedicalRecordsLock(false);
      }
    } catch (e) {
      debugPrint("SettingsNotifier: Failed to save biometric state: $e");
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
      await prefs.setString(keyThemeMode, mode.name);
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

  void clear() {
    _isLoaded = false;
    _showDrawerHint = true;
    _themeMode = ThemeMode.system;
    _inactivityTimeoutMs = 300000;
    _notificationsEnabled = true;
    _medicalRecordsLocked = false; // Reset lock on logout
    _hasBiometricHardware = false;
    _isBiometricEnabled = false;
    _is2FAEnabled = false;

    notifyListeners();
  }
}
