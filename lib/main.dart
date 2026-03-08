import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/constants/app_routes.dart';
import 'core/network/network_notifier.dart';
import 'core/router/app_router.dart';
import 'core/security/device_integrity_service.dart';
import 'core/services/appointment_notification_service.dart';
import 'core/services/error_telemetry_service.dart';
import 'core/widgets/app_error_fallback.dart';
import 'features/settings/presentation/settings_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Hive.initFlutter();

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  await SettingsNotifier.instance.loadSettings();
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
