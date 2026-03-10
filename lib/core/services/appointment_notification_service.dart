import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Schedules strict appointment reminders on-device using absolute UTC time.
class AppointmentNotificationService {
  AppointmentNotificationService._();
  static final AppointmentNotificationService instance =
      AppointmentNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  bool get _isSupportedPlatform {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> initialize() async {
    if (_initialized || !_isSupportedPlatform) {
      return;
    }

    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);
    await _requestPermissions();
    _initialized = true;
  }

  /// Triggers an immediate notification to confirm the booking was successful.
  Future<void> showBookingConfirmation({
    required int appointmentId,
    required String doctorName,
    required String appointmentTime,
  }) async {
    if (!_isSupportedPlatform) return;

    try {
      await initialize();

      const title = 'Booking Confirmed! ✅';
      final body =
          'Your appointment with $doctorName is set for $appointmentTime.';

      const notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          'booking_confirmations',
          'Booking Confirmations',
          channelDescription:
              'Immediate alerts when an appointment is successfully booked',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      final immediateId = appointmentId.abs() + 100000;

      await _plugin.show(immediateId, title, body, notificationDetails);
    } catch (e) {
      debugPrint("Failed to show immediate confirmation notification: $e");
    }
  }

  /// Helper method to cleanly schedule a notification with Android 14+ exact-alarm fallbacks.
  Future<void> _scheduleWithFallback({
    required int id,
    required String title,
    required String body,
    required DateTime triggerUtc,
    required String payload,
  }) async {
    final nowUtc = DateTime.now().toUtc();
    if (!triggerUtc.isAfter(nowUtc)) return;

    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'appointment_reminders',
        'Appointment Reminders',
        channelDescription: 'Time-sensitive appointment reminder alerts',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    try {
      await _plugin.cancel(id);
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(triggerUtc, tz.UTC),
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
    } catch (e) {
      debugPrint("Exact scheduling failed for ID $id: $e");
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          tz.TZDateTime.from(triggerUtc, tz.UTC),
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: payload,
        );
      } catch (e2) {
        debugPrint("Inexact fallback also failed for ID $id: $e2");
      }
    }
  }

  /// Schedules the complete lifecycle of appointment alerts.
  Future<void> scheduleReminder({
    required int appointmentId,
    required DateTime appointmentLocalDateTime,
    DateTime?
    appointmentEndDateTime, // NEW: Added to support timeout notifications
    required int reminderMinutes,
    required String doctorName,
  }) async {
    if (!_isSupportedPlatform) return;
    await initialize();

    final safeId = appointmentId.abs();
    final appointmentTime = DateFormat(
      'h:mm a',
    ).format(appointmentLocalDateTime);
    final payloadString = 'appointment:$safeId';

    // 1. Standard Reminder (e.g., 30 or 60 minutes before)
    final nowUtc = DateTime.now().toUtc();
    final desiredReminderUtc = appointmentLocalDateTime
        .subtract(Duration(minutes: reminderMinutes))
        .toUtc();
    final appointmentTimeUtc = appointmentLocalDateTime.toUtc();

    // PRO FIX: If the global reminder (say 60 mins) implies a time that ALREADY HAPPENED, 
    // but the actual appointment is still in the future (say, starts in 5 mins),
    // we fire the reminder IMMEDIATELY.
    DateTime finalReminderTimeUtc = desiredReminderUtc;
    if (desiredReminderUtc.isBefore(nowUtc) && appointmentTimeUtc.isAfter(nowUtc)) {
      finalReminderTimeUtc = nowUtc.add(const Duration(seconds: 5));
    }

    await _scheduleWithFallback(
      id: safeId,
      title: 'Appointment reminder',
      body: 'You have an appointment with Dr. $doctorName at $appointmentTime.',
      triggerUtc: finalReminderTimeUtc,
      payload: payloadString,
    );

    // 2. The 5-Hour Cancellation Warning
    await _scheduleWithFallback(
      id: safeId + 200000,
      title: 'Upcoming Appointment Reminder',
      body:
          'Your visit with Dr. $doctorName is in 5 hours. Please note that cancellations cannot be made within 4 hours of your scheduled time.',
      triggerUtc:
          appointmentLocalDateTime.subtract(const Duration(hours: 5)).toUtc(),
      payload: payloadString,
    );

    // 3. The Time-Out / Resolution Notification
    // If end time isn't explicitly provided, default to 30 minutes after start.
    final endDateTime =
        appointmentEndDateTime ??
        appointmentLocalDateTime.add(const Duration(minutes: 30));
    await _scheduleWithFallback(
      id: safeId + 300000,
      title: 'Appointment Status Update',
      body:
          'Your scheduled visit time has passed. If this appointment was missed or not completed, please open the app to contact the clinic or file a report.',
      triggerUtc: endDateTime.toUtc(),
      payload: payloadString,
    );
  }

  /// Cancels all scheduled alerts tied to a specific appointment ID.
  Future<void> cancelReminder(int appointmentId) async {
    if (!_isSupportedPlatform) return;
    await initialize();

    final safeId = appointmentId.abs();
    await _plugin.cancel(safeId); // Standard Reminder
    await _plugin.cancel(safeId + 200000); // Cancellation Warning
    await _plugin.cancel(safeId + 300000); // Time-Out Notification
  }

  Future<void> cancelAllReminders() async {
    if (!_isSupportedPlatform) return;
    await initialize();
    await _plugin.cancelAll();
  }

  Future<void> _requestPermissions() async {
    final androidImpl =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();

    final iosImpl =
        _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
    await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);
  }
}
