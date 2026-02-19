import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/localization/app_localizations.dart'; // Import Custom Localization
import 'features/settings/presentation/settings_notifier.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to SettingsNotifier for Theme and Locale changes
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
          locale: SettingsNotifier.instance.locale,
          supportedLocales: const [
            Locale('en', 'US'), // English
            Locale('bn', 'BD'), // Bengali
          ],
          
          localizationsDelegates: const [
            AppLocalizations.delegate, // Custom Delegate
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
