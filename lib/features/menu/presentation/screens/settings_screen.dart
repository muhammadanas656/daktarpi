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
import '../../../../core/services/appointment_notification_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/security_formatters.dart';
import '../../../../presentation/widgets/auth_text_field.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';
import '../../../../presentation/widgets/pessimistic_switch.dart';
import '../../../../presentation/widgets/primary_button.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/data/security_gate_service.dart';
import '../../../auth/data/trusted_device_repository.dart';
import '../../../profile/presentation/profile_notifier.dart';
import '../../../settings/presentation/settings_notifier.dart';
import '../../data/settings_repository.dart';

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
          WidgetsBinding.instance.addPostFrameCallback((_) {
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
      builder:
          (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(Icons.shield_outlined, color: AppColors.primaryGreen),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Protect Your Account",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: const SingleChildScrollView(
              child: Text(
                "You currently have no security measures enabled. We strongly recommend setting up Two-Factor Authentication to secure your medical records.",
                style: TextStyle(color: AppColors.textLight, height: 1.4),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  "Maybe Later",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _start2FASetupWizard();
                },
                child: const Text(
                  "Set Up Security",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
    );
  }

  Future<bool> _enforceSecurityGate(String actionReason) async {
    final gateDecision = _securityGateService.evaluateAal2Gate();
    if (gateDecision.isAllowed) {
      return true;
    }
    if (gateDecision.isUnauthenticated) {
      return false;
    }

    final biometricSuccess = await _stepUpService.authenticateIfTrusted(
      localizedReason: actionReason,
    );
    if (biometricSuccess) {
      return true;
    }

    bool success = false;
    final otpController = TextEditingController();
    final recoveryController = TextEditingController();
    bool isDialogLoading = false;
    bool isRecoveryMode = false;

    if (!mounted) {
      return false;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final defaultPinTheme = PinTheme(
              width: 36,
              height: 46,
              textStyle: const TextStyle(
                fontSize: 18,
                color: AppColors.textDark,
                fontWeight: FontWeight.bold,
              ),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderColor),
              ),
            );

            Future<void> submitCode(String code) async {
              setDialogState(() => isDialogLoading = true);
              try {
                if (isRecoveryMode) {
                  final rpcSuccess = await _authRepository.useRecoveryCode(
                    code,
                  );
                  if (rpcSuccess != true) {
                    throw "Invalid backup code.";
                  }
                } else {
                  await _authRepository.verifyTotpCode(code);
                }
                success = true;
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
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

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(
                    isRecoveryMode ? Icons.lock_open : Icons.security,
                    color:
                        isRecoveryMode ? Colors.orange : AppColors.primaryGreen,
                  ),
                  const SizedBox(width: 10),
                  Text(isRecoveryMode ? "Account Recovery" : "Security Check"),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isRecoveryMode
                          ? "Enter an 8-character backup code to verify your identity."
                          : "Please verify your identity with your 6-digit authenticator code.",
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textLight,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    AnimatedCrossFade(
                      firstChild: Pinput(
                        length: 6,
                        controller: otpController,
                        autofocus: true,
                        defaultPinTheme: defaultPinTheme,
                        onClipboardFound: null,
                        autofillHints: null,
                        enableInteractiveSelection: false,
                        focusedPinTheme: defaultPinTheme.copyWith(
                          decoration: defaultPinTheme.decoration!.copyWith(
                            border: Border.all(
                              color: AppColors.primaryGreen,
                              width: 2,
                            ),
                          ),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onCompleted: submitCode,
                      ),
                      secondChild: TextField(
                        controller: recoveryController,
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.characters,
                        enableInteractiveSelection: false,
                        inputFormatters: [BackupCodeFormatter()],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          fontFamily: 'monospace',
                        ),
                        decoration: InputDecoration(
                          hintText: "XXXX-XXXX",
                          border: OutlineInputBorder(
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
                            submitCode(val);
                          }
                        },
                        onSubmitted: submitCode,
                      ),
                      crossFadeState:
                          isRecoveryMode
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 300),
                    ),
                    if (isDialogLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isDialogLoading ? null : () => Navigator.pop(ctx),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                TextButton(
                  onPressed:
                      isDialogLoading
                          ? null
                          : () => setDialogState(() {
                            isRecoveryMode = !isRecoveryMode;
                            otpController.clear();
                            recoveryController.clear();
                          }),
                  child: Text(
                    isRecoveryMode ? "Use Authenticator" : "Use Backup Code",
                    style: TextStyle(
                      color:
                          isRecoveryMode
                              ? AppColors.primaryGreen
                              : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
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

        await Future.delayed(const Duration(milliseconds: 300));

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

            Widget buildInfoStep() {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.security,
                    size: 50,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Protect your account",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Add an extra layer of security using an authenticator app.\n\nYou'll need:\n• Google Authenticator or Authy\n• 30 seconds to setup",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textLight,
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
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      "Close",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              );
            }

            Widget buildQRStep() {
              // FIX: Defined explicit pin dimensions to prevent stretching
              final defaultPinTheme = PinTheme(
                width: 44,
                height: 54,
                textStyle: const TextStyle(
                  fontSize: 22,
                  color: AppColors.textDark,
                  fontWeight: FontWeight.bold,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderColor),
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
                    style: TextStyle(fontSize: 13, color: AppColors.textLight),
                  ),
                  const SizedBox(height: 16),
                  if (qrCodeSvg != null)
                    SizedBox(
                      height: 130,
                      width: 130,
                      child: SvgPicture.string(qrCodeSvg!),
                    ),
                  const SizedBox(height: 12),
                  const Text(
                    "Or enter this key manually:",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  SelectableText(
                    secretKey ?? "",
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Enter the 6-digit code:",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  // FIX: Wrapped in Center to maintain proper proportions
                  Center(
                    child: Pinput(
                      length: 6,
                      controller: codeController,
                      autofocus: true,
                      defaultPinTheme: defaultPinTheme,
                      onClipboardFound: null,
                      autofillHints: null,
                      enableInteractiveSelection: false,
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
                        if (_activePinSubmit != null) {
                          _activePinSubmit!();
                        }
                      },
                    ),
                  ),
                  if (isDialogLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      "Cancel 2FA Setup",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              );
            }

            Widget buildBackupStep() {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.vpn_key_outlined,
                    size: 40,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Save Backup Codes",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "If you lose your device, these codes are the ONLY way to log in.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textLight,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children:
                          generatedCodes
                              .map(
                                (c) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(
                                      color: Colors.grey[300]!,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    c,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
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
                    label: const Text("Copy Codes"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textDark,
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
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    activeColor: AppColors.primaryGreen,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
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

            Widget buildBiometricPrompt() {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.fingerprint_rounded,
                    size: 60,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Enable Biometrics",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Would you like to enable Biometric Login for faster access on this device?",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: AppColors.textLight),
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
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      "Skip Biometrics",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              );
            }

            Widget buildSuccessStep() {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 60,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Security Updated",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Your security preferences have been successfully updated.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: AppColors.textLight),
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

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              contentPadding: const EdgeInsets.all(24),
              content: SingleChildScrollView(
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
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.lock_outline, color: AppColors.primaryGreen),
                  SizedBox(width: 10),
                  Text("Change Password"),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.verified,
                          color: AppColors.primaryGreen,
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          "Identity verified.",
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Enter your new password below.",
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    AuthTextField(
                      controller: newPassController,
                      hintText: "New Password",
                      isPassword: true,
                    ),
                    const SizedBox(height: 12),
                    AuthTextField(
                      controller: confirmPassController,
                      hintText: "Confirm Password",
                      isPassword: true,
                    ),
                    if (isDialogLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isDialogLoading ? null : () => Navigator.pop(dialogCtx),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                TextButton(
                  onPressed:
                      isDialogLoading
                          ? null
                          : () async {
                            final newPass = newPassController.text.trim();
                            final confirmPass =
                                confirmPassController.text.trim();
                            if (newPass.length < 6) {
                              CustomSnackbar.showError(
                                ctx,
                                "Password must be at least 6 characters",
                              );
                              return;
                            }
                            if (newPass != confirmPass) {
                              CustomSnackbar.showError(
                                ctx,
                                "Passwords do not match",
                              );
                              return;
                            }
                            setDialogState(() => isDialogLoading = true);
                            try {
                              await _settingsRepository.updatePassword(newPass);
                              if (!dialogCtx.mounted) return;
                              Navigator.pop(dialogCtx);
                              if (!mounted) return;
                              CustomSnackbar.showSuccess(
                                context,
                                "Password updated successfully!",
                              );
                            } on AppFailure catch (failure) {
                              setDialogState(() => isDialogLoading = false);
                              if (!ctx.mounted) return;
                              CustomSnackbar.showError(
                                ctx,
                                failure.userMessage,
                              );
                            } catch (e) {
                              setDialogState(() => isDialogLoading = false);
                              if (!ctx.mounted) return;
                              CustomSnackbar.showError(
                                ctx,
                                "Failed to update password",
                              );
                            }
                          },
                  child: const Text(
                    "Update",
                    style: TextStyle(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
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
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            bool canDelete = confirmController.text == "DELETE";
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red),
                  SizedBox(width: 8),
                  Text(
                    "Delete Account",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "This action is irreversible. All your data, medical records, and appointments will be permanently removed.",
                      style: TextStyle(fontSize: 14, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Type DELETE to confirm:",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: confirmController,
                      decoration: InputDecoration(
                        hintText: "DELETE",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (val) => setDialogState(() {}),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                TextButton(
                  onPressed:
                      canDelete
                          ? () {
                            Navigator.pop(ctx);
                            _executeAccountDeletion();
                          }
                          : null,
                  child: Text(
                    "Delete",
                    style: TextStyle(
                      color:
                          canDelete
                              ? Colors.red
                              : Colors.red.withValues(alpha: 0.5),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
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
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            title: Text("Settings", style: AppTextStyles.h2),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => context.pop(),
              color: AppColors.textDark,
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader("Account & Security"),
                _buildSettingsTile(
                  context,
                  icon: Icons.lock_outline,
                  title: "Change Password",
                  onTap: _showChangePasswordDialog,
                ),
                _buildSettingsTile(
                  context,
                  icon: Icons.link,
                  title: "Linked Accounts",
                  subtitle: "Facebook, Google",
                  onTap: () => context.push(AppRoutes.linkedAccounts),
                ),
                if (_hasBiometricHardware && _is2FAEnabled)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.fingerprint_rounded,
                          color: AppColors.primaryGreen,
                          size: 20,
                        ),
                      ),
                      title: const Text(
                        "Enable Biometric Login",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textDark,
                        ),
                      ),
                      subtitle:
                          _isBiometricToggleBusy
                              ? Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Row(
                                  children: [
                                    const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primaryGreen,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        "Updating...",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textLight,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              : Text(
                                _isBiometricEnabled
                                    ? "Linked to this device"
                                    : "Not configured",
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      _isBiometricEnabled
                                          ? AppColors.primaryGreen
                                          : AppColors.textLight,
                                ),
                              ),
                      trailing: PessimisticSwitch(
                        value: _isBiometricEnabled,
                        enabled: !_isBiometricToggleBusy,
                        activeColor: AppColors.primaryGreen,
                        onAttemptChange: (val) async {
                          final result = await _handleBiometricToggle(val);
                          setState(() => _isBiometricEnabled = result);
                          return result;
                        },
                      ),
                    ),
                  ),
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.security,
                        color: AppColors.primaryGreen,
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      "Two-Factor Authentication",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textDark,
                      ),
                    ),
                    subtitle:
                        _is2FAToggleBusy
                            ? Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Row(
                                children: [
                                  const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primaryGreen,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      "Updating security setting...",
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textLight,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                            : Text(
                              _is2FAEnabled
                                  ? "Enabled via Authenticator"
                                  : "Disabled",
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    _is2FAEnabled
                                        ? AppColors.primaryGreen
                                        : AppColors.textLight,
                              ),
                            ),
                    trailing: PessimisticSwitch(
                      value: _is2FAEnabled,
                      enabled: !_is2FAToggleBusy,
                      activeColor: AppColors.primaryGreen,
                      onAttemptChange: _handleTwoFactorToggle,
                    ),
                  ),
                ),
                _buildSettingsTile(
                  context,
                  icon: Icons.delete_forever,
                  title: "Delete Account",
                  isDestructive: true,
                  onTap: _showDeleteConfirmation,
                ),
                const SizedBox(height: 32),
                _buildSectionHeader("Preferences"),
                AnimatedBuilder(
                  animation: SettingsNotifier.instance,
                  builder: (context, child) {
                    return SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      secondary: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.notifications_none,
                          color: AppColors.primaryGreen,
                          size: 20,
                        ),
                      ),
                      title: const Text(
                        "Notifications",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textDark,
                        ),
                      ),
                      subtitle: const Text(
                        "Receive appointment reminders",
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textLight,
                        ),
                      ),
                      value: SettingsNotifier.instance.notificationsEnabled,
                      activeColor: AppColors.primaryGreen,
                      onChanged: (val) async {
                        await SettingsNotifier.instance
                            .updateNotificationsEnabled(val);
                        if (!val) {
                          await AppointmentNotificationService.instance
                              .cancelAllReminders();
                        }
                      },
                    );
                  },
                ),
                if (_isBiometricEnabled)
                  AnimatedBuilder(
                    animation: SettingsNotifier.instance,
                    builder: (context, child) {
                      return _buildSettingsTile(
                        context,
                        icon: Icons.timer_outlined,
                        title: "Inactivity Lock",
                        value: _getTimeoutName(
                          SettingsNotifier.instance.inactivityTimeoutMs,
                        ),
                        onTap: () => _showTimeoutSelectionDialog(),
                      );
                    },
                  ),
                _buildSettingsTile(
                  context,
                  icon: Icons.attach_money,
                  title: "Currency",
                  value: ProfileNotifier.instance.currencySymbol,
                  subtitle: "Set automatically by location",
                  onTap:
                      () => CustomSnackbar.showInfo(
                        context,
                        "Currency is automatically configured based on your profile location.",
                      ),
                ),
                _buildSettingsTile(
                  context,
                  icon: Icons.dark_mode_outlined,
                  title: "Appearance",
                  value: _getThemeName(SettingsNotifier.instance.themeMode),
                  onTap: () async {
                    await showModalBottomSheet(
                      context: context,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      builder: (context) {
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                "Appearance",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ListTile(
                                leading: const Icon(Icons.brightness_auto),
                                title: const Text("System Default"),
                                trailing:
                                    SettingsNotifier.instance.themeMode ==
                                            ThemeMode.system
                                        ? const Icon(
                                          Icons.check,
                                          color: AppColors.primaryGreen,
                                        )
                                        : null,
                                onTap: () {
                                  SettingsNotifier.instance.updateThemeMode(
                                    ThemeMode.system,
                                  );
                                  Navigator.pop(context);
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.light_mode),
                                title: const Text("Light"),
                                trailing:
                                    SettingsNotifier.instance.themeMode ==
                                            ThemeMode.light
                                        ? const Icon(
                                          Icons.check,
                                          color: AppColors.primaryGreen,
                                        )
                                        : null,
                                onTap: () {
                                  SettingsNotifier.instance.updateThemeMode(
                                    ThemeMode.light,
                                  );
                                  Navigator.pop(context);
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.dark_mode),
                                title: const Text("Dark"),
                                trailing:
                                    SettingsNotifier.instance.themeMode ==
                                            ThemeMode.dark
                                        ? const Icon(
                                          Icons.check,
                                          color: AppColors.primaryGreen,
                                        )
                                        : null,
                                onTap: () {
                                  SettingsNotifier.instance.updateThemeMode(
                                    ThemeMode.dark,
                                  );
                                  Navigator.pop(context);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                    if (mounted) setState(() {});
                  },
                ),
                AnimatedBuilder(
                  animation: SettingsNotifier.instance,
                  builder: (context, child) {
                    return SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      secondary: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.animation,
                          color: AppColors.primaryGreen,
                          size: 20,
                        ),
                      ),
                      title: const Text(
                        "Menu Drawer Hint",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textDark,
                        ),
                      ),
                      subtitle: const Text(
                        "Show animation on startup",
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textLight,
                        ),
                      ),
                      value: SettingsNotifier.instance.showDrawerHint,
                      activeColor: AppColors.primaryGreen,
                      onChanged: (val) {
                        SettingsNotifier.instance.updateShowDrawerHint(val);
                      },
                    );
                  },
                ),
                const SizedBox(height: 32),
                _buildSectionHeader("Support & Legal"),
                _buildSettingsTile(
                  context,
                  icon: Icons.help_outline,
                  title: "Help Center",
                  onTap: () => context.push(AppRoutes.helpCenter),
                ),
                _buildSettingsTile(
                  context,
                  icon: Icons.privacy_tip_outlined,
                  title: "Privacy Policy",
                  onTap: () => context.push(AppRoutes.privacyPolicy),
                ),
                _buildSettingsTile(
                  context,
                  icon: Icons.description_outlined,
                  title: "Terms of Service",
                  onTap: () => context.push(AppRoutes.termsOfService),
                ),
                _buildSettingsTile(
                  context,
                  icon: Icons.info_outline,
                  title: "About App",
                  value: "v1.0.0",
                  onTap: () {},
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.5),
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textLight,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    String? value,
    bool isDestructive = false,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color:
                isDestructive
                    ? Colors.red.withValues(alpha: 0.1)
                    : AppColors.primaryGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: isDestructive ? Colors.red : AppColors.primaryGreen,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isDestructive ? Colors.red : AppColors.textDark,
          ),
        ),
        subtitle:
            subtitle != null
                ? Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                )
                : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textLight,
                  ),
                ),
              ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: AppColors.textLight,
            ),
          ],
        ),
      ),
    );
  }

  String _getThemeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return "System Default";
      case ThemeMode.light:
        return "Light";
      case ThemeMode.dark:
        return "Dark";
    }
  }

  String _getTimeoutName(int ms) {
    if (ms == 0) return "Off";
    if (ms == 60000) return "1 Minute";
    if (ms == 300000) return "5 Minutes";
    if (ms == 900000) return "15 Minutes";
    if (ms == 1800000) return "30 Minutes";
    if (ms == 3600000) return "1 Hour";
    return "5 Minutes";
  }

  void _showTimeoutSelectionDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Inactivity Lock",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...[0, 60000, 300000, 900000, 1800000, 3600000].map((timeout) {
                return ListTile(
                  title: Text(_getTimeoutName(timeout)),
                  trailing:
                      SettingsNotifier.instance.inactivityTimeoutMs == timeout
                          ? const Icon(
                            Icons.check,
                            color: AppColors.primaryGreen,
                          )
                          : null,
                  onTap: () {
                    SettingsNotifier.instance.updateInactivityTimeout(timeout);
                    Navigator.pop(context);
                    if (mounted) setState(() {});
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
