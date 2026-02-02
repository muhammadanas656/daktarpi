import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    // 1. Simulate a short delay for splash animation (optional)
    await Future.delayed(const Duration(seconds: 2));

    // 2. Check Supabase Auth Session
    final session = Supabase.instance.client.auth.currentSession;

    if (!mounted) return;

    // 3. Navigation 2.0 Redirect
    if (session != null) {
      context.go('/home'); // User is logged in
    } else {
      context.go('/login'); // User needs to login
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text("Loading App..."),
          ],
        ),
      ),
    );
  }
}
