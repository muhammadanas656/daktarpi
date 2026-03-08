import 'dart:ui';
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
      children: [
        widget.child,

        AnimatedPositioned(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutBack,
          top: isOffline ? safeAreaTop + 10 : -100,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      // PRO FIX: Dynamic Surface Color instead of hardcoded hex
                      color: Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        // PRO FIX: Uses your AppColors for precise dark mode borders
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
                            // Dynamic Red that softens in Dark Mode
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
                            // PRO FIX: Text strictly follows the current theme
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
      ],
    );
  }
}
