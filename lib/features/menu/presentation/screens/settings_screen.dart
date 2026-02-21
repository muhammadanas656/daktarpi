import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:pinput/pinput.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';
import '../../../../presentation/widgets/primary_button.dart';
import '../../../profile/presentation/profile_notifier.dart';
import '../../../../presentation/widgets/auth_text_field.dart';
import '../../../settings/presentation/settings_notifier.dart';
import '../../../../core/utils/security_formatters.dart';
import '../../../auth/presentation/models/verify_2fa_route_args.dart';
import '../../data/settings_repository.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  bool _isLoading = false;
  bool _is2FAEnabled = false;
  bool _is2FAToggleBusy = false;
  String? _verifiedFactorId;
  bool _hasRecoveryCodes = false;
  final SettingsRepository _settingsRepository = SettingsRepository();

  TextEditingController? _activePinController;
  VoidCallback? _activePinSubmit;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SettingsNotifier.instance.loadSettings();
    _check2FAStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _activePinController != null) {
      _checkClipboardAndPaste();
    }
  }

  Future<void> _checkClipboardAndPaste() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isEmpty) {
        return;
      }

      final cleanText = text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

      // Check if it's a 6 digit number
      if (cleanText.length == 6 && RegExp(r'^[0-9]+$').hasMatch(cleanText)) {
        if (_activePinController!.text != cleanText) {
          setState(() {
            _activePinController!.text = cleanText;
          });
          if (_activePinSubmit != null) {
            _activePinSubmit!();
          }
        }
      }
      // Check if it's an 8 char backup code
      else if (cleanText.length == 8) {
        final formattedCode =
            '${cleanText.substring(0, 4)}-${cleanText.substring(4)}';
        if (_activePinController!.text != formattedCode) {
          setState(() {
            _activePinController!.text = formattedCode;
          });
          if (_activePinSubmit != null) {
            _activePinSubmit!();
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _check2FAStatus() async {
    try {
      final user = _settingsRepository.currentUser;
      final factors = await _settingsRepository.listMfaFactors();

      final hasCodes = await _settingsRepository.userHasRecoveryCodes();

      if (mounted) {
        setState(() {
          final totpFactors = factors.totp;
          final hasFactor = totpFactors.isNotEmpty;
          final isEnabledInMetadata =
              user?.appMetadata['is_2fa_enabled'] == true;

          _is2FAEnabled = hasFactor && isEnabledInMetadata;
          _hasRecoveryCodes = hasCodes;

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
      }
    } catch (e) {
      debugPrint("Error checking 2FA status: $e");
    }
  }

  Future<void> _handleTwoFactorToggle(bool enable) async {
    if (_is2FAToggleBusy) {
      return;
    }

    setState(() {
      _is2FAToggleBusy = true;
    });

    try {
      if (enable) {
        await _start2FASetupWizard();
      } else {
        await _showDisable2FADialog();
      }
    } finally {
      if (mounted) {
        setState(() {
          _is2FAToggleBusy = false;
        });
      }
    }
  }

  Future<bool> _verifyRecentMfaForSensitiveAction() async {
    if (!mounted) {
      return false;
    }

    final verified = await context.push<bool>(
      AppRoutes.verify2fa,
      extra: const Verify2FARouteArgs(popOnSuccess: true),
    );

    if (verified == true) {
      await _settingsRepository.refreshSession();
      await _check2FAStatus();
      return true;
    }

    if (mounted) {
      CustomSnackbar.showInfo(context, "Security verification was cancelled.");
    }
    return false;
  }

  Future<void> _start2FASetupWizard() async {
    int currentStep = 0;
    bool isDialogLoading = false;
    String? qrCodeSvg, secretKey, factorId;
    List<String> generatedCodes = [];
    bool hasSavedCodes = false;

    final codeController = TextEditingController();
    _activePinController = codeController;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            _activePinSubmit = () async {
              setDialogState(() {
                isDialogLoading = true;
              });
              try {
                await _settingsRepository.challengeAndVerify(
                  factorId: factorId!,
                  code: codeController.text,
                );
                generatedCodes = _generateLocalCodes();
                await _settingsRepository.saveRecoveryCodes(generatedCodes);
                setDialogState(() {
                  currentStep = 2;
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
                    "Add an extra layer of security to your medical records using an authenticator app.\n\nYou'll need:\n• Google Authenticator or Authy\n• 30 seconds to setup",
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
                    label: "Get Started",
                    onTap: () async {
                      setDialogState(() {
                        isDialogLoading = true;
                      });
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
                          currentStep = 1;
                          isDialogLoading = false;
                        });
                      } catch (e) {
                        setDialogState(() {
                          isDialogLoading = false;
                        });
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
                      "Cancel",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              );
            }

            Widget buildQRStep() {
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
                      height:
                          130, // Optimized size so it doesn't overflow when keyboard opens
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

                  Pinput(
                    length: 6,
                    controller: codeController,
                    defaultPinTheme: defaultPinTheme,
                    autofocus: true,
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

                  if (isDialogLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryGreen,
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
                    "If you lose your device, these codes are the ONLY way to log in. Each code works once.",
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
                      CustomSnackbar.showSuccess(
                        context,
                        "Codes copied to clipboard",
                      );
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
                    onChanged: (val) {
                      setDialogState(() {
                        hasSavedCodes = val == true;
                      });
                    },
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
                    label: "Finish Setup",
                    onTap:
                        hasSavedCodes
                            ? () {
                              setDialogState(() {
                                currentStep = 3;
                              });
                            }
                            : () {},
                    backgroundColor:
                        hasSavedCodes ? AppColors.primaryGreen : Colors.grey,
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
                    "Setup Complete",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Your account is now protected with Two-Factor Authentication.",
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
                  duration: const Duration(milliseconds: 300),
                  child:
                      [
                        buildInfoStep(),
                        buildQRStep(),
                        buildBackupStep(),
                        buildSuccessStep(),
                      ][currentStep],
                ),
              ),
            );
          },
        );
      },
    );

    _activePinController = null;
    _activePinSubmit = null;
  }

  Future<bool> _showDisable2FADialog() async {
    final otpController = TextEditingController();
    final recoveryController = TextEditingController();
    bool isDialogLoading = false;
    bool isRecoveryMode = false;
    bool disabled = false;

    _activePinController = otpController;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            _activePinSubmit = () async {
              final code =
                  isRecoveryMode
                      ? recoveryController.text.trim()
                      : otpController.text.trim();

              if (isRecoveryMode && code.isEmpty) {
                CustomSnackbar.showError(ctx, "Please enter a backup code.");
                return;
              } else if (!isRecoveryMode && code.length != 6) {
                CustomSnackbar.showError(ctx, "Please enter the 6-digit code.");
                return;
              }

              setDialogState(() {
                isDialogLoading = true;
              });

              try {
                if (isRecoveryMode) {
                  final rpcSuccess = await _settingsRepository.useRecoveryCode(
                    code,
                  );
                  if (rpcSuccess != true) {
                    throw "Invalid backup code.";
                  }
                } else {
                  await _settingsRepository.challengeAndVerify(
                    factorId: _verifiedFactorId!,
                    code: code,
                  );
                  await _settingsRepository.unenrollFactor(_verifiedFactorId!);
                }

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                disabled = true;
                await _check2FAStatus();
                if (mounted) {
                  CustomSnackbar.showSuccess(context, "2FA has been disabled.");
                }
              } on AppFailure catch (failure) {
                if (failure.isRequiresRecentMfa) {
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }

                  final upgraded = await _verifyRecentMfaForSensitiveAction();
                  if (upgraded) {
                    disabled = await _showDisable2FADialog();
                  }
                  return;
                }

                setDialogState(() {
                  isDialogLoading = false;
                });
                otpController.clear();
                recoveryController.clear();
                if (ctx.mounted) {
                  CustomSnackbar.showError(ctx, failure.userMessage);
                }
              } catch (e) {
                setDialogState(() {
                  isDialogLoading = false;
                });
                otpController.clear();
                recoveryController.clear();
                if (ctx.mounted) {
                  CustomSnackbar.showError(
                    ctx,
                    isRecoveryMode
                        ? "Invalid backup code."
                        : "Verification failed. Invalid code.",
                  );
                }
              }
            };

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

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(
                    isRecoveryMode
                        ? Icons.lock_open
                        : Icons.warning_amber_rounded,
                    color: isRecoveryMode ? Colors.orange : Colors.red,
                  ),
                  const SizedBox(width: 10),
                  Text(isRecoveryMode ? "Use Backup Code" : "Disable 2FA?"),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isRecoveryMode
                          ? "Enter an 8-character backup code to turn off Two-Factor Authentication."
                          : "Your account will be less secure. To confirm this action, please enter a final authenticator code.",
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
                        focusedPinTheme: defaultPinTheme.copyWith(
                          decoration: defaultPinTheme.decoration!.copyWith(
                            border: Border.all(color: Colors.red, width: 2),
                          ),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onCompleted: (pin) {
                          if (_activePinSubmit != null) {
                            _activePinSubmit!();
                          }
                        },
                      ),
                      secondChild: TextField(
                        controller: recoveryController,
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.characters,
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
                          if (val.length == 9 && _activePinSubmit != null) {
                            _activePinSubmit!();
                          }
                        },
                        onSubmitted: (val) {
                          if (_activePinSubmit != null) {
                            _activePinSubmit!();
                          }
                        },
                      ),
                      crossFadeState:
                          isRecoveryMode
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 300),
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
                          : () {
                            setDialogState(() {
                              isRecoveryMode = !isRecoveryMode;
                              _activePinController =
                                  isRecoveryMode
                                      ? recoveryController
                                      : otpController;
                              otpController.clear();
                              recoveryController.clear();
                            });
                          },
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

    _activePinController = null;
    _activePinSubmit = null;
    return disabled;
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

  void _handleRecoveryCodesTap() {
    if (_hasRecoveryCodes) {
      _showRegenerateConfirmation();
    } else {
      CustomSnackbar.showInfo(
        context,
        "Please disable and re-enable 2FA to generate new codes.",
      );
    }
  }

  Future<void> _showRegenerateConfirmation() async {
    await showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text(
              "Regenerate Codes?",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: const Text(
              "This will invalidate your existing backup codes.\n\nAre you sure you want to generate new ones?",
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
                onPressed: () {
                  Navigator.pop(ctx);
                  _generateAndShowCodes();
                },
                child: const Text(
                  "Regenerate",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _generateAndShowCodes() async {
    setState(() {
      _isLoading = true;
    });

    List<String> codes = [];
    try {
      codes = _generateLocalCodes();
      await _settingsRepository.saveRecoveryCodes(codes);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        CustomSnackbar.showError(context, "Failed to generate codes: $e");
      }
      return;
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }

    if (!mounted) {
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isCheckboxChecked = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                "New Backup Codes",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children:
                              codes
                                  .map(
                                    (code) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.grey[300]!,
                                        ),
                                      ),
                                      child: Text(
                                        code,
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
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
                            ClipboardData(text: codes.join('\n')),
                          );
                          CustomSnackbar.showSuccess(
                            context,
                            "Codes copied to clipboard",
                          );
                        },
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text("Copy Codes"),
                      ),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        value: isCheckboxChecked,
                        onChanged: (val) {
                          setDialogState(() {
                            isCheckboxChecked = val == true;
                          });
                        },
                        title: const Text(
                          "I have securely saved these codes.",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        activeColor: AppColors.primaryGreen,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isCheckboxChecked ? () => Navigator.pop(ctx) : null,
                  child: Text(
                    "Done",
                    style: TextStyle(
                      color:
                          isCheckboxChecked
                              ? AppColors.primaryGreen
                              : Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    if (mounted) {
      await _check2FAStatus();
    }
  }

  Future<void> _showChangePasswordDialog() async {
    int currentStep = _is2FAEnabled ? 0 : 1;
    bool isDialogLoading = false;
    bool isRecoveryMode = false;

    final otpController = TextEditingController();
    final recoveryController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();

    if (_is2FAEnabled) {
      _activePinController = otpController;
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

            _activePinSubmit = () async {
              if (currentStep == 0) {
                final code =
                    isRecoveryMode
                        ? recoveryController.text.trim()
                        : otpController.text.trim();

                if (isRecoveryMode && code.isEmpty) {
                  CustomSnackbar.showError(ctx, "Please enter a backup code.");
                  return;
                } else if (!isRecoveryMode && code.length != 6) {
                  CustomSnackbar.showError(
                    ctx,
                    "Please enter the 6-digit code.",
                  );
                  return;
                }

                setDialogState(() {
                  isDialogLoading = true;
                });

                try {
                  if (isRecoveryMode) {
                    final rpcSuccess = await _settingsRepository
                        .useRecoveryCode(code);
                    if (rpcSuccess != true) {
                      throw "Invalid backup code.";
                    }
                  } else {
                    await _settingsRepository.challengeAndVerify(
                      factorId: _verifiedFactorId!,
                      code: code,
                    );
                  }

                  await _settingsRepository.refreshSession();
                  setDialogState(() {
                    isDialogLoading = false;
                    currentStep = 1;
                  });
                } catch (e) {
                  setDialogState(() {
                    isDialogLoading = false;
                  });
                  otpController.clear();
                  recoveryController.clear();

                  if (!ctx.mounted) {
                    return;
                  }
                  CustomSnackbar.showError(
                    ctx,
                    isRecoveryMode
                        ? "Invalid backup code."
                        : "Verification failed. Invalid code.",
                  );
                }
              }
            };

            Widget buildAuthStep() {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isRecoveryMode
                        ? "Enter an 8-character backup code to verify your identity before changing your password."
                        : "To change your password, please verify your identity with your 6-digit authenticator code.",
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textLight,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  AnimatedCrossFade(
                    firstChild: Center(
                      child: Pinput(
                        length: 6,
                        controller: otpController,
                        autofocus: true,
                        defaultPinTheme: defaultPinTheme,
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
                        onCompleted: (pin) {
                          if (_activePinSubmit != null) {
                            _activePinSubmit!();
                          }
                        },
                      ),
                    ),
                    secondChild: Center(
                      child: TextField(
                        controller: recoveryController,
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.characters,
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
                          if (val.length == 9 && _activePinSubmit != null) {
                            _activePinSubmit!();
                          }
                        },
                        onSubmitted: (val) {
                          if (_activePinSubmit != null) {
                            _activePinSubmit!();
                          }
                        },
                      ),
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
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ),
                ],
              );
            }

            Widget buildPasswordStep() {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_is2FAEnabled) ...[
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
                  ],
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
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ),
                ],
              );
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(
                    currentStep == 0
                        ? (isRecoveryMode ? Icons.lock_open : Icons.security)
                        : Icons.lock_outline,
                    color:
                        currentStep == 0 && isRecoveryMode
                            ? Colors.orange
                            : AppColors.primaryGreen,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    currentStep == 0
                        ? (isRecoveryMode
                            ? "Account Recovery"
                            : "Security Check")
                        : "Change Password",
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child:
                      currentStep == 0 ? buildAuthStep() : buildPasswordStep(),
                ),
              ),
              actions: [
                if (currentStep == 0) ...[
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
                            : () {
                              setDialogState(() {
                                isRecoveryMode = !isRecoveryMode;
                                _activePinController =
                                    isRecoveryMode
                                        ? recoveryController
                                        : otpController;
                                otpController.clear();
                                recoveryController.clear();
                              });
                            },
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
                ] else ...[
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

                              setDialogState(() {
                                isDialogLoading = true;
                              });

                              try {
                                await _settingsRepository.updatePassword(
                                  newPass,
                                );

                                if (!dialogCtx.mounted) {
                                  return;
                                }
                                Navigator.pop(dialogCtx);

                                if (!mounted) {
                                  return;
                                }
                                CustomSnackbar.showSuccess(
                                  context,
                                  "Password updated successfully!",
                                );
                              } catch (e) {
                                setDialogState(() {
                                  isDialogLoading = false;
                                });

                                if (!ctx.mounted) {
                                  return;
                                }
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
              ],
            );
          },
        );
      },
    );

    _activePinController = null;
    _activePinSubmit = null;
  }

  Future<void> _showDeleteConfirmation(BuildContext context) async {
    final confirmController = TextEditingController();
    final otpController = TextEditingController();
    bool isDialogLoading = false;

    if (_is2FAEnabled) {
      _activePinController = otpController;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            bool canDelete = confirmController.text == "DELETE";

            _activePinSubmit = () async {
              if (!canDelete) {
                CustomSnackbar.showError(ctx, "Please type DELETE to confirm.");
                return;
              }
              if (_is2FAEnabled && otpController.text.length != 6) {
                CustomSnackbar.showError(
                  ctx,
                  "Please enter the 6-digit authenticator code.",
                );
                return;
              }

              setDialogState(() {
                isDialogLoading = true;
              });

              try {
                if (_is2FAEnabled && _verifiedFactorId != null) {
                  await _settingsRepository.challengeAndVerify(
                    factorId: _verifiedFactorId!,
                    code: otpController.text,
                  );
                }

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                _executeAccountDeletion();
              } catch (e) {
                setDialogState(() {
                  isDialogLoading = false;
                });
                if (ctx.mounted) {
                  CustomSnackbar.showError(
                    ctx,
                    "Verification failed. Invalid code.",
                  );
                }
              }
            };

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
                      onChanged: (val) {
                        setDialogState(() {});
                      },
                    ),

                    if (_is2FAEnabled) ...[
                      const SizedBox(height: 24),
                      const Text(
                        "Authenticator Code:",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Pinput(
                        length: 6,
                        controller: otpController,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        defaultPinTheme: PinTheme(
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
                        ),
                        focusedPinTheme: PinTheme(
                          width: 36,
                          height: 46,
                          textStyle: const TextStyle(
                            fontSize: 18,
                            color: AppColors.textDark,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red, width: 2),
                          ),
                        ),
                        onCompleted: (pin) {
                          if (canDelete && _activePinSubmit != null) {
                            _activePinSubmit!();
                          }
                        },
                        onChanged: (val) {
                          setDialogState(() {});
                        },
                      ),
                    ],
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
                      (canDelete && !isDialogLoading)
                          ? () {
                            if (_activePinSubmit != null) {
                              _activePinSubmit!();
                            }
                          }
                          : null,
                  child:
                      isDialogLoading
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.red,
                            ),
                          )
                          : Text(
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

    _activePinController = null;
    _activePinSubmit = null;
  }

  Future<void> _executeAccountDeletion() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _settingsRepository.deleteAccount();

      if (mounted) {
        context.go(AppRoutes.login);
        CustomSnackbar.showSuccess(context, "Account deleted successfully.");
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(
          context,
          "Account deletion failed: ${e.toString()}",
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    secondary: Container(
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
                            ? Row(
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
                                const Text(
                                  "Updating security setting...",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textLight,
                                  ),
                                ),
                              ],
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
                    value: _is2FAEnabled,
                    activeColor: AppColors.primaryGreen,
                    onChanged: _is2FAToggleBusy ? null : _handleTwoFactorToggle,
                  ),
                ),

                if (_is2FAEnabled)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4),
                    child: _buildSettingsTile(
                      context,
                      icon: Icons.key_off_outlined,
                      title:
                          _hasRecoveryCodes
                              ? "Regenerate Recovery Codes"
                              : "Generate Recovery Codes",
                      subtitle:
                          _hasRecoveryCodes
                              ? "You have active backup codes"
                              : "Get backup codes for account recovery",
                      onTap: _handleRecoveryCodesTap,
                    ),
                  ),

                _buildSettingsTile(
                  context,
                  icon: Icons.delete_forever,
                  title: "Delete Account",
                  isDestructive: true,
                  onTap: () => _showDeleteConfirmation(context),
                ),
                const SizedBox(height: 32),

                _buildSectionHeader("Preferences"),
                _buildSettingsTile(
                  context,
                  icon: Icons.notifications_none,
                  title: "Notifications",
                  onTap:
                      () => CustomSnackbar.showInfo(
                        context,
                        "Notifications: Coming Soon",
                      ),
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
                              Text("Appearance", style: AppTextStyles.h3),
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
                    setState(() {});
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
}
