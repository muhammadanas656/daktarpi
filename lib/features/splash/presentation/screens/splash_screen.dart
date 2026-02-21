import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/data/auth_entry_route_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthEntryRouteService _authEntryRouteService = AuthEntryRouteService();

  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final target = await _authEntryRouteService.resolvePostAuthRoute();
    if (!mounted) {
      return;
    }
    context.go(target);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.5, 1.0],
            colors: [
              AppColors.scaffoldBackground,
              Colors.white,
              AppColors.primaryGreen.withValues(alpha: 0.1),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Image.asset(
                'assets/images/logo.png',
                width: 120,
                height: 120,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.medical_services_rounded,
                    size: 100,
                    color: AppColors.primaryGreen,
                  );
                },
              ),

              const SizedBox(height: 20),

              // --- BRAND NAME WITH NUNITO FONT ---
              Text(
                'DaktarPai',
                style: AppTextStyles.h1.copyWith(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
