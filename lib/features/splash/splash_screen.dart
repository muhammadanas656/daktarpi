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
    // 1. Keep the splash screen visible for 2 seconds
    await Future.delayed(const Duration(seconds: 2));

    // 2. Check Supabase Auth Session
    final session = Supabase.instance.client.auth.currentSession;

    if (!mounted) return;

    // 3. Navigate based on auth state
    if (session != null) {
      context.go('/home');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The gradient background matching the design
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE0F7FA), // Light Blue/White at top
              Color(0xFFE0F2F1), // Soft Teal middle
              Color(0xFFB2DFDB), // Darker Teal at bottom
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // --- LOGO SECTION ---
              // If you have your logo asset, uncomment the lines below and remove the Icon:
              Image.asset('assets/images/logo.png', width: 100, height: 100),

              const SizedBox(height: 24),

              // --- BRAND NAME ---
              const Text(
                'DaktarPai',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A2338), // Dark Navy/Black text
                  letterSpacing: -0.5,
                  fontFamily: 'Nunito', // Default, or add your specific font
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
