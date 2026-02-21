import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/constants/app_routes.dart';
import 'core/router/app_router.dart';
import 'core/services/error_telemetry_service.dart';
import 'core/widgets/app_error_fallback.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
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
      onGoHome: () {
        try {
          appRouter.go(AppRoutes.home);
        } catch (_) {
          appRouter.go(AppRoutes.login);
        }
      },
    );
  };

  runZonedGuarded(() => runApp(const MyApp()), (error, stack) {
    unawaited(
      telemetryService.logError(error, stack, source: 'run_zoned_guarded'),
    );
  });
}
