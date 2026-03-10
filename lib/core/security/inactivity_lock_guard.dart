import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/data/trusted_device_repository.dart';
import '../../features/settings/presentation/settings_notifier.dart';
import '../constants/app_routes.dart';
import '../theme/app_motion.dart';
import '../theme/app_colors.dart';
import 'biometric_auth_service.dart';

/// Session timeout guard: locks the app after inactivity and requires re-auth.
class InactivityLockGuard extends StatefulWidget {
  final Widget child;
  final Duration timeout;
  final Duration absoluteTimeout;

  const InactivityLockGuard({
    super.key,
    required this.child,
    this.timeout = const Duration(minutes: 5),
    this.absoluteTimeout = const Duration(hours: 12),
  });

  @override
  State<InactivityLockGuard> createState() => _InactivityLockGuardState();
}

class _InactivityLockGuardState extends State<InactivityLockGuard>
    with WidgetsBindingObserver {
  final AuthRepository _authRepository = AuthRepository();
  final BiometricAuthService _biometricAuthService = BiometricAuthService();
  final TrustedDeviceRepository _trustedDeviceRepository =
      TrustedDeviceRepository();

  Timer? _inactivityTimer;
  bool _isLocked = false;
  bool _isUnlocking = false;
  bool _biometricAvailable = false;
  DateTime? _pausedAt;
  DateTime? _sessionStartedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // NEW: Listen to settings changes for real-time timer updates
    SettingsNotifier.instance.addListener(_handleSettingsUpdate);
    _loadBiometricAvailability();
    _ensureSessionClock();
    _resetTimer();
  }

  @override
  void didUpdateWidget(covariant InactivityLockGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _resetTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // NEW: Clean up listener
    SettingsNotifier.instance.removeListener(_handleSettingsUpdate);
    _inactivityTimer?.cancel();
    super.dispose();
  }

  // Listener wrapper to ensure status and timer refresh together
  void _handleSettingsUpdate() {
    if (!mounted) {
      return;
    }
    _loadBiometricAvailability().then((_) {
      _resetTimer();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
      _inactivityTimer?.cancel();
      return;
    }

    if (state == AppLifecycleState.resumed) {
      // --- FIX: Wait for Flutter to finish waking up the UI before evaluating locks ---
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadBiometricAvailability().then((_) {
          if (!mounted) return;

          if (_isAbsoluteTimeoutExceeded()) {
            unawaited(_signOutFromLockScreen());
            return;
          }

          final pausedAt = _pausedAt;
          _pausedAt = null;

          final savedTimeoutMs = SettingsNotifier.instance.inactivityTimeoutMs;
          if (pausedAt != null && _biometricAvailable && savedTimeoutMs > 0) {
            final elapsed = DateTime.now().difference(pausedAt);
            if (elapsed >= Duration(milliseconds: savedTimeoutMs)) {
              _lockAndScheduleUnlock();
              return;
            }
          }

          if (!_isLocked) {
            _resetTimer();
          }
        });
      });
    }
  }

  Future<void> _loadBiometricAvailability() async {
    final hasHardware = await _biometricAuthService.canUseBiometricUnlock();
    final userId = _authRepository.currentUserId;

    bool isConfigured = false;
    if (userId != null) {
      isConfigured = await _trustedDeviceRepository.isBiometricEnabledForDevice(
        userId: userId,
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _biometricAvailable = hasHardware && isConfigured;
    });
  }

  void _resetTimer() {
    if (_isLocked) {
      _inactivityTimer?.cancel();
      return;
    }

    _ensureSessionClock();

    if (_isAbsoluteTimeoutExceeded()) {
      unawaited(_signOutFromLockScreen());
      return;
    }

    final savedTimeoutMs = SettingsNotifier.instance.inactivityTimeoutMs;

    if (!_biometricAvailable || savedTimeoutMs <= 0) {
      _inactivityTimer?.cancel();
      return;
    }

    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(
      Duration(milliseconds: savedTimeoutMs),
      _handleSessionTimeout,
    );
  }

  void _handleSessionTimeout() {
    if (!mounted) {
      return;
    }

    if (_authRepository.currentUser == null) {
      _sessionStartedAt = null;
      _resetTimer();
      return;
    }

    _lockAndScheduleUnlock();
  }

  void _lockAndScheduleUnlock() {
    if (!mounted ||
        !_biometricAvailable ||
        SettingsNotifier.instance.inactivityTimeoutMs <= 0) {
      return;
    }

    _inactivityTimer?.cancel();
    if (!_isLocked) {
      setState(() {
        _isLocked = true;
      });

      SettingsNotifier.instance.updateMedicalRecordsLock(true);
    }
  }

  Future<void> _unlock() async {
    if (_isUnlocking || !_isLocked) {
      return;
    }

    if (_isAbsoluteTimeoutExceeded()) {
      await _signOutFromLockScreen();
      return;
    }

    setState(() {
      _isUnlocking = true;
    });
    bool isAuthenticated = false;
    try {
      if (_biometricAvailable) {
        isAuthenticated = await _biometricAuthService.authenticate();
      }
    } catch (_) {
      isAuthenticated = false;
    } finally {
      if (mounted) {
        if (isAuthenticated) {
          setState(() {
            _isLocked = false;
            _isUnlocking = false;
          });
          _resetTimer();
        } else {
          setState(() {
            _isUnlocking = false;
          });
        }
      }
    }
  }

  Future<void> _signOutFromLockScreen() async {
    _inactivityTimer?.cancel(); // Cancel timer first to stop memory leaks

    try {
      await _authRepository.signOut();
    } catch (_) {}

    if (!mounted) {
      return;
    }

    setState(() {
      _isLocked = false;
      _isUnlocking = false;
      _sessionStartedAt = null;
    });

    // --- FIX: Defer navigation until after the layout phase is completely finished ---
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.go(AppRoutes.login);
      }
    });
  }

  void _ensureSessionClock() {
    if (_authRepository.currentUser == null) {
      _sessionStartedAt = null;
      return;
    }
    _sessionStartedAt ??= DateTime.now().toUtc();
  }

  bool _isAbsoluteTimeoutExceeded() {
    _ensureSessionClock();
    final startedAt = _sessionStartedAt;
    if (startedAt == null) {
      return false;
    }
    return DateTime.now().toUtc().difference(startedAt) >=
        widget.absoluteTimeout;
  }

  // --- PRO FIX: Premium Adaptive Glass Lock Overlay ---
  Widget _buildLockOverlay() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.black.withValues(alpha: 0.7), // Richer, modern dimming
      child: SafeArea(
        child: Center(
          child: Container(
            width: 340,
            margin: EdgeInsets.all(24),
            padding: EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(28), // Smoother corners
              border: Border.all(
                color:
                    isDark
                        ? AppColors.darkBorder
                        : Colors.grey.withValues(alpha: 0.2),
                width: 1.5,
              ),
              boxShadow: [
                // Premium Glowing "Halo" Shadow
                BoxShadow(
                  color: AppColors.primaryGreen.withValues(alpha: 0.15),
                  blurRadius: 50,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Floating Halo Icon
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.primaryGreen,
                    size: 32,
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'App Locked',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'For your privacy, please re-authenticate to continue your session.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isUnlocking ? null : _unlock,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      _isUnlocking
                          ? 'Unlocking...'
                          : _biometricAvailable
                          ? 'Unlock'
                          : 'Retry Unlock',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12),
                TextButton(
                  onPressed: _signOutFromLockScreen,
                  child: Text(
                    'Sign out instead',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (_) {
        if (!_isLocked) {
          _resetTimer();
        }
        return false;
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) {
          if (!_isLocked) {
            _resetTimer();
          }
        },
        onPointerMove: (_) {
          if (!_isLocked) {
            _resetTimer();
          }
        },
        onPointerSignal: (_) {
          if (!_isLocked) {
            _resetTimer();
          }
        },
        child: Stack(
          children: [
            AbsorbPointer(absorbing: _isLocked, child: widget.child),
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_isLocked,
                child: AnimatedOpacity(
                  opacity: _isLocked ? 1 : 0,
                  duration: AppMotion.defaultDuration,
                  curve: Curves.easeOut,
                  child: _buildLockOverlay(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
