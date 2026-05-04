import 'dart:ui';
import 'package:flutter/material.dart';

class AppBottomTray extends StatelessWidget {
  final Widget child;

  const AppBottomTray({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    // PRO FIX 1: Smoothly animate the tray away when the keyboard opens instead of snapping!
    return AnimatedSlide(
      duration: const Duration(milliseconds: 250),
      curve: Curves.fastOutSlowIn,
      offset: bottomInset > 0 ? const Offset(0, 1.5) : Offset.zero,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: bottomInset > 0 ? 0.0 : 1.0,
        child: ClipRRect(
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // PRO FIX 2: The Z-Index Buffer. Eats harsh shadows from scrolled content!
              Positioned.fill(
                child: Container(
                  color: isDark 
                      ? Colors.black.withValues(alpha: 0.6) 
                      : Colors.white.withValues(alpha: 0.8),
                ),
              ),
              // PRO FIX 3: True Glassmorphism with Ultra-Thin Hairline
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24, tileMode: TileMode.mirror),
                child: Container(
                  // PRO FIX 4: Precise Math. NO SafeArea widget used here to prevent double-padding!
                  padding: EdgeInsets.fromLTRB(24, 16, 24, safeBottom > 0 ? safeBottom + 8 : 24),
                  decoration: BoxDecoration(
                    color: Colors.transparent, // Handled by the buffer layer
                    border: Border(
                      top: BorderSide(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                        width: 0.5, // Hairline stroke
                      ),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: child,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
