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

class _SnackbarOverlay extends StatefulWidget {
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
  State<_SnackbarOverlay> createState() => _SnackbarOverlayState();
}

class _SnackbarOverlayState extends State<_SnackbarOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation; // opacity requires double
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.standard,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.emphasized,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.standardCurve,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: AppMotion.standardCurve),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: MediaQuery.of(context).viewInsets.bottom + AppDimens.space4xl,
      left: AppDimens.spaceXl,
      right: AppDimens.spaceXl,
      child: Material(
        color: Colors.transparent,
        child: SlideTransition(
          position: _slideAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: GestureDetector(
                onTap: widget.onDismiss, // Dismiss on tap
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceXl,
                    vertical: AppDimens.spaceMdPlus,
                  ),
                  decoration: BoxDecoration(
                    color: widget.color,
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
                      Icon(widget.icon, color: Colors.white, size: 22),
                      const SizedBox(width: AppDimens.spaceMd),
                      Flexible(
                        child: Text(
                          widget.message,
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
        ),
      ),
    );
  }
}
