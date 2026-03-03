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
    if (!_isSupportedPlatform) {
      return;
    }

    try {
      await initialize();

      const title = 'Booking Confirmed! ✅';
      final body = 'Your appointment with $doctorName is set for $appointmentTime.';

      const notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          'booking_confirmations', // Use a separate channel for immediate alerts
          'Booking Confirmations',
          channelDescription: 'Immediate alerts when an appointment is successfully booked',
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

      // We add 100000 to the ID so this immediate notification doesn't 
      // accidentally overwrite the future scheduled reminder!
      final immediateId = appointmentId.abs() + 100000;

      await _plugin.show(
        immediateId,
        title,
        body,
        notificationDetails,
      );
    } catch (e) {
      debugPrint("Failed to show immediate confirmation notification: $e");
    }
  }

  Future<void> scheduleReminder({
    required int appointmentId,
    required DateTime appointmentLocalDateTime,
    required int reminderMinutes,
    required String doctorName,
  }) async {
    if (!_isSupportedPlatform) {
      return;
    }

    try {
      await initialize();

      final safeId = appointmentId.abs();
      final triggerUtc =
          appointmentLocalDateTime
              .subtract(Duration(minutes: reminderMinutes))
              .toUtc();
      final nowUtc = DateTime.now().toUtc();
      if (!triggerUtc.isAfter(nowUtc)) {
        await cancelReminder(safeId);
        return;
      }

      final title = 'Appointment reminder';
      final appointmentTime = DateFormat(
        'h:mm a',
      ).format(appointmentLocalDateTime);
      final body =
          'You have an appointment with $doctorName at $appointmentTime.';

      final notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          'appointment_reminders',
          'Appointment Reminders',
          channelDescription: 'Time-sensitive appointment reminder alerts',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      await _plugin.cancel(safeId);
      await _plugin.zonedSchedule(
        safeId,
        title,
        body,
        tz.TZDateTime.from(triggerUtc, tz.UTC),
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'appointment:$safeId',
      );
    } catch (e) {
      debugPrint("Failed to schedule notification: $e");
      // Fallback to inexact if exact is denied on Android 14+
      try {
        final safeId = appointmentId.abs();
        final triggerUtc =
            appointmentLocalDateTime
                .subtract(Duration(minutes: reminderMinutes))
                .toUtc();
        final appointmentTime = DateFormat(
          'h:mm a',
        ).format(appointmentLocalDateTime);
        final title = 'Appointment reminder';
        final body =
            'You have an appointment with $doctorName at $appointmentTime.';
        final notificationDetails = NotificationDetails(
          android: AndroidNotificationDetails(
            'appointment_reminders',
            'Appointment Reminders',
            channelDescription: 'Time-sensitive appointment reminder alerts',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        );

        await _plugin.zonedSchedule(
          safeId,
          title,
          body,
          tz.TZDateTime.from(triggerUtc, tz.UTC),
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: 'appointment:$safeId',
        );
      } catch (e2) {
        debugPrint("Inexact fallback also failed: $e2");
      }
    }
  }

  Future<void> cancelReminder(int appointmentId) async {
    if (!_isSupportedPlatform) {
      return;
    }
    await initialize();
    await _plugin.cancel(appointmentId.abs());
  }

  Future<void> cancelAllReminders() async {
    if (!_isSupportedPlatform) {
      return;
    }
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
