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

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);
    await _requestPermissions();
    _initialized = true;
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

    await initialize();

    final triggerUtc =
        appointmentLocalDateTime.subtract(Duration(minutes: reminderMinutes))
            .toUtc();
    final nowUtc = DateTime.now().toUtc();
    if (!triggerUtc.isAfter(nowUtc)) {
      await cancelReminder(appointmentId);
      return;
    }

    final title = 'Appointment reminder';
    final appointmentTime = DateFormat('h:mm a').format(appointmentLocalDateTime);
    final body = 'You have an appointment with $doctorName at $appointmentTime.';

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

    await _plugin.cancel(appointmentId);
    await _plugin.zonedSchedule(
      appointmentId,
      title,
      body,
      tz.TZDateTime.from(triggerUtc, tz.UTC),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'appointment:$appointmentId',
    );
  }

  Future<void> cancelReminder(int appointmentId) async {
    if (!_isSupportedPlatform) {
      return;
    }
    await initialize();
    await _plugin.cancel(appointmentId);
  }

  Future<void> _requestPermissions() async {
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();

    final iosImpl = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);
  }
}
