import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_repository.dart';
import '../constants/app_routes.dart';
import '../theme/app_colors.dart';
import 'biometric_auth_service.dart';

/// Session timeout guard: locks the app after inactivity and requires re-auth.
class InactivityLockGuard extends StatefulWidget {
  final Widget child;
  final Duration timeout;

  const InactivityLockGuard({
    super.key,
    required this.child,
    this.timeout = const Duration(minutes: 5),
  });

  @override
  State<InactivityLockGuard> createState() => _InactivityLockGuardState();
}

class _InactivityLockGuardState extends State<InactivityLockGuard>
    with WidgetsBindingObserver {
  final AuthRepository _authRepository = AuthRepository();
  final BiometricAuthService _biometricAuthService = BiometricAuthService();
  Timer? _inactivityTimer;
  bool _isLocked = false;
  bool _isUnlocking = false;
  bool _biometricAvailable = false;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadBiometricAvailability();
    _resetTimer();
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
      final pausedAt = _pausedAt;
      _pausedAt = null;

      if (pausedAt != null) {
        final elapsed = DateTime.now().difference(pausedAt);
        if (elapsed >= widget.timeout) {
          _lockAndScheduleUnlock(delayBeforePrompt: true);
          return;
        }
      }

      if (_isLocked) {
        _unlock(delayBeforePrompt: true);
      } else {
        _resetTimer();
      }
    }
  }

  Future<void> _loadBiometricAvailability() async {
    final available = await _biometricAuthService.canUseBiometricUnlock();
    if (!mounted) {
      return;
    }
    setState(() => _biometricAvailable = available);
  }

  void _resetTimer() {
    if (_isLocked) {
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
      _resetTimer();
      return;
    }

    _lockAndScheduleUnlock();
  }

  void _lockAndScheduleUnlock({bool delayBeforePrompt = false}) {
    if (!mounted) {
      return;
    }
    _inactivityTimer?.cancel();
    if (!_isLocked) {
      setState(() => _isLocked = true);
    }
    unawaited(_unlock(delayBeforePrompt: delayBeforePrompt));
  }

  Future<void> _unlock({bool delayBeforePrompt = false}) async {
    if (_isUnlocking || !_isLocked) {
      return;
    }

    setState(() => _isUnlocking = true);
    bool isAuthenticated = false;
    try {
      if (delayBeforePrompt) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
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
          setState(() => _isUnlocking = false);
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
    });
    context.go(AppRoutes.login);
    _resetTimer();
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
                  duration: const Duration(milliseconds: 180),
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
