import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/data/trusted_device_repository.dart'; // NEW IMPORT
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
      TrustedDeviceRepository(); // ADDED

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
    _loadBiometricAvailability();
    _ensureSessionClock();
    _resetTimer();
  }

  @override
  void didUpdateWidget(covariant InactivityLockGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timeout != widget.timeout ||
        oldWidget.absoluteTimeout != widget.absoluteTimeout) {
      _resetTimer();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
      _inactivityTimer?.cancel();
      return;
    }

    if (state == AppLifecycleState.resumed) {
      // Re-check security status on resume to catch settings changes
      _loadBiometricAvailability().then((_) {
        if (_isAbsoluteTimeoutExceeded()) {
          unawaited(_signOutFromLockScreen());
          return;
        }

        final pausedAt = _pausedAt;
        _pausedAt = null;

        // Only enforce inactivity lock if biometrics are active/configured
        if (pausedAt != null && _biometricAvailable) {
          final elapsed = DateTime.now().difference(pausedAt);
          if (elapsed >= widget.timeout) {
            _lockAndScheduleUnlock();
            return;
          }
        }

        if (!_isLocked) {
          _resetTimer();
        }
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
      // Feature only functions if hardware exists AND user enabled it
      _biometricAvailable = hasHardware && isConfigured;
    });
  }

  void _resetTimer() {
    _ensureSessionClock();

    if (_isAbsoluteTimeoutExceeded()) {
      unawaited(_signOutFromLockScreen());
      return;
    }

    // NEW Logic: If security is not configured, do not start the inactivity timer
    if (!_biometricAvailable || _isLocked) {
      _inactivityTimer?.cancel();
      return;
    }

    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(widget.timeout, _handleSessionTimeout);
  }

  void _handleSessionTimeout() {
    if (!mounted) {
      return;
    }

    // Ignore when there is no active authenticated user.
    if (_authRepository.currentUser == null) {
      _sessionStartedAt = null;
      _resetTimer();
      return;
    }

    _lockAndScheduleUnlock();
  }

  void _lockAndScheduleUnlock() {
    if (!mounted || !_biometricAvailable) {
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
    try {
      await _authRepository.signOut();
    } catch (_) {
      // force route transition even when sign-out API fails.
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isLocked = false;
      _isUnlocking = false;
      _sessionStartedAt = null;
    });
    context.go(AppRoutes.login);
    _inactivityTimer?.cancel();
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

  Widget _buildLockOverlay() {
    return Material(
      color: const Color(0xFF0F151E),
      child: SafeArea(
        child: Center(
          child: Container(
            width: 340,
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'App Locked',
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'For your privacy, re-authenticate to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textLight, fontSize: 14),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isUnlocking ? null : _unlock,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _isUnlocking
                          ? 'Unlocking...'
                          : _biometricAvailable
                          ? 'Unlock'
                          : 'Retry Unlock',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _signOutFromLockScreen,
                  child: const Text(
                    'Sign out instead',
                    style: TextStyle(color: AppColors.textLight),
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
