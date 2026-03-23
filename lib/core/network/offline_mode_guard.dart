import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'network_notifier.dart';
import '../theme/app_colors.dart';

class OfflineModeGuard extends StatefulWidget {
  final Widget child;
  const OfflineModeGuard({super.key, required this.child});

  @override
  State<OfflineModeGuard> createState() => _OfflineModeGuardState();
}

class _OfflineModeGuardState extends State<OfflineModeGuard> {
  bool _isVisible = false;
  bool _isSuccessMode = false;
  bool _wasOffline = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _wasOffline = NetworkNotifier.instance.isOffline;
    
    // If the app boots up offline, show the pill briefly
    if (_wasOffline) {
      _triggerPill(success: false);
    }
    
    NetworkNotifier.instance.addListener(_onNetworkChange);
  }

  @override
  void dispose() {
    NetworkNotifier.instance.removeListener(_onNetworkChange);
    _hideTimer?.cancel();
    super.dispose();
  }

  void _onNetworkChange() {
    final currentlyOffline = NetworkNotifier.instance.isOffline;
    
    if (currentlyOffline != _wasOffline) {
      _wasOffline = currentlyOffline;
      
      if (currentlyOffline) {
        // Just lost connection
        HapticFeedback.lightImpact();
        _triggerPill(success: false);
      } else {
        // Just regained connection!
        HapticFeedback.mediumImpact();
        _triggerPill(success: true);
      }
    }
  }

  void _triggerPill({required bool success}) {
    _hideTimer?.cancel();
    
    if (mounted) {
      setState(() {
        _isSuccessMode = success;
        _isVisible = true;
      });
    }

    // Auto-hide the pill so it doesn't frustrate the user
    // Lingers for 4 seconds if offline, 2.5 seconds for the success message
    _hideTimer = Timer(Duration(milliseconds: success ? 2500 : 4000), () {
      if (mounted) {
        setState(() => _isVisible = false);
      }
    });
  }

  void _dismissManually() {
    _hideTimer?.cancel();
    if (mounted) {
      setState(() => _isVisible = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeAreaTop = MediaQuery.paddingOf(context).top;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(child: widget.child),

        Positioned(
          top: safeAreaTop + 10,
          left: 0,
          right: 0,
          child: Center(
            child: RepaintBoundary(
              // 📌 The Slide Engine
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutBack, // Gives it a premium native "pop"
                offset: _isVisible ? Offset.zero : const Offset(0, -1.6),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  opacity: _isVisible ? 1 : 0,
                  
                  // 📌 The Removal Mechanism (Swipe up or Tap to dismiss)
                  child: GestureDetector(
                    onTap: _dismissManually,
                    onVerticalDragEnd: (details) {
                      if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
                        _dismissManually(); // Swiped up
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        // Morphs color dynamically based on state
                        color: _isSuccessMode 
                            ? AppColors.primaryGreen.withValues(alpha: 0.94)
                            : Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: _isSuccessMode
                              ? Colors.transparent
                              : (isDark ? AppColors.darkBorder : Colors.grey[300]!),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      // 📌 AnimatedSwitcher morphs the content seamlessly
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                        child: _isSuccessMode 
                            ? _buildSuccessContent() 
                            : _buildOfflineContent(isDark),
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

  Widget _buildOfflineContent(bool isDark) {
    return Row(
      key: const ValueKey('offline'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.redAccent.withValues(alpha: isDark ? 0.2 : 0.1),
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
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessContent() {
    return Row(
      key: const ValueKey('online'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.wifi_rounded,
            color: Colors.white,
            size: 14,
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          "Back Online",
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}