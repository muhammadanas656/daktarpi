import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Load Env
  await dotenv.load(fileName: ".env");

  // 2. Init Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 3. Use .router constructor for Nav 2.0
    return MaterialApp.router(
      title: 'Supabase Flutter App',
      theme: ThemeData(primarySwatch: Colors.blue),
      routerConfig: appRouter, // Connects GoRouter
    );
  }
}
