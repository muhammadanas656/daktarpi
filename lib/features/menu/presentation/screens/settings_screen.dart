import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/security/biometric_auth_service.dart';
import '../../../../core/security/sensitive_action_step_up_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/security_formatters.dart';
import '../../../../presentation/widgets/app_text_field.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../presentation/widgets/primary_button.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/data/security_gate_service.dart';
import '../../../auth/data/trusted_device_repository.dart';
import '../../../settings/presentation/settings_notifier.dart';
import '../../data/settings_repository.dart';
import '../widgets/settings_account_security_section.dart';
import '../widgets/settings_preferences_section.dart';
import '../widgets/settings_support_legal_section.dart';
import '../../../../presentation/widgets/app_floating_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  bool _isLoading = false;

  late bool _is2FAEnabled;
  late bool _isBiometricEnabled;

  bool _is2FAToggleBusy = false;
  String? _verifiedFactorId;
  bool _hasPromptedSecurity = false;

  // NEW: State to track if the user has an email password provider
  bool _hasEmailProvider = false;

  late final AuthRepository _authRepository = AuthRepository();
  late final SecurityGateService _securityGateService = SecurityGateService(
    authProvider: AuthRepositorySecurityProvider(_authRepository),
  );

  final SettingsRepository _settingsRepository = SettingsRepository();
  final SensitiveActionStepUpService _stepUpService =
      SensitiveActionStepUpService();

  bool _hasBiometricHardware = false;
  bool _isBiometricToggleBusy = false;

  final BiometricAuthService _biometricAuthService = BiometricAuthService();
  final TrustedDeviceRepository _trustedDeviceRepository =
      TrustedDeviceRepository();

  VoidCallback? _activePinSubmit;

  @override
  void initState() {
    super.initState();
    // Preload state from SettingsNotifier's cache for instant UI rendering without layout shifts
    _is2FAEnabled = SettingsNotifier.instance.is2FAEnabled;

    // Preload biometric capabilities from SettingsNotifier's cache to prevent layout shift
    _hasBiometricHardware = SettingsNotifier.instance.hasBiometricHardware;
    _isBiometricEnabled = SettingsNotifier.instance.isBiometricEnabled;

    SettingsNotifier.instance.loadSettings();

    // NEW: Check if the user signed in with an email/password or just OAuth (Google)
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final providers = List<String>.from(user.appMetadata['providers'] ?? []);
      final hasEmailMetadata = user.userMetadata?['has_email_password'] == true;
      // It has an email if it's in the providers list OR if we set the hidden metadata flag
      _hasEmailProvider = providers.contains('email') || hasEmailMetadata;
    }

    // Run these in background to refresh the UI without blocking initial build
    _checkBiometricStatus();
    _check2FAStatus();
  }

  Future<void> _checkBiometricStatus() async {
    final hasHardware = await _biometricAuthService.canUseBiometricUnlock();
    final user = _settingsRepository.currentUser;

    if (user == null || !hasHardware) {
      if (mounted) {
        setState(() {
          _hasBiometricHardware = false;
          _isBiometricEnabled = false;
        });
        SettingsNotifier.instance.updateBiometricState(false, false);
      }
      return;
    }

    final isEnabled = await _trustedDeviceRepository
        .isBiometricEnabledForDevice(userId: user.id);

    if (mounted) {
      setState(() {
        _hasBiometricHardware = true;
        _isBiometricEnabled = isEnabled;
      });
      SettingsNotifier.instance.updateBiometricState(true, isEnabled);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _check2FAStatus() async {
    try {
      final user = _settingsRepository.currentUser;
      final factors = await _settingsRepository.listMfaFactors();

      if (mounted) {
        setState(() {
          final totpFactors = factors.totp;
          final hasFactor = totpFactors.isNotEmpty;
          final isEnabledInMetadata =
              user?.appMetadata['is_2fa_enabled'] == true;

          _is2FAEnabled = hasFactor && isEnabledInMetadata;
          SettingsNotifier.instance.update2FAEnabled(_is2FAEnabled);

          if (hasFactor) {
            final verifiedFactor = totpFactors.firstWhere(
              (f) => f.status == FactorStatus.verified,
              orElse: () => totpFactors.first,
            );
            _verifiedFactorId = verifiedFactor.id;
          } else {
            _verifiedFactorId = null;
          }
        });

        if (!_is2FAEnabled && !_isBiometricEnabled && !_hasPromptedSecurity) {
          _hasPromptedSecurity = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (mounted) {
              _showSecurityOnboardingPrompt();
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error checking 2FA status: $e");
    }
  }

  void _showSecurityOnboardingPrompt() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) {
        return AppFloatingDialog(
          headerIcon: Icons.privacy_tip_rounded,
          iconColor: Colors.orange,
          title: "Protect Your Account",
          description:
              "You currently have no security measures enabled. We recommend Two-Factor Authentication to secure your medical records.",
          isUpdating: false,
          content: const SizedBox.shrink(),
          actions: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: "Set Up Security",
                  onTap: () {
                    Navigator.pop(ctx);
                    _start2FASetupWizard();
                  },
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    "Maybe Later",
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- PRO FIX: Adaptive Glass Security Gate ---
  Future<bool> _enforceSecurityGate(String actionReason) async {
    final gateDecision = _securityGateService.evaluateAal2Gate();
    if (gateDecision.isAllowed) return true;
    if (gateDecision.isUnauthenticated) return false;

    final biometricSuccess = await _stepUpService.authenticateIfTrusted(
      localizedReason: actionReason,
    );
    if (biometricSuccess) return true;

    bool success = false;
    final otpController = TextEditingController();
    final recoveryController = TextEditingController();
    bool isDialogLoading = false;
    bool isRecoveryMode = false;

    if (!mounted) return false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            final themeColor =
                isRecoveryMode ? Colors.orange : AppColors.primaryGreen;

            final defaultPinTheme = PinTheme(
              width: 38,
              height: 48,
              textStyle: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.colorTextDark,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkScaffold : Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : Colors.grey[300]!,
                ),
              ),
            );

            Future<void> submitCode(String code) async {
              setDialogState(() => isDialogLoading = true);
              try {
                if (isRecoveryMode) {
                  final rpcSuccess = await _authRepository.useRecoveryCode(
                    code,
                  );
                  if (rpcSuccess != true) throw "Invalid backup code.";
                } else {
                  await _authRepository.verifyTotpCode(code);
                }
                success = true;
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                setDialogState(() => isDialogLoading = false);
                otpController.clear();
                recoveryController.clear();
                if (ctx.mounted) {
                  CustomSnackbar.showError(
                    ctx,
                    isRecoveryMode
                        ? "Invalid backup code."
                        : "Invalid authenticator code.",
                  );
                }
              }
            }

            return AppFloatingDialog(
              headerIcon:
                  isRecoveryMode
                      ? Icons.lock_open_rounded
                      : Icons.security_rounded,
              iconColor: themeColor,
              title: isRecoveryMode ? "Account Recovery" : "Security Check",
              description:
                  isRecoveryMode
                      ? "Enter an 8-character backup code to verify your identity."
                      : "Please verify your identity with your 6-digit authenticator code.",
              isUpdating: isDialogLoading,
              content: AnimatedCrossFade(
                firstChild: Pinput(
                  length: 6,
                  controller: otpController,
                  autofocus: true,
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: defaultPinTheme.copyWith(
                    decoration: defaultPinTheme.decoration!.copyWith(
                      border: Border.all(color: themeColor, width: 2),
                    ),
                  ),
                  autofillHints: const [],
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onCompleted: submitCode,
                ),
                secondChild: AppTextField(
                  controller: recoveryController,
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [BackupCodeFormatter()],
                  textAlign: TextAlign.center,
                  hintText: "XXXX-XXXX",
                  onChanged: (val) {
                    if (val.length == 9) submitCode(val);
                  },
                  onSubmitted: submitCode,
                ),
                crossFadeState:
                    isRecoveryMode
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 300),
              ),
              actions: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed:
                          isDialogLoading ? null : () => Navigator.pop(ctx),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed:
                          isDialogLoading
                              ? null
                              : () => setDialogState(() {
                                isRecoveryMode = !isRecoveryMode;
                                otpController.clear();
                                recoveryController.clear();
                              }),
                      child: Text(
                        isRecoveryMode ? "Use App" : "Use Backup",
                        style: TextStyle(
                          color: themeColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    return success;
  }

  Future<bool> _handleBiometricToggle(bool enable) async {
    if (_isBiometricToggleBusy) {
      return _isBiometricEnabled;
    }
    setState(() => _isBiometricToggleBusy = true);

    try {
      if (enable) {
        if (!_hasBiometricHardware) {
          throw Exception("Biometric hardware not available.");
        }

        bool passedGate = await _enforceSecurityGate(
          'Verify your identity to enable Biometrics',
        );

        if (!passedGate) {
          return false;
        }

        await Future.delayed(Duration(milliseconds: 300));

        final authenticated = await _biometricAuthService.authenticate(
          localizedReason:
              "Verify your identity to link this device to your DaktarPai account",
        );

        if (authenticated) {
          await _trustedDeviceRepository.trustCurrentDevice(
            isBiometricEnabled: true,
          );
          if (!mounted) {
            return false;
          }
          CustomSnackbar.showSuccess(
            context,
            "Biometric login successfully linked",
          );
          return true;
        } else {
          return false;
        }
      } else {
        bool passedGate = await _enforceSecurityGate(
          'Verify your identity to disable biometric authentication',
        );

        if (!passedGate) {
          return true;
        }

        await _trustedDeviceRepository.revokeCurrentDevice();
        if (!mounted) {
          return false;
        }
        CustomSnackbar.showSuccess(
          context,
          "Biometric login removed from this device",
        );
        return false;
      }
    } catch (e) {
      if (!mounted) {
        return _isBiometricEnabled;
      }
      CustomSnackbar.showError(
        context,
        "Failed to update biometric settings: ${e.toString().replaceAll('Exception: ', '')}",
      );
      return _isBiometricEnabled;
    } finally {
      if (mounted) {
        setState(() => _isBiometricToggleBusy = false);
      }
    }
  }

  Future<bool> _handleTwoFactorToggle(bool enable) async {
    if (_is2FAToggleBusy) {
      return _is2FAEnabled;
    }
    setState(() => _is2FAToggleBusy = true);

    try {
      if (enable) {
        await _start2FASetupWizard();
      } else {
        await _showDisable2FADialog();
      }
      return _is2FAEnabled;
    } catch (error) {
      debugPrint("2FA toggle failed: $error");
      return _is2FAEnabled;
    } finally {
      if (mounted) {
        await _check2FAStatus();
        setState(() => _is2FAToggleBusy = false);
      }
    }
  }

  // --- PRO FIX: Fully Upgraded Adaptive Glass 2FA Wizard ---
  Future<void> _start2FASetupWizard() async {
    int currentStep = 0;
    bool isDialogLoading = false;
    String? qrCodeSvg, secretKey, factorId;
    List<String> generatedCodes = [];
    bool hasSavedCodes = false;
    final codeController = TextEditingController();

    const int stepQR = 1;
    const int stepBackup = 2;
    const int stepBiometricPrompt = 3;
    const int stepSuccess = 4;

    void proceedToBiometricsOrSuccess(Function setDialogState) {
      if (_hasBiometricHardware && !_isBiometricEnabled) {
        setDialogState(() => currentStep = stepBiometricPrompt);
      } else {
        setDialogState(() => currentStep = stepSuccess);
      }
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;

            _activePinSubmit = () async {
              setDialogState(() => isDialogLoading = true);
              try {
                await _settingsRepository.challengeAndVerify(
                  factorId: factorId!,
                  code: codeController.text,
                );

                await Supabase.instance.client.auth.updateUser(
                  UserAttributes(data: {'is_2fa_enabled': true}),
                );

                generatedCodes = _generateLocalCodes();
                await _settingsRepository.saveRecoveryCodes(generatedCodes);

                setDialogState(() {
                  currentStep = stepBackup;
                  isDialogLoading = false;
                });
              } catch (e) {
                setDialogState(() {
                  isDialogLoading = false;
                  codeController.clear();
                });
                if (ctx.mounted) {
                  CustomSnackbar.showError(
                    ctx,
                    "That code didn't match. Please try again.",
                  );
                }
              }
            };

            // 1. INFO STEP
            Widget buildInfoStep() {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.security_rounded,
                      size: 36,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Protect your account",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Add an extra layer of security using an authenticator app.\n\nYou'll need:\n• Google Authenticator or Authy\n• 30 seconds to setup",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  PrimaryButton(
                    isLoading: isDialogLoading,
                    label: "Set Up 2FA",
                    onTap: () async {
                      setDialogState(() => isDialogLoading = true);
                      try {
                        final factors =
                            await _settingsRepository.listMfaFactors();
                        for (final f in factors.all.where(
                          (f) => f.status != FactorStatus.verified,
                        )) {
                          await _settingsRepository.unenrollFactor(f.id);
                        }

                        final response = await _settingsRepository.enrollTotp(
                          issuer: 'DaktarPai',
                          friendlyName:
                              'DaktarPai (${_settingsRepository.currentUserEmail})',
                        );

                        factorId = response.id;
                        qrCodeSvg = response.totp?.qrCode;
                        secretKey = response.totp?.secret;

                        setDialogState(() {
                          currentStep = stepQR;
                          isDialogLoading = false;
                        });
                      } catch (e) {
                        setDialogState(() => isDialogLoading = false);
                        if (ctx.mounted) {
                          CustomSnackbar.showError(
                            ctx,
                            "Failed to start setup. Please try again.",
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      "Close",
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              );
            }

            // 2. QR STEP
            Widget buildQRStep() {
              final defaultPinTheme = PinTheme(
                width: 44,
                height: 54,
                textStyle: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkScaffold : Colors.grey[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : Colors.grey[300]!,
                  ),
                ),
              );

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Scan QR Code",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Scan this with your authenticator app:",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  if (qrCodeSvg != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.3),
                        ),
                      ),
                      height: 140,
                      width: 140,
                      child: SvgPicture.string(qrCodeSvg!),
                    ),
                  const SizedBox(height: 16),
                  const Text(
                    "Or enter this key manually:",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    secretKey ?? "",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Enter the 6-digit code:",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Pinput(
                      length: 6,
                      controller: codeController,
                      autofocus: true,
                      defaultPinTheme: defaultPinTheme,
                      enableInteractiveSelection: false,
                      autofillHints: const [], // Force disable autofill
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      focusedPinTheme: defaultPinTheme.copyWith(
                        decoration: defaultPinTheme.decoration!.copyWith(
                          border: Border.all(
                            color: AppColors.primaryGreen,
                            width: 2,
                          ),
                        ),
                      ),
                      onCompleted: (code) {
                        if (_activePinSubmit != null) _activePinSubmit!();
                      },
                    ),
                  ),
                  if (isDialogLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: AppLoader(
                        strokeWidth: 2,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      "Cancel 2FA Setup",
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              );
            }

            // 3. BACKUP CODES STEP
            Widget buildBackupStep() {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.vpn_key_rounded,
                      size: 36,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Save Backup Codes",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "If you lose your device, these codes are the ONLY way to log in. Please save them.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkScaffold : Colors.grey[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            isDark ? AppColors.darkBorder : Colors.grey[200]!,
                      ),
                    ),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children:
                          generatedCodes
                              .map(
                                (c) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        isDark
                                            ? Colors.black.withValues(
                                              alpha: 0.3,
                                            )
                                            : Colors.white,
                                    border: Border.all(
                                      color:
                                          isDark
                                              ? AppColors.darkBorder
                                              : Colors.grey[300]!,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    c,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: generatedCodes.join('\n')),
                      );
                      if (ctx.mounted) {
                        CustomSnackbar.showSuccess(
                          ctx,
                          "Codes copied to clipboard",
                        );
                      }
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text(
                      "Copy Codes",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          isDark ? Colors.white : AppColors.darkTextPrimary,
                      side: BorderSide(
                        color:
                            isDark ? AppColors.darkBorder : Colors.grey[300]!,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    value: hasSavedCodes,
                    onChanged:
                        (val) =>
                            setDialogState(() => hasSavedCodes = val == true),
                    title: const Text(
                      "I have safely stored these codes",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    activeColor: AppColors.primaryGreen,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: "Finish 2FA Setup",
                    onTap:
                        hasSavedCodes
                            ? () => proceedToBiometricsOrSuccess(setDialogState)
                            : () {},
                    backgroundColor:
                        hasSavedCodes ? AppColors.primaryGreen : Colors.grey,
                  ),
                ],
              );
            }

            // 4. BIOMETRIC PROMPT STEP
            Widget buildBiometricPrompt() {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.fingerprint_rounded,
                      size: 36,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Enable Biometrics",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Would you like to enable Biometric Login for faster access on this device?",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),
                  PrimaryButton(
                    label: "Enable Biometric Login",
                    isLoading: isDialogLoading,
                    onTap: () async {
                      setDialogState(() => isDialogLoading = true);
                      try {
                        await Future.delayed(const Duration(milliseconds: 400));
                        final authenticated = await _biometricAuthService
                            .authenticate(localizedReason: "Verify to link");
                        if (authenticated) {
                          await _trustedDeviceRepository.trustCurrentDevice(
                            isBiometricEnabled: true,
                          );
                          if (ctx.mounted) {
                            CustomSnackbar.showSuccess(
                              ctx,
                              "Biometric login linked",
                            );
                          }
                        }
                      } finally {
                        setDialogState(() {
                          isDialogLoading = false;
                          currentStep = stepSuccess;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed:
                        () => setDialogState(() => currentStep = stepSuccess),
                    child: const Text(
                      "Skip Biometrics",
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              );
            }

            // 5. SUCCESS STEP
            Widget buildSuccessStep() {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 36,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Security Updated",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Your security preferences have been successfully updated.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),
                  PrimaryButton(
                    label: "Done",
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _settingsRepository.refreshSession();
                      _check2FAStatus();
                      _checkBiometricStatus();
                    },
                  ),
                ],
              );
            }

            // MAIN WRAPPER
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? AppColors.deepMedicalSlate
                          : Theme.of(ctx).colorScheme.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color:
                        isDark
                            ? AppColors.darkBorder
                            : Colors.grey.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: SingleChildScrollView(
                  child: AnimatedSwitcher(
                    duration: AppMotion.defaultDuration,
                    child:
                        [
                          buildInfoStep(),
                          buildQRStep(),
                          buildBackupStep(),
                          buildBiometricPrompt(),
                          buildSuccessStep(),
                        ][currentStep],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    _activePinSubmit = null;
  }

  Future<bool> _showDisable2FADialog() async {
    bool passedGate = await _enforceSecurityGate(
      'Verify your identity to disable Two-Factor Authentication',
    );

    if (!passedGate || !mounted) return false;

    try {
      CustomSnackbar.showInfo(context, "Disabling 2FA...");

      if (_isBiometricEnabled) {
        await _trustedDeviceRepository.revokeCurrentDevice();
        _isBiometricEnabled = false;
        SettingsNotifier.instance.updateBiometricState(
          _hasBiometricHardware,
          false,
        );
      }

      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'is_2fa_enabled': false}),
      );

      if (_verifiedFactorId != null) {
        await _settingsRepository.unenrollFactor(_verifiedFactorId!);
      } else {
        final factors = await _settingsRepository.listMfaFactors();
        for (final f in factors.totp) {
          if (f.status == FactorStatus.verified) {
            await _settingsRepository.unenrollFactor(f.id);
          }
        }
      }

      await _settingsRepository.refreshSession();
      await _check2FAStatus();
      await _checkBiometricStatus();

      if (!mounted) return true;
      CustomSnackbar.showSuccess(context, "2FA has been disabled.");
      return true;
    } catch (e) {
      if (!mounted) return false;
      CustomSnackbar.showError(context, "Failed to disable 2FA.");
      return false;
    }
  }

  List<String> _generateLocalCodes() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    return List.generate(
      10,
      (_) =>
          '${List.generate(4, (_) => chars[rnd.nextInt(chars.length)]).join()}-${List.generate(4, (_) => chars[rnd.nextInt(chars.length)]).join()}',
    );
  }

  Future<void> _showChangePasswordDialog() async {
    bool passedGate = await _enforceSecurityGate(
      'Verify your identity to change your password',
    );
    if (!passedGate || !mounted) return;

    bool isDialogLoading = false;
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AppFloatingDialog(
              headerIcon: Icons.lock_reset_rounded,
              iconColor: AppColors.primaryGreen,
              title: "Change Password",
              isUpdating: isDialogLoading,
              content: Column(
                children: [
                  AppTextField(
                    controller: newPassController,
                    hintText: "New Password",
                    isPassword: true,
                    prefix: const Icon(Icons.lock_outline, size: 18),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: confirmPassController,
                    hintText: "Confirm Password",
                    isPassword: true,
                    prefix: const Icon(Icons.lock_outline, size: 18),
                  ),
                ],
              ),
              actions: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed:
                          isDialogLoading
                              ? null
                              : () => Navigator.pop(dialogCtx),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: PrimaryButton(
                      label: "Update",
                      onTap:
                          isDialogLoading
                              ? () {}
                              : () async {
                                final newPass = newPassController.text.trim();
                                if (newPass.length < 6) {
                                  CustomSnackbar.showError(
                                    ctx,
                                    "Password must be at least 6 characters",
                                  );
                                  return;
                                }
                                if (newPass !=
                                    confirmPassController.text.trim()) {
                                  CustomSnackbar.showError(
                                    ctx,
                                    "Passwords do not match",
                                  );
                                  return;
                                }
                                setDialogState(() => isDialogLoading = true);
                                try {
                                  await _settingsRepository.updatePassword(
                                    newPass,
                                  );
                                  if (!dialogCtx.mounted) return;
                                  Navigator.pop(dialogCtx);
                                  if (mounted) {
                                    CustomSnackbar.showSuccess(
                                      context,
                                      "Password updated successfully!",
                                    );
                                  }
                                } on AppFailure catch (failure) {
                                  setDialogState(() => isDialogLoading = false);
                                  if (ctx.mounted) {
                                    CustomSnackbar.showError(
                                      ctx,
                                      failure.userMessage,
                                    );
                                  }
                                } catch (_) {
                                  setDialogState(() => isDialogLoading = false);
                                  if (ctx.mounted) {
                                    CustomSnackbar.showError(
                                      ctx,
                                      "Failed to update password",
                                    );
                                  }
                                }
                              },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showDeleteConfirmation() async {
    bool passedGate = await _enforceSecurityGate(
      'Verify your identity to delete your account',
    );
    if (!passedGate || !mounted) return;

    final confirmController = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            bool canDelete = confirmController.text == "DELETE";

            return AppFloatingDialog(
              headerIcon: Icons.delete_forever_rounded,
              iconColor: AppColors.dangerRed,
              title: "Delete Account",
              description:
                  "This action is irreversible. All your data, medical records, and appointments will be permanently removed.",
              isUpdating: _isLoading,
              content: AppTextField(
                controller: confirmController,
                hintText: "Type DELETE to confirm",
                onChanged: (val) => setDialogState(() {}),
              ),
              actions: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(ctx),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: PrimaryButton(
                      label: "Delete",
                      backgroundColor: AppColors.dangerRed,
                      onTap:
                          canDelete && !_isLoading
                              ? () async {
                                setDialogState(() => _isLoading = true);
                                await _executeAccountDeletion();
                                if (mounted && dialogContext.mounted) {
                                  Navigator.pop(dialogContext);
                                }
                              }
                              : () {},
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _executeAccountDeletion() async {
    setState(() => _isLoading = true);
    try {
      await _settingsRepository.deleteAccount();
      if (!mounted) return;
      CustomSnackbar.showSuccess(context, "Account deleted successfully.");
      context.go(AppRoutes.login);
    } catch (e) {
      if (!mounted) return;
      CustomSnackbar.showError(
        context,
        "Account deletion failed: ${e.toString()}",
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text("Settings", style: AppTextStyles.h2(context)),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => context.pop(),
              color: context.colorTextDark,
            ),
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SettingsAccountSecuritySection(
                  hasEmailProvider: _hasEmailProvider,
                  hasBiometricHardware: _hasBiometricHardware,
                  isBiometricEnabled: _isBiometricEnabled,
                  isBiometricToggleBusy: _isBiometricToggleBusy,
                  onBiometricToggle: (val) async {
                    final result = await _handleBiometricToggle(val);
                    if (mounted) setState(() => _isBiometricEnabled = result);
                    return result;
                  },
                  is2FAEnabled: _is2FAEnabled,
                  is2FAToggleBusy: _is2FAToggleBusy,
                  onTwoFactorToggle: _handleTwoFactorToggle,
                  onTapChangePassword: _showChangePasswordDialog,
                  onTapDeleteAccount: _showDeleteConfirmation,
                ),
                SizedBox(height: 32),
                SettingsPreferencesSection(
                  isBiometricEnabled: _isBiometricEnabled,
                ),
                SizedBox(height: 32),
                SettingsSupportLegalSection(),
                SizedBox(height: 40),
              ],
            ),
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.5),
            child: const AppLoader(),
          ),
      ],
    );
  }
}
