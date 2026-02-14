import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'DaktarPai',
      debugShowCheckedModeBanner: false,

      // USE YOUR NEW THEME HERE
      theme: AppTheme.lightTheme,

      routerConfig: appRouter,
    );
  }
}
