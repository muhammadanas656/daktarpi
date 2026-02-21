import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pinput/pinput.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../presentation/widgets/primary_button.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/utils/security_formatters.dart';
import '../models/verify_2fa_route_args.dart';
import '../../data/auth_repository.dart';
import '../../data/security_gate_service.dart';

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
  final SecurityGateService _securityGateService = SecurityGateService(
    authProvider: AuthRepositorySecurityProvider(AuthRepository()),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkClipboardAndPaste();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _codeController.dispose();
    _recoveryController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboardAndPaste();
    }
  }

  Future<void> _checkClipboardAndPaste() async {
    if (_isLoading) {
      return;
    }
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isEmpty) {
        return;
      }

      final cleanText = text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

      if (!_isRecoveryMode &&
          cleanText.length == 6 &&
          RegExp(r'^[0-9]+$').hasMatch(cleanText)) {
        if (_codeController.text != cleanText) {
          setState(() {
            _codeController.text = cleanText;
          });
          _verify();
        }
      } else if (_isRecoveryMode && cleanText.length == 8) {
        final formattedCode =
            '${cleanText.substring(0, 4)}-${cleanText.substring(4)}';
        if (_recoveryController.text != formattedCode) {
          setState(() {
            _recoveryController.text = formattedCode;
          });
          _verify();
        }
      }
    } catch (_) {}
  }

  Future<void> _verify() async {
    final code =
        _isRecoveryMode
            ? _recoveryController.text.trim()
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
          if (mounted) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder:
                  (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: const Row(
                      children: [
                        Icon(Icons.check_circle, color: AppColors.primaryGreen),
                        SizedBox(width: 10),
                        Text("Access Recovered"),
                      ],
                    ),
                    content: const Text(
                      "Your backup code was accepted.\n\nFor your security, your account is currently unprotected. We highly recommend re-enabling 2FA in your settings soon.",
                      style: TextStyle(height: 1.5, color: AppColors.textDark),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _handleVerificationSuccess();
                        },
                        child: const Text(
                          "Continue",
                          style: TextStyle(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
            );
          }
        } else {
          throw "That backup code didn't match. Please try another one.";
        }
      } else {
        await _securityGateService.verifyWithTotp(code);
        _handleVerificationSuccess();
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

  void _handleVerificationSuccess() {
    if (!mounted) {
      return;
    }
    if (widget.routeArgs.popOnSuccess) {
      context.pop(true);
      return;
    }
    context.go(AppRoutes.home);
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
      textStyle: const TextStyle(
        fontSize: 24,
        color: AppColors.textDark,
        fontWeight: FontWeight.bold,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
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
      backgroundColor: AppColors.scaffoldBackground,
      body: Container(
        decoration: const BoxDecoration(gradient: AppStyles.pageGradient),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
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
                    const SizedBox(height: 24),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _isRecoveryMode ? "Account Recovery" : "Security Check",
                        key: ValueKey(_isRecoveryMode),
                        style: AppTextStyles.h2,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _isRecoveryMode
                            ? "Enter one of your 8-character backup codes to securely regain access to your account."
                            : "We sent a challenge to your authenticator app. Please enter the 6-digit code below.",
                        key: ValueKey(_isRecoveryMode),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

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
                            showCursor: true,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ], // Only numbers allowed
                            onCompleted: (pin) => _verify(),
                          );
                        },
                      ),
                      secondChild: TextField(
                        controller: _recoveryController,
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          BackupCodeFormatter(),
                        ], // AUTO-FORMATTER
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          fontFamily: 'monospace',
                        ),
                        decoration: InputDecoration(
                          hintText: "XXXX-XXXX",
                          hintStyle: TextStyle(color: Colors.grey[300]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.borderColor,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.borderColor,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.orange,
                              width: 2,
                            ),
                          ),
                        ),
                        onChanged: (val) {
                          if (val.length == 9) {
                            _verify();
                          }
                        },
                        onSubmitted: (val) => _verify(),
                      ),
                      crossFadeState:
                          _isRecoveryMode
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 300),
                    ),

                    const SizedBox(height: 32),
                    PrimaryButton(
                      label: _isRecoveryMode ? "Unlock Account" : "Verify",
                      onTap: _verify,
                      isLoading: _isLoading,
                      backgroundColor:
                          _isRecoveryMode
                              ? Colors.orange
                              : AppColors.primaryGreen,
                    ),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isRecoveryMode = !_isRecoveryMode;
                          _codeController.clear();
                          _recoveryController.clear();
                        });
                      },
                      child: Text(
                        _isRecoveryMode
                            ? "I found my authenticator app"
                            : "Can't access your authenticator?",
                        style: const TextStyle(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _handleCancel,
                      child: const Text(
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
