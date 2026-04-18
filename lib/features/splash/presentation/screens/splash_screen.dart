import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Lottie playback — duration is set from the composition (~3.1s)
  late final AnimationController _lottieController;

  // Text reveal — fixed 800ms, fully independent of the Lottie timeline
  late final AnimationController _textController;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;

  // Guard: ensures the boot sequence only fires once, even if onLoaded re-fires on rebuild
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();

    _lottieController = AnimationController(vsync: this);
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeIn),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );

    // Navigate home once the Lottie fully completes + breathing room
    _lottieController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) context.go(AppRoutes.home);
        });
      }
    });
  }

  @override
  void dispose() {
    _lottieController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final animationFile = isDark ? 'darkmode.json' : 'lightmode.json';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Logo Lottie ──────────────────────────────────────
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.35,
              child: RepaintBoundary(
                child: Lottie.asset(
                  'assets/animations/$animationFile',
                  controller: _lottieController,
                  frameRate: const FrameRate(60),
                  options: LottieOptions(enableMergePaths: true),
                  repeat: false,
                  fit: BoxFit.contain,
                  onLoaded: (composition) {
                    // GUARD: onLoaded can re-fire on widget rebuilds — only boot once
                    if (_hasInitialized) return;
                    _hasInitialized = true;

                    // Lock the controller to the composition's native duration
                    _lottieController.duration = composition.duration;

                    // Text starts at 60% into the Lottie timeline
                    // For a 3.1s animation this is ~1.86s — logo establishes before text appears
                    final textDelay = Duration(
                      milliseconds: (composition.duration.inMilliseconds * 0.6).round(),
                    );

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      // Phase 1: Hold native splash so Lottie frame 0 is rasterized
                      Future.delayed(const Duration(milliseconds: 800), () {
                        FlutterNativeSplash.remove();

                        // Phase 2: OS dissolve buffer, then single clean forward
                        Future.delayed(const Duration(milliseconds: 400), () {
                          if (!mounted) return;

                          // Single forward call — guarded, no restart possible
                          _lottieController.forward(from: 0.0);

                          // Phase 3: Text reveal fires independently at the calculated offset
                          Future.delayed(textDelay, () {
                            if (mounted) _textController.forward(from: 0.0);
                          });
                        });
                      });
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Brand Name ───────────────────────────────────────
            SlideTransition(
              position: _textSlide,
              child: FadeTransition(
                opacity: _textFade,
                child: Text(
                  'AeviaPulse',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: isDark ? Colors.white : AppColors.primaryGreen,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
