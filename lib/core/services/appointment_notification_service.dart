import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../../features/notifications/presentation/notification_notifier.dart';
import '../../core/router/app_router.dart';

/// Schedules strict appointment reminders on-device using absolute UTC time.
class AppointmentNotificationService {
  AppointmentNotificationService._();
  static final AppointmentNotificationService instance =
      AppointmentNotificationService._();
  static const String _standardReminderTitle = 'Appointment reminder';
  static const String _fiveHourWarningTitle = 'Upcoming Appointment Reminder';
  static const String _morningOfReminderTitle = 'Appointment Today';
  static const String _statusUpdateTitle = 'Appointment Status Update';
  static const Set<String> _nonMissedReminderTitles = {
    _standardReminderTitle,
    _fiveHourWarningTitle,
    _morningOfReminderTitle,
  };

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _permissionsRequested = false;
  Future<void>? _permissionRequestFuture;

  bool get _isSupportedPlatform {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  // Inside AppointmentNotificationService
  Future<void> initialize() async {
    if (_initialized || !_isSupportedPlatform) {
      return;
    }

    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // --- PRO FIX: Listen for physical taps on local notifications! ---
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Import your router file at the top of this file to access handleNotificationTap!
        handleNotificationTap(response.payload);
      },
    );

    _initialized = true;
  }

  Future<void> _ensurePermissions() async {
    if (!_isSupportedPlatform) {
      return;
    }
    if (_permissionsRequested) {
      return;
    }
    if (_permissionRequestFuture != null) {
      await _permissionRequestFuture;
      return;
    }

    final future = () async {
      await initialize();

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

      _permissionsRequested = true;
    }();

    _permissionRequestFuture = future;
    try {
      await future;
    } finally {
      _permissionRequestFuture = null;
    }
  }

  Future<void> showBookingConfirmation({
    required int appointmentId,
    required String doctorName,
    required String appointmentTime,
  }) async {
    if (!_isSupportedPlatform) return;

    try {
      await _ensurePermissions();
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

      // Keep the immediate confirmation on its own ID range so it cannot
      // overwrite the morning-of appointment reminder for the same booking.
      final immediateId = appointmentId.abs() + 400000;
      await _plugin.show(immediateId, title, body, notificationDetails);
    } catch (e) {
      debugPrint("Failed to show immediate confirmation notification: $e");
    }
  }

  Future<void> showPushNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isSupportedPlatform) return;

    try {
      await _ensurePermissions();
      await initialize();

      const notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          'push_notifications',
          'Push Notifications',
          channelDescription: 'General alerts and updates',
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

      final immediateId = DateTime.now().millisecondsSinceEpoch.remainder(
        100000,
      ) + 500000;

      await _plugin.show(
        immediateId,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint("Failed to show foreground push notification: $e");
    }
  }

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

  Future<void> scheduleReminder({
    required int appointmentId,
    required DateTime appointmentLocalDateTime,
    DateTime? appointmentEndDateTime,
    required int reminderMinutes,
    required String doctorName,
    bool includeFiveHourWarning = true,
    bool includeMissedStatusUpdate = true,
  }) async {
    if (!_isSupportedPlatform) return;
    await _ensurePermissions();
    await initialize();

    final safeId = appointmentId.abs();
    final appointmentTime = DateFormat(
      'h:mm a',
    ).format(appointmentLocalDateTime);
    final payloadString = 'appointment:$safeId';

    final nowUtc = DateTime.now().toUtc();
    final desiredReminderUtc =
        appointmentLocalDateTime
            .subtract(Duration(minutes: reminderMinutes))
            .toUtc();
    final appointmentTimeUtc = appointmentLocalDateTime.toUtc();

    DateTime finalReminderTimeUtc = desiredReminderUtc;
    if (desiredReminderUtc.isBefore(nowUtc) &&
        appointmentTimeUtc.isAfter(nowUtc)) {
      finalReminderTimeUtc = nowUtc.add(const Duration(seconds: 5));
    }

    // 1. Standard Reminder (OS)
    await _scheduleWithFallback(
      id: safeId,
      title: _standardReminderTitle,
      body: 'You have an appointment with $doctorName at $appointmentTime.',
      triggerUtc: finalReminderTimeUtc,
      payload: payloadString,
    );

    // 2. The 5-Hour Cancellation Warning (OS)
    final cancellationWarningUtc =
        appointmentLocalDateTime.subtract(const Duration(hours: 5)).toUtc();
    if (includeFiveHourWarning) {
      await _scheduleWithFallback(
        id: safeId + 200000,
        title: _fiveHourWarningTitle,
        body:
            'Your visit with $doctorName is in 5 hours. Please note that cancellations cannot be made within 4 hours of your scheduled time.',
        triggerUtc: cancellationWarningUtc,
        payload: payloadString,
      );
    } else {
      await _plugin.cancel(safeId + 200000);
    }

    // 2.5 The Morning-of Notification (OS) - 8:00 AM on the day of the appointment
    final morningOfLocal = DateTime(
      appointmentLocalDateTime.year,
      appointmentLocalDateTime.month,
      appointmentLocalDateTime.day,
      8, // 8:00 AM
      0,
    );
    final morningOfUtc = morningOfLocal.toUtc();

    // Only schedule if 8:00 AM is in the future AND it is strictly before the actual appointment
    // (We don't want an 8:00 AM reminder for an 8:00 AM appointment)
    if (morningOfUtc.isAfter(nowUtc) &&
        morningOfLocal.isBefore(appointmentLocalDateTime)) {
      await _scheduleWithFallback(
        id: safeId + 100000,
        title: _morningOfReminderTitle,
        body:
            'You have a scheduled visit with $doctorName today at $appointmentTime.',
        triggerUtc: morningOfUtc,
        payload: payloadString,
      );
    }

    // 3. The Time-Out / Resolution Notification (OS)
    final endDateTime =
        appointmentEndDateTime ??
        appointmentLocalDateTime.add(const Duration(minutes: 30));
    final endDateTimeUtc = endDateTime.toUtc();
    if (includeMissedStatusUpdate) {
      await _scheduleWithFallback(
        id: safeId + 300000,
        title: _statusUpdateTitle,
        body:
            'Your scheduled visit time has passed. If this appointment was missed or not completed, please open the app to contact the clinic or file a report.',
        triggerUtc: endDateTimeUtc,
        payload: payloadString,
      );
    } else {
      await _plugin.cancel(safeId + 300000);
      await NotificationNotifier.instance.deleteNotificationsByPayload(
        payloadString,
        excludedTitles: _nonMissedReminderTitles,
      );
    }

    // --- PRO FIX: INBOX SYNC WITH METADATA ---
    // We pass the appointmentId as 'payload' so we can find and delete these exact
    // messages from the Hive database later if the appointment is canceled!

    if (finalReminderTimeUtc.isAfter(nowUtc)) {
      await NotificationNotifier.instance.addNotification(
        title: _standardReminderTitle,
        body: 'You have an appointment with $doctorName at $appointmentTime.',
        scheduledTime: finalReminderTimeUtc.toLocal(),
        payload: payloadString,
      );
    }

    if (includeFiveHourWarning && cancellationWarningUtc.isAfter(nowUtc)) {
      await NotificationNotifier.instance.addNotification(
        title: _fiveHourWarningTitle,
        body:
            'Your visit with $doctorName is in 5 hours. Please note that cancellations cannot be made within 4 hours of your scheduled time.',
        scheduledTime: cancellationWarningUtc.toLocal(),
        payload: payloadString,
      );
    }

    if (morningOfUtc.isAfter(nowUtc) &&
        morningOfLocal.isBefore(appointmentLocalDateTime)) {
      await NotificationNotifier.instance.addNotification(
        title: _morningOfReminderTitle,
        body:
            'You have a scheduled visit with $doctorName today at $appointmentTime.',
        scheduledTime: morningOfUtc.toLocal(),
        payload: payloadString,
      );
    }

    if (includeMissedStatusUpdate && endDateTimeUtc.isAfter(nowUtc)) {
      await NotificationNotifier.instance.addNotification(
        title: _statusUpdateTitle,
        body:
            'Your scheduled visit time has passed. If this appointment was missed or not completed, please open the app to contact the clinic or file a report.',
        scheduledTime: endDateTime.toLocal(),
        payload: payloadString,
      );
    }
  }

  /// Cancels all scheduled alerts tied to a specific appointment ID AND scrubs them from the inbox!
  Future<void> cancelReminder(
    int appointmentId, {
    bool preserveMissedStatusUpdate = false,
  }) async {
    if (!_isSupportedPlatform) return;
    await initialize();

    final safeId = appointmentId.abs();

    // 1. Stop the OS from vibrating the phone
    await _plugin.cancel(safeId); // Standard Reminder
    await _plugin.cancel(safeId + 100000); // Morning-of Reminder
    await _plugin.cancel(safeId + 200000); // Cancellation Warning
    if (!preserveMissedStatusUpdate) {
      await _plugin.cancel(safeId + 300000); // Time-Out Notification
    }

    // 2. PRO FIX: Scrub the future-dated "ghost" messages from the local Hive inbox!
    await NotificationNotifier.instance.deleteNotificationsByPayload(
      'appointment:$safeId',
      excludedTitles:
          preserveMissedStatusUpdate ? {_statusUpdateTitle} : const {},
    );
  }

  Future<void> cancelAllReminders() async {
    if (!_isSupportedPlatform) return;
    await initialize();
    await _plugin.cancelAll();
  }

  Future<void> requestPermissions() async {
    await _ensurePermissions();
  }
}
