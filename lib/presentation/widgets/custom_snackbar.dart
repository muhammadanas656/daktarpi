import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_shapes.dart';
import '../../core/theme/app_styles.dart';
import '../../core/theme/app_text_styles.dart';

class CustomSnackbar {
  static OverlayEntry? _overlayEntry;
  static Timer? _timer;

  static void showSuccess(BuildContext context, String message) {
    _show(context, message, AppColors.primaryGreen, Icons.check_circle_rounded);
  }

  static void showError(BuildContext context, String message) {
    _show(context, message, AppColors.dangerRed, Icons.error_outline_rounded);
  }

  static void showInfo(BuildContext context, String message) {
    _show(context, message, AppColors.infoBlue, Icons.info_outline_rounded);
  }

  static void _show(
    BuildContext context,
    String message,
    Color color,
    IconData icon,
  ) {
    _cleanup();

    final overlayState = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder:
          (context) => _SnackbarOverlay(
            message: message,
            color: color,
            icon: icon,
            onDismiss: _cleanup,
          ),
    );

    overlayState.insert(_overlayEntry!);

    _timer = Timer(AppMotion.snackbarVisible, _cleanup);
  }

  static void _cleanup() {
    _timer?.cancel();
    if (_overlayEntry != null) {
      try {
        _overlayEntry?.remove();
      } catch (_) {}
      _overlayEntry = null;
    }
  }
}

class _SnackbarOverlay extends StatelessWidget {
  final String message;
  final Color color;
  final IconData icon;
  final VoidCallback onDismiss;

  const _SnackbarOverlay({
    required this.message,
    required this.color,
    required this.icon,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      // Respects the keyboard and adds standard spacing
      bottom: MediaQuery.of(context).viewInsets.bottom + AppDimens.space4xl,
      left: AppDimens.spaceXl,
      right: AppDimens.spaceXl,
      child: Material(
        color: Colors.transparent,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: AppMotion.standard,
          curve: AppMotion.emphasized,
          builder: (context, value, child) {
            return SlideTransition(
              position: AlwaysStoppedAnimation(Offset(0, 0.5 * (1 - value))),
              child: FadeTransition(
                opacity: AlwaysStoppedAnimation(value.clamp(0.0, 1.0)),
                child: child,
              ),
            );
          },
          child: GestureDetector(
            onTap: onDismiss,
            child: ClipRRect(
              borderRadius: AppShapes.pill,
              child: BackdropFilter(
                // PRO FIX: Added Glassmorphism blur for a premium medical look
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceXl,
                    vertical: AppDimens.spaceMdPlus,
                  ),
                  decoration: BoxDecoration(
                    // PRO FIX: Surface-aware background with a 10% brand tint
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: isDark ? 0.8 : 0.9),
                    borderRadius: AppShapes.pill,
                    border: Border.all(
                      // Uses your brand color for a subtle accent border
                      color: color.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    boxShadow: AppStyles.elevatedShadow(context),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon with dedicated tinted background
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      const SizedBox(width: AppDimens.spaceMd),
                      Flexible(
                        child: Text(
                          message,
                          style: AppTextStyles.bodyBold(context).copyWith(
                            fontSize: 14,
                            // Dynamic text color for maximum readability
                            color: context.colorTextDark,
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
      ),
    );
  }
}
