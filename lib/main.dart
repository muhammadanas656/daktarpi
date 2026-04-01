import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
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
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'is_read': false,
      'payload': payload,
      if (message.messageId != null) 'message_id': message.messageId,
    };

    // D. Add to unsynced queue using Hive directly (bypassing Supabase/Repo)
    // We cannot use Supabase or NotificationRepository here because the
    // background isolate does not have the .env variables or auth session.
    try {
      final box = await Hive.openBox('notifications_box');
      final List<dynamic> queue = box.get('unsynced_notifs') ?? [];
      queue.add(newNotif);
      await box.put('unsynced_notifs', queue);
      
      debugPrint(
        '✅ Background Isolate: Saved ${title} to Hive unsynced queue successfully!',
      );
    } catch (e) {
      debugPrint('❌ Background Isolate: Failed to save to Hive: $e');
    }

    debugPrint(
      '✅ Background Isolate: Saved notification to unsynced queue + cache!',
    );
  }
}

Future<void> _runStartupStepVoid(
  String label,
  Future<void> Function() action, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  try {
    await action().timeout(timeout);
  } catch (e) {
    debugPrint('Startup step failed: $label -> $e');
  }
}

Future<T> _runStartupStepValue<T>(
  String label,
  Future<T> Function() action, {
  required T fallback,
  Duration timeout = const Duration(seconds: 5),
}) async {
  try {
    return await action().timeout(timeout);
  } catch (e) {
    debugPrint('Startup step failed: $label -> $e');
    return fallback;
  }
}

Future<void> _startDeferredServices() async {
  await _runStartupStepVoid(
    'settings.load',
    () => SettingsNotifier.instance.loadSettings(),
  );
  await _runStartupStepVoid(
    'notifications.load',
    () => NotificationNotifier.instance.load(),
  );

  // The core app is now ready and loaded. Remove the native splash screen!
  FlutterNativeSplash.remove();

  unawaited(
    _runStartupStepVoid(
      'local_notifications.initialize',
      () => AppointmentNotificationService.instance.initialize(),
    ),
  );
  unawaited(
    _runStartupStepVoid(
      'network.initialize',
      () async {
        NetworkNotifier.instance.initialize();
      },
    ),
  );

  final hasFirebaseApp = Firebase.apps.isNotEmpty;

  if (hasFirebaseApp && Supabase.instance.client.auth.currentSession != null) {
    unawaited(
      _runStartupStepVoid(
        'fcm.initialize.current_session',
        () => FcmService.instance.initialize(),
      ),
    );
  }

  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    if (hasFirebaseApp && data.session != null) {
      unawaited(
        _runStartupStepVoid(
          'fcm.initialize.auth_change',
          () => FcmService.instance.initialize(),
        ),
      );
    }
  });
}

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

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
  await _runStartupStepVoid(
    'dotenv.load',
    () => dotenv.load(fileName: ".env"),
  );
  await _runStartupStepVoid(
    'hive.init',
    () => Hive.initFlutter(),
  );

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  final deviceCompromised = await _runStartupStepValue<bool>(
    'device_integrity.enforce',
    () => DeviceIntegrityService().enforceOnStartup(),
    fallback: false,
    timeout: const Duration(seconds: 3),
  );

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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (deviceCompromised) {
          FlutterNativeSplash.remove();
          return;
        }
        unawaited(_startDeferredServices());
      });
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
