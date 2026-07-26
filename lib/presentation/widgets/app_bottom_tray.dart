import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

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

    // Keyboard interaction: Slides down, shrinks slightly, and fades out.
    return AnimatedSlide(
      duration: const Duration(milliseconds: 300),
      curve: Curves.fastOutSlowIn,
      offset: bottomInset > 0 ? const Offset(0, 0.5) : Offset.zero,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 300),
        curve: Curves.fastOutSlowIn,
        scale: bottomInset > 0 ? 0.95 : 1.0,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: bottomInset > 0 ? 0.0 : 1.0,
          child: Padding(
            // Detaches from the bottom edge to create the "Floating Pill" effect
            padding: EdgeInsets.fromLTRB(24, 0, 24, safeBottom > 0 ? safeBottom : 24),
            child: Container(
              // Bioluminescent Down-cast Shadow
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryGreen.withValues(alpha: isDark ? 0.15 : 0.12),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Z-Buffer
                    Positioned.fill(
                      child: Container(
                        color: isDark 
                            ? const Color(0xFF050608).withValues(alpha: 0.55) 
                            : const Color(0xFFFFFFFF).withValues(alpha: 0.70),
                      ),
                    ),
                    // Hyper-Blur Glass
                    BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40, tileMode: TileMode.mirror),
                      child: Container(
                        padding: const EdgeInsets.all(12), // Inner padding around the button
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.04),
                            width: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 54, // Locks the internal button height
                          child: child,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}