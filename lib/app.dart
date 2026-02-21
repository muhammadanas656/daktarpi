import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/localization/app_localizations.dart';
import 'core/network/offline_mode_guard.dart';
import 'features/settings/presentation/settings_notifier.dart';
import 'core/security/inactivity_lock_guard.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to SettingsNotifier for Theme changes
    return AnimatedBuilder(
      animation: SettingsNotifier.instance,
      builder: (context, child) {
        return MaterialApp.router(
          title: 'DaktarPai',
          debugShowCheckedModeBanner: false,

          // Theme Settings
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: SettingsNotifier.instance.themeMode,

          // Locale Settings
          locale: const Locale('en', 'US'),
          supportedLocales: const [Locale('en', 'US'), Locale('bn', 'BD')],

          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          routerConfig: appRouter,
          builder: (context, child) {
            if (child == null) {
              return const SizedBox.shrink();
            }
            return OfflineModeGuard(child: InactivityLockGuard(child: child));
          },
        );
      },
    );
  }
}
