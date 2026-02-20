import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/localization/app_localizations.dart';
import 'features/settings/presentation/settings_notifier.dart';

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

          // Locale Settings (Locked to English)
          locale: const Locale('en', 'US'),
          supportedLocales: const [Locale('en', 'US')],

          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          routerConfig: appRouter,
        );
      },
    );
  }
}
