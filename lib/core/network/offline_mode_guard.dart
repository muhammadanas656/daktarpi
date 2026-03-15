import 'package:flutter/material.dart';
import 'network_notifier.dart';
import '../theme/app_colors.dart'; // PRO FIX: Imported theme tokens

class OfflineModeGuard extends StatefulWidget {
  final Widget child;
  const OfflineModeGuard({super.key, required this.child});

  @override
  State<OfflineModeGuard> createState() => _OfflineModeGuardState();
}

class _OfflineModeGuardState extends State<OfflineModeGuard> {
  @override
  void initState() {
    super.initState();
    NetworkNotifier.instance.addListener(_onNetworkChange);
  }

  @override
  void dispose() {
    NetworkNotifier.instance.removeListener(_onNetworkChange);
    super.dispose();
  }

  void _onNetworkChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = NetworkNotifier.instance.isOffline;
    final safeAreaTop = MediaQuery.paddingOf(context).top;

    // PRO FIX: Listen to the current theme brightness
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(child: widget.child),

        Positioned(
          top: safeAreaTop + 10,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: RepaintBoundary(
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  offset: isOffline ? Offset.zero : const Offset(0, -1.6),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    opacity: isOffline ? 1 : 0,
                    // Avoid BackdropFilter here; it causes visible route-transition artifacts
                    // when modal barriers animate under the offline pill.
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surface.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color:
                              isDark ? AppColors.darkBorder : Colors.grey[300]!,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.3 : 0.08,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(
                                alpha: isDark ? 0.2 : 0.1,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.wifi_off_rounded,
                              color: isDark ? Colors.red[300] : Colors.redAccent,
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Operating Offline",
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                              decoration: TextDecoration.none,
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
        ),
      ],
    );
  }
}
