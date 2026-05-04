import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsNotifier extends ChangeNotifier {
  SettingsNotifier._();
  static final SettingsNotifier instance = SettingsNotifier._();

  static const String keyShowDrawerHint = 'show_drawer_hint';
  static const String keyThemeMode = 'theme_mode';
  static const String keyInactivityTimeout = 'inactivity_timeout';
  static const String keyMedicalRecordsLocked = 'medical_records_locked';
  static const String keyHasBiometricHardware = 'has_biometric_hardware';
  static const String keyIsBiometricEnabled = 'is_biometric_enabled';
  static const String key2FAEnabled = 'is_2fa_enabled';

  // Master Notification Toggle
  static const String keyNotificationsEnabled = 'notifications_enabled';

  // NEW: Granular Notification Toggles
  static const String keyBookingAlertsEnabled = 'booking_alerts_enabled';
  static const String keyReminderAlertsEnabled = 'reminder_alerts_enabled';
  static const String keyFiveHourWarningEnabled = 'five_hour_warning_enabled';
  static const String keyMorningOfReminderEnabled = 'morning_of_reminder_enabled';
  static const String keyMissedAppointmentAlertEnabled =
      'missed_appointment_alert_enabled';
  static const String keyAppUpdatesEnabled = 'app_updates_enabled';
  static const String keyGlobalReminderMinutes = 'global_reminder_minutes';
  static const String keyHasSeenRegionalWarning = 'has_seen_regional_warning';

  bool _isLoaded = false;
  bool _showDrawerHint = true;
  ThemeMode _themeMode = ThemeMode.system;

  int _inactivityTimeoutMs = 300000; // default 5 minutes
  bool _medicalRecordsLocked = false;
  bool _hasBiometricHardware = false;
  bool _isBiometricEnabled = false;
  bool _is2FAEnabled = false;

  // Notification State
  bool _notificationsEnabled = true;
  bool _bookingAlertsEnabled = true;
  bool _reminderAlertsEnabled = true;
  bool _fiveHourWarningEnabled = true;
  bool _morningOfReminderEnabled = true;
  bool _missedAppointmentAlertEnabled = true;
  bool _appUpdatesEnabled = true;
  int _globalReminderMinutes = 60; // Default: 1 hour before
  bool _hasSeenRegionalWarning = false;

  bool get isLoaded => _isLoaded;
  bool get showDrawerHint => _showDrawerHint;
  ThemeMode get themeMode => _themeMode;
  int get inactivityTimeoutMs => _inactivityTimeoutMs;
  bool get medicalRecordsLocked => _medicalRecordsLocked;
  bool get hasBiometricHardware => _hasBiometricHardware;
  bool get isBiometricEnabled => _isBiometricEnabled;
  bool get is2FAEnabled => _is2FAEnabled;

  // Notification Getters
  bool get notificationsEnabled => _notificationsEnabled;
  bool get bookingAlertsEnabled => _bookingAlertsEnabled;
  bool get reminderAlertsEnabled => _reminderAlertsEnabled;
  bool get fiveHourWarningEnabled => _fiveHourWarningEnabled;
  bool get morningOfReminderEnabled => _morningOfReminderEnabled;
  bool get missedAppointmentAlertEnabled => _missedAppointmentAlertEnabled;
  bool get appUpdatesEnabled => _appUpdatesEnabled;
  int get globalReminderMinutes => _globalReminderMinutes;
  bool get hasSeenRegionalWarning => _hasSeenRegionalWarning;

  Future<void> loadSettings() async {
    if (_isLoaded) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _showDrawerHint = prefs.getBool(keyShowDrawerHint) ?? true;

      final themeString = prefs.getString(keyThemeMode) ?? 'system';
      _themeMode = _parseThemeMode(themeString);

      _inactivityTimeoutMs = prefs.getInt(keyInactivityTimeout) ?? 300000;
      _medicalRecordsLocked = prefs.getBool(keyMedicalRecordsLocked) ?? false;
      _hasBiometricHardware = prefs.getBool(keyHasBiometricHardware) ?? false;
      _isBiometricEnabled = prefs.getBool(keyIsBiometricEnabled) ?? false;
      _is2FAEnabled = prefs.getBool(key2FAEnabled) ?? false;

      // Load Notification States
      _notificationsEnabled = prefs.getBool(keyNotificationsEnabled) ?? true;
      _bookingAlertsEnabled = prefs.getBool(keyBookingAlertsEnabled) ?? true;
      _reminderAlertsEnabled = prefs.getBool(keyReminderAlertsEnabled) ?? true;
      _fiveHourWarningEnabled =
          prefs.getBool(keyFiveHourWarningEnabled) ?? true;
      _morningOfReminderEnabled =
          prefs.getBool(keyMorningOfReminderEnabled) ?? true;
      _missedAppointmentAlertEnabled =
          prefs.getBool(keyMissedAppointmentAlertEnabled) ?? true;
      _appUpdatesEnabled = prefs.getBool(keyAppUpdatesEnabled) ?? true;
      _globalReminderMinutes = prefs.getInt(keyGlobalReminderMinutes) ?? 60;
      _hasSeenRegionalWarning =
          prefs.getBool(keyHasSeenRegionalWarning) ?? false;

      if (!_isBiometricEnabled) {
        _medicalRecordsLocked = false;
        await prefs.setBool(keyMedicalRecordsLocked, false);
      }

      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint("SettingsNotifier: Failed to load settings: $e");
    }
  }

  // Security Updaters
  Future<void> update2FAEnabled(bool value) async {
    if (_is2FAEnabled == value) return;
    _is2FAEnabled = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key2FAEnabled, value);
      
    } catch (e) {
      debugPrint("SettingsNotifier: Failed to save 2FA status: $e");
    }
  }

  Future<void> updateBiometricState(bool hasHardware, bool isEnabled) async {
    _hasBiometricHardware = hasHardware;
    _isBiometricEnabled = isEnabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyHasBiometricHardware, hasHardware);
      await prefs.setBool(keyIsBiometricEnabled, isEnabled);
      if (!isEnabled) {
        await updateMedicalRecordsLock(false);
      }
    } catch (e) {
      debugPrint("SettingsNotifier: Failed to save biometric state: $e");
    }
  }

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

  // App Preference Updaters
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

  // --- Notification Updaters ---
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

  Future<void> updateBookingAlertsEnabled(bool enabled) async {
    _bookingAlertsEnabled = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyBookingAlertsEnabled, enabled);
    } catch (e) {
      debugPrint("SettingsNotifier: Failed to save booking alerts: $e");
    }
  }

  Future<void> updateReminderAlertsEnabled(bool enabled) async {
    _reminderAlertsEnabled = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyReminderAlertsEnabled, enabled);
    } catch (e) {
      debugPrint("SettingsNotifier: Failed to save reminder alerts: $e");
    }
  }

  Future<void> updateFiveHourWarningEnabled(bool enabled) async {
    _fiveHourWarningEnabled = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyFiveHourWarningEnabled, enabled);
    } catch (e) {
      debugPrint("SettingsNotifier: Failed to save 5-hour warning toggle: $e");
    }
  }

  Future<void> updateMorningOfReminderEnabled(bool enabled) async {
    _morningOfReminderEnabled = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyMorningOfReminderEnabled, enabled);
    } catch (e) {
      debugPrint("SettingsNotifier: Failed to save morning-of reminder: $e");
    }
  }

  Future<void> updateMissedAppointmentAlertEnabled(bool enabled) async {
    _missedAppointmentAlertEnabled = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyMissedAppointmentAlertEnabled, enabled);
    } catch (e) {
      debugPrint(
        "SettingsNotifier: Failed to save missed appointment alert toggle: $e",
      );
    }
  }

  Future<void> updateAppUpdatesEnabled(bool enabled) async {
    _appUpdatesEnabled = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyAppUpdatesEnabled, enabled);
    } catch (e) {
      debugPrint("SettingsNotifier: Failed to save app updates alerts: $e");
    }
  }

  Future<void> updateGlobalReminderMinutes(int mins) async {
    _globalReminderMinutes = mins;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(keyGlobalReminderMinutes, mins);
    } catch (e) {
      debugPrint("SettingsNotifier: Failed to save reminder time: $e");
    }
  }

  // --- Geofence Updaters ---
  Future<void> markRegionalWarningSeen() async {
    _hasSeenRegionalWarning = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyHasSeenRegionalWarning, true);
    } catch (e) {
      debugPrint(
        "SettingsNotifier: Failed to save regional warning state: $e",
      );
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
    _medicalRecordsLocked = false;
    _hasBiometricHardware = false;
    _isBiometricEnabled = false;
    _is2FAEnabled = false;

    _notificationsEnabled = true;
    _bookingAlertsEnabled = true;
    _reminderAlertsEnabled = true;
    _fiveHourWarningEnabled = true;
    _morningOfReminderEnabled = true;
    _missedAppointmentAlertEnabled = true;
    _appUpdatesEnabled = true;
    _globalReminderMinutes = 60;
    _hasSeenRegionalWarning = false;

    notifyListeners();
  }
}
