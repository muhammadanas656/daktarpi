import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import '../../../auth/data/auth_entry_route_service.dart';
import '../../../../core/widgets/premium_app_loader.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  final AuthEntryRouteService _authEntryRouteService = AuthEntryRouteService();
  
  late AnimationController _revealController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _revealController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
      CurvedAnimation(parent: _revealController, curve: Curves.easeOutQuart),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
      _revealController.forward();
      
      // --- PRO FIX: The Thread Starvation Buffer ---
      // We give the Flutter Engine 150ms to start the animation loop 
      // BEFORE we slam the CPU with heavy Auth/Database reading!
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) _redirect();
      });
    });
  }

  @override
  void dispose() {
    _revealController.dispose();
    super.dispose();
  }

  Future<void> _redirect() async {
    final results = await Future.wait([
      _authEntryRouteService.resolvePostAuthRoute(skipServerValidation: true),
      Future.delayed(const Duration(milliseconds: 1500)),
    ]);

    if (!mounted) return;
    context.go(results[0] as String);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryGreen.withValues(alpha: 0.15),
                        blurRadius: 40,
                        spreadRadius: 10,
                      )
                    ]
                  ),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 110,
                    height: 110,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.medical_services_rounded,
                        size: 90,
                        color: AppColors.primaryGreen,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'DaktarPai',
                  style: AppTextStyles.h1(context).copyWith(
                    fontSize: 38, 
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 48),
                const PremiumAppLoader(size: 36),
              ],
            ),
          ),
        ),
      ),
    );
  }
}