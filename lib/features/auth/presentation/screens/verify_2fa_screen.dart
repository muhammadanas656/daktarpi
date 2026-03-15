import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pinput/pinput.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../presentation/widgets/primary_button.dart';
import '../../../../presentation/widgets/app_text_field.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/utils/security_formatters.dart';
import '../models/verify_2fa_route_args.dart';
import '../../data/auth_entry_route_service.dart';
import '../../data/auth_repository.dart';
import '../../data/security_gate_service.dart';
import '../../data/trusted_device_repository.dart';
import '../../../../presentation/widgets/app_floating_dialog.dart';

class Verify2FAScreen extends StatefulWidget {
  final Verify2FARouteArgs routeArgs;

  const Verify2FAScreen({
    super.key,
    this.routeArgs = const Verify2FARouteArgs(),
  });

  @override
  State<Verify2FAScreen> createState() => _Verify2FAScreenState();
}

class _Verify2FAScreenState extends State<Verify2FAScreen>
    with WidgetsBindingObserver {
  final _codeController = TextEditingController();
  final _recoveryController = TextEditingController();

  bool _isLoading = false;
  bool _isRecoveryMode = false;
  bool _rememberThisDevice = false;
  bool _showRecoveryAssist = false;
  Timer? _recoveryAssistTimer;
  final SecurityGateService _securityGateService = SecurityGateService(
    authProvider: AuthRepositorySecurityProvider(AuthRepository()),
  );
  final TrustedDeviceRepository _trustedDeviceRepository =
      TrustedDeviceRepository();
  final AuthEntryRouteService _authEntryRouteService = AuthEntryRouteService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startRecoveryAssistTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recoveryAssistTimer?.cancel();
    _codeController.dispose();
    _recoveryController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Background clipboard checks removed to prevent false verification attempts
    }
  }

  void _startRecoveryAssistTimer() {
    _recoveryAssistTimer?.cancel();
    if (_isRecoveryMode) {
      return;
    }

    if (mounted && _showRecoveryAssist) {
      setState(() {
        _showRecoveryAssist = false;
      });
    } else {
      _showRecoveryAssist = false;
    }

    _recoveryAssistTimer = Timer(Duration(seconds: 5), () {
      if (!mounted || _isRecoveryMode) {
        return;
      }
      setState(() {
        _showRecoveryAssist = true;
      });
    });
  }

  void _setRecoveryMode(bool enabled) {
    setState(() {
      _isRecoveryMode = enabled;
      _codeController.clear();
      _recoveryController.clear();
      _showRecoveryAssist = false;
    });

    if (enabled) {
      _recoveryAssistTimer?.cancel();
    } else {
      _startRecoveryAssistTimer();
    }
  }

  Future<void> _verify() async {
    final code =
        _isRecoveryMode
            ? _recoveryController.text.replaceAll('-', '').trim()
            : _codeController.text.trim();

    if (code.isEmpty) {
      return;
    }
    if (!_isRecoveryMode && code.length != 6) {
      CustomSnackbar.showError(context, "Please enter all 6 digits.");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isRecoveryMode) {
        final success = await _securityGateService.verifyWithRecoveryCode(code);

        if (success) {
          final trustSaved = await _markTrustedDeviceIfSelected();
          if (mounted) {
            if (!trustSaved && _rememberThisDevice) {
              CustomSnackbar.showInfo(
                context,
                "Verified successfully, but this device could not be remembered.",
              );
            }
            // --- PRO FIX: Adaptive Glass Success Dialog ---
            // --- PRO FIX: Adaptive Glass Success Dialog ---
            await showDialog(
              context: context,
              barrierColor: Colors.black.withValues(alpha: 0.6),
              barrierDismissible: false,
              builder: (ctx) {
                return AppFloatingDialog(
                  headerIcon: Icons.check_circle_outline_rounded,
                  iconColor: AppColors.primaryGreen,
                  title: "Access Recovered",
                  description:
                      "Your backup code was accepted.\n\nFor your security, your account is currently unprotected. We highly recommend re-enabling 2FA in your settings soon.",
                  content: const SizedBox.shrink(),
                  isUpdating: false,
                  actions: SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      label: "Continue",
                      onTap: () async {
                        Navigator.pop(ctx);
                        await _handleVerificationSuccess();
                      },
                    ),
                  ),
                );
              },
            );
          }
        } else {
          throw "That backup code didn't match. Please try another one.";
        }
      } else {
        await _securityGateService.verifyWithTotp(code);
        final trustSaved = await _markTrustedDeviceIfSelected();
        if (mounted && !trustSaved && _rememberThisDevice) {
          CustomSnackbar.showInfo(
            context,
            "Verified successfully, but this device could not be remembered.",
          );
        }
        await _handleVerificationSuccess();
      }
    } on AuthException catch (_) {
      if (mounted) {
        CustomSnackbar.showError(
          context,
          "That code didn't match. Please try again.",
        );
        _codeController.clear();
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(
          context,
          e.toString().replaceAll("Exception: ", ""),
        );
        if (!_isRecoveryMode) {
          _codeController.clear();
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _markTrustedDeviceIfSelected() async {
    if (!_rememberThisDevice) {
      return true;
    }
    try {
      await _trustedDeviceRepository.trustCurrentDevice();
      return true;
    } catch (e) {
      debugPrint('Mark trusted failed: $e');
      // Trust persistence should never block authentication success.
      return false;
    }
  }

  Future<void> _handleVerificationSuccess() async {
    if (!mounted) {
      return;
    }
    if (widget.routeArgs.popOnSuccess) {
      context.pop(true);
      return;
    }
    String targetRoute = AppRoutes.home;
    try {
      targetRoute = await _authEntryRouteService.resolvePostAuthRoute();
    } catch (_) {
      targetRoute = AppRoutes.home;
    }

    if (!mounted) {
      return;
    }
    if (targetRoute == AppRoutes.verify2fa) {
      targetRoute = AppRoutes.home;
    }
    context.go(targetRoute);
  }

  Future<void> _handleCancel() async {
    if (widget.routeArgs.popOnSuccess) {
      if (mounted) {
        context.pop(false);
      }
      return;
    }

    await AuthRepository().signOut();
    if (mounted) {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 64,
      textStyle: TextStyle(
        fontSize: 24,
        color: context.colorTextDark,
        fontWeight: FontWeight.bold,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colorBorder),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(color: AppColors.primaryGreen, width: 2),
      ),
    );

    final errorPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(color: Colors.redAccent, width: 2),
      ),
    );

    return Scaffold(
      backgroundColor: context.colorScaffoldBackground,
      body: Container(
        decoration: BoxDecoration(gradient: AppStyles.pageGradient(context)),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                padding: EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: AppStyles.elevatedShadow(context),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color:
                            _isRecoveryMode
                                ? Colors.orange.withValues(alpha: 0.1)
                                : AppColors.primaryGreen.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isRecoveryMode
                            ? Icons.healing_outlined
                            : Icons.lock_outline,
                        size: 40,
                        color:
                            _isRecoveryMode
                                ? Colors.orange
                                : AppColors.primaryGreen,
                      ),
                    ),
                    SizedBox(height: 24),
                    AnimatedSwitcher(
                      duration: AppMotion.defaultDuration,
                      child: Text(
                        _isRecoveryMode ? "Account Recovery" : "Security Check",
                        key: ValueKey(_isRecoveryMode),
                        style: AppTextStyles.h2(context),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(height: 12),
                    AnimatedSwitcher(
                      duration: AppMotion.defaultDuration,
                      child: Text(
                        _isRecoveryMode
                            ? "Enter one of your 8-character backup codes to securely regain access to your account."
                            : "We sent a challenge to your authenticator app. Please enter the 6-digit code below.",
                        key: ValueKey(_isRecoveryMode),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.colorTextLight,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ),
                    if (!_isRecoveryMode) ...[
                      SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: CheckboxListTile(
                          dense: true,
                          value: _rememberThisDevice,
                          activeColor: AppColors.primaryGreen,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8),
                          title: Text(
                            "Remember this device for 30 days",
                            style: TextStyle(
                              fontSize: 13,
                              color: context.colorTextDark,
                            ),
                          ),
                          onChanged:
                              _isLoading
                                  ? null
                                  : (value) {
                                    setState(() {
                                      _rememberThisDevice = value ?? false;
                                    });
                                  },
                        ),
                      ),
                    ],
                    SizedBox(height: 32),

                    AnimatedCrossFade(
                      firstChild: LayoutBuilder(
                        builder: (context, constraints) {
                          double boxWidth = (constraints.maxWidth - 40) / 6;
                          boxWidth = boxWidth.clamp(30.0, 56.0);

                          return Pinput(
                            length: 6,
                            controller: _codeController,
                            defaultPinTheme: defaultPinTheme.copyWith(
                              width: boxWidth,
                              height: boxWidth + 10,
                            ),
                            focusedPinTheme: focusedPinTheme.copyWith(
                              width: boxWidth,
                              height: boxWidth + 10,
                            ),
                            errorPinTheme: errorPinTheme.copyWith(
                              width: boxWidth,
                              height: boxWidth + 10,
                            ),
                            autofocus: true,
                            keyboardType: TextInputType.number,

                            // PRO FIX: Empty array forcefully disables the OS OTP autofill banner
                            autofillHints: const [],

                            showCursor: true,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],

                            // PRO FIX: Automatically triggers verification when full
                            onCompleted: (pin) => _verify(),
                          );
                        },
                      ),
                      secondChild: AppTextField(
                        controller: _recoveryController,
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.characters,
                        textAlign: TextAlign.center,
                        inputFormatters: [
                          BackupCodeFormatter(),
                        ], // AUTO-FORMATTER
                        hintText: "XXXX-XXXX",
                        onChanged: (val) {
                          final extracted = extractFirstBackupCode(val);
                          if (extracted != null &&
                              extracted != _recoveryController.text) {
                            setState(() {
                              _recoveryController.text = extracted;
                            });
                          }
                          if (_recoveryController.text.length == 9) {
                            _verify();
                          }
                        },
                        onSubmitted: (val) => _verify(),
                      ),
                      crossFadeState:
                          _isRecoveryMode
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                      duration: AppMotion.defaultDuration,
                    ),

                    SizedBox(height: 32),
                    PrimaryButton(
                      label: _isRecoveryMode ? "Unlock Account" : "Verify",
                      onTap: _verify,
                      isLoading: _isLoading,
                      backgroundColor:
                          _isRecoveryMode
                              ? Colors.orange
                              : AppColors.primaryGreen,
                    ),
                    SizedBox(height: 24),
                    AnimatedSwitcher(
                      duration: AppMotion.defaultDuration,
                      child:
                          _isRecoveryMode
                              ? TextButton(
                                key: ValueKey('back_to_totp_button'),
                                onPressed:
                                    _isLoading
                                        ? null
                                        : () => _setRecoveryMode(false),
                                child: Text(
                                  "I found my authenticator app",
                                  style: TextStyle(
                                    color: AppColors.primaryGreen,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              )
                              : AnimatedOpacity(
                                key: ValueKey('recovery_assist_button'),
                                opacity: _showRecoveryAssist ? 1 : 0,
                                duration: AppMotion.defaultDuration,
                                curve: Curves.easeOut,
                                child: IgnorePointer(
                                  ignoring: !_showRecoveryAssist || _isLoading,
                                  child: TextButton(
                                    onPressed: () => _setRecoveryMode(true),
                                    child: Text(
                                      "Lost your authenticator? Use a backup code",
                                      style: TextStyle(
                                        color: AppColors.primaryGreen,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                    ),
                    SizedBox(height: 16),
                    TextButton(
                      onPressed: _handleCancel,
                      child: Text(
                        "Cancel",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
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
