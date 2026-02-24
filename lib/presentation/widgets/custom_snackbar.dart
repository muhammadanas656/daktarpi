import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_shapes.dart';

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
    return Positioned(
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
              position: AlwaysStoppedAnimation(Offset(0, 1 - value)),
              child: ScaleTransition(
                scale: AlwaysStoppedAnimation(value),
                child: FadeTransition(
                  opacity: AlwaysStoppedAnimation(value.clamp(0.0, 1.0)),
                  child: child,
                ),
              ),
            );
          },
          child: GestureDetector(
            onTap: onDismiss, // Dismiss on tap
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceXl,
                vertical: AppDimens.spaceMdPlus,
              ),
              decoration: BoxDecoration(
                color: color,
                borderRadius: AppShapes.pill,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 22),
                  const SizedBox(width: AppDimens.spaceMd),
                  Flexible(
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
