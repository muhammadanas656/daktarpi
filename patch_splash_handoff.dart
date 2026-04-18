import 'dart:io';

void main() {
  final file = File('lib/features/splash/presentation/screens/splash_screen.dart');
  var content = file.readAsStringSync();

  // 1. Remove the custom _isFadingOut local state and its trigger logic
  content = content.replaceAll('''            // Restore the elegant localized fade-out the user requested!
            setState(() {
              _isFadingOut = true;
            });

            // Wait for it to become a perfectly blank slate before pushing the heavy router!
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                context.go(AppRoutes.home);
              }
            });''', '''            if (mounted) {
              // Directly hand off to GoRouter!
              // GoRouter will use CustomTransitionPage to cross-dissolve the Home Screen 
              // perfectly on top of this static splash screen frame natively!
              context.go(AppRoutes.home);
            }''');

  // 2. Remove the IgnorePointer Overlay block
  content = content.replaceFirst('''          // PRO FIX: Foreground Overlay Alpha-Blend (Zero SaveLayer Overhead!)
          // By fading IN a solid rectangle OVER the animation, we bypass Flutter
          // invoking expensive composite SaveLayer buffering on the entire deep Lottie tree!
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _isFadingOut ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInQuad,
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
              ),
            ),
          ),''', '');
          
  file.writeAsStringSync(content);
}
