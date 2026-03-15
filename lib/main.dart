import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // This fixes RemoteMessage & FirebaseMessaging
import 'firebase_options.dart'; // This fixes DefaultFirebaseOptions
import 'core/services/fcm_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'app.dart';
import 'core/constants/app_routes.dart';
import 'core/network/network_notifier.dart';
import 'core/router/app_router.dart';
import 'core/security/device_integrity_service.dart';
import 'core/services/appointment_notification_service.dart';
import 'core/services/error_telemetry_service.dart';
import 'core/widgets/app_error_fallback.dart';
import 'features/notifications/data/notification_repository.dart';
import 'features/notifications/presentation/notification_notifier.dart';
import 'features/settings/presentation/settings_notifier.dart';

// 1. Add this TOP-LEVEL function (must be outside any class)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // A. Initialize the core engines for this isolated background worker
  await Firebase.initializeApp();
  await Hive.initFlutter();

  debugPrint('🌙 Background Isolate Woke Up: Processing FCM Message');

  // B. Check if it's a visible notification
  if (message.notification != null) {
    final title = message.notification!.title ?? 'New Notification';
    final body = message.notification!.body ?? '';
    final payload = message.data.toString();

    // C. Create the raw data map (mirroring what the Notifier does)
    final newNotif = {
      'id': const Uuid().v4(),
      'title': title,
      'body': body,
      'timestamp': DateTime.now().toIso8601String(),
      'is_read': false,
      'payload': payload,
    };

    // D. Talk directly to the physical database (bypassing the UI Notifier)
    final repo = NotificationRepository();

    // Fetch, insert, sort, and save
    final notifications = await repo.getNotifications();
    notifications.insert(0, newNotif);
    notifications.sort(
      (a, b) => DateTime.parse(
        b['timestamp'],
      ).compareTo(DateTime.parse(a['timestamp'])),
    );

    await repo.saveNotifications(notifications);
    debugPrint(
      '✅ Background Isolate: Successfully saved ghost notification to Hive!',
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // 2. Add this line right after Firebase.initializeApp
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint(
      'Firebase not initialized for this platform (usually missing android firebase_options.dart): $e',
    );
  }
  await dotenv.load(fileName: ".env");
  await Hive.initFlutter();

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // 2. Start the FCM Service to grab the token
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    if (data.session != null) {
      FcmService.instance.initialize();
    }
  });

  await SettingsNotifier.instance.loadSettings();
  await NotificationNotifier.instance.load();
  await AppointmentNotificationService.instance.initialize();
  NetworkNotifier.instance.initialize();
  final deviceCompromised = await DeviceIntegrityService().enforceOnStartup();

  final telemetryService = ErrorTelemetryService();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(telemetryService.logFlutterError(details));
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(
      telemetryService.logError(error, stack, source: 'platform_dispatcher'),
    );
    return true;
  };

  ErrorWidget.builder = (details) {
    unawaited(
      telemetryService.logFlutterError(details, source: 'error_widget'),
    );
    return AppErrorFallback(
      errorDetails: details, // <--- NEW: Handing the error to the UI!
      onGoHome: () {
        try {
          appRouter.go(AppRoutes.home);
        } catch (_) {
          appRouter.go(AppRoutes.login);
        }
      },
    );
  };

  runZonedGuarded(
    () {
      runApp(deviceCompromised ? const _CompromisedDeviceApp() : const MyApp());
    },
    (error, stack) {
      unawaited(
        telemetryService.logError(error, stack, source: 'run_zoned_guarded'),
      );
    },
  );
}

class _CompromisedDeviceApp extends StatelessWidget {
  const _CompromisedDeviceApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.security, size: 48, color: Color(0xFF2F855A)),
                  SizedBox(height: 16),
                  Text(
                    'Security Check Failed',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'This device appears rooted or jailbroken. '
                    'Sensitive local data was cleared and the session was signed out.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
