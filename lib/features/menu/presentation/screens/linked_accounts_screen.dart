import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show UserIdentity;
import 'package:pinput/pinput.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';
import '../../../../presentation/widgets/auth_text_field.dart';
import '../../../../core/utils/security_formatters.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/data/security_gate_service.dart';
import '../../data/settings_repository.dart';

class LinkedAccountsScreen extends StatefulWidget {
  const LinkedAccountsScreen({super.key});

  @override
  State<LinkedAccountsScreen> createState() => _LinkedAccountsScreenState();
}

class _LinkedAccountsScreenState extends State<LinkedAccountsScreen> {
  bool _isLoading = false;
  List<UserIdentity> _identities = [];
  final AuthRepository _authRepository = AuthRepository();
  late final SettingsRepository _settingsRepository = SettingsRepository(
    authRepository: _authRepository,
  );
  late final SecurityGateService _securityGateService = SecurityGateService(
    authProvider: AuthRepositorySecurityProvider(_authRepository),
  );

  @override
  void initState() {
    super.initState();
    _fetchIdentities(withLoading: true);
  }

  Future<void> _fetchIdentities({bool withLoading = false}) async {
    if (withLoading && mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      await _settingsRepository.refreshSession();
      final user = _settingsRepository.currentUser;
      if (mounted) {
        setState(() {
          _identities = user?.identities ?? [];
        });
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(
          context,
          "Failed to refresh linked accounts: $e",
        );
      }
    } finally {
      if (withLoading && mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _enforceAAL2() async {
    final gateDecision = _securityGateService.evaluateAal2Gate();
    if (gateDecision.isAllowed) {
      return true;
    }
    if (gateDecision.isUnauthenticated) {
      return false;
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
              setDialogState(() {
                isDialogLoading = true;
              });
              try {
                if (isRecoveryMode) {
                  final rpcSuccess = await _securityGateService
                      .verifyWithRecoveryCode(code);
                  if (rpcSuccess != true) {
                    throw "Invalid backup code.";
                  }
                  if (ctx.mounted) {
                    CustomSnackbar.showSuccess(
                      ctx,
                      "Account recovered! 2FA has been temporarily disabled.",
                    );
                  }
                } else {
                  await _securityGateService.verifyWithTotp(code);
                }

                success = true;
                if (ctx.mounted) {
                  Navigator.pop(ctx);
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
                          ? "Enter an 8-character backup code to bypass and disable 2FA."
                          : "To make security changes to your account, please verify your identity with your 6-digit authenticator code.",
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
                        // SECURITY FIXES:
                        onClipboardFound: null, // Disables auto-paste popup
                        autofillHints: null, // Disables OS autofill suggestions
                        enableInteractiveSelection:
                            false, // Disables manual paste context menu
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
                        onCompleted: submitCode, // Keeps automatic submit
                      ),
                      secondChild: TextField(
                        controller: recoveryController,
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.characters,
                        enableInteractiveSelection:
                            false, // Disables paste for backup codes
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
                          : () {
                            setDialogState(() {
                              isRecoveryMode = !isRecoveryMode;
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
    return success;
  }

  Future<void> _linkGoogle() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await _settingsRepository.linkGoogleIdentity(
        redirectTo: 'io.supabase.daktarpi://login-callback',
      );

      await _settingsRepository.refreshSession();

      if (!mounted) {
        return;
      }
      await _fetchIdentities();
      if (!mounted) {
        return;
      }
      CustomSnackbar.showSuccess(
        context,
        "Google account linked successfully!",
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      CustomSnackbar.showError(context, "Failed to link Google: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _linkEmail() async {
    final passed2FA = await _enforceAAL2();
    if (!passed2FA) {
      return;
    }

    if (!mounted) {
      return;
    }

    final passwordController = TextEditingController();
    bool isDialogLoading = false;

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
                  Icon(Icons.email, color: AppColors.primaryGreen),
                  SizedBox(width: 10),
                  Text("Link Email Account"),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "To link your email address, please set a secure password for this account.",
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textLight,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  AuthTextField(
                    controller: passwordController,
                    hintText: "Set a Password",
                    isPassword: true,
                  ),
                ],
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
                          : () async {
                            if (passwordController.text.length < 6) {
                              CustomSnackbar.showError(
                                ctx,
                                "Password must be at least 6 characters.",
                              );
                              return;
                            }

                            setDialogState(() {
                              isDialogLoading = true;
                            });

                            try {
                              await _settingsRepository.updatePassword(
                                passwordController.text,
                              );

                              await _settingsRepository.refreshSession();

                              if (!ctx.mounted) {
                                return;
                              }
                              Navigator.pop(ctx);

                              await _fetchIdentities();

                              if (!mounted) {
                                return;
                              }
                              CustomSnackbar.showSuccess(
                                context,
                                "Email account linked successfully!",
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
                                "Failed to link email: $e",
                              );
                            }
                          },
                  child:
                      isDialogLoading
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text(
                            "Link Account",
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

  Future<void> _unlinkIdentity(UserIdentity identity) async {
    final passed2FA = await _enforceAAL2();
    if (!passed2FA) {
      return;
    }

    if (!mounted) {
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(Icons.link_off, color: Colors.red),
                SizedBox(width: 10),
                Text("Unlink Account?"),
              ],
            ),
            content: Text(
              "Are you sure you want to unlink ${identity.provider}? You won't be able to sign in with this account anymore.",
              style: const TextStyle(height: 1.4, color: AppColors.textDark),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  "Cancel",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  "Unlink",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
    );

    if (confirm != true) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _settingsRepository.unlinkIdentity(identity);
      await _settingsRepository.refreshSession();

      if (!mounted) {
        return;
      }
      CustomSnackbar.showSuccess(context, "Account unlinked successfully");
      _fetchIdentities();
    } catch (e) {
      if (!mounted) {
        return;
      }
      CustomSnackbar.showError(context, "Failed to unlink: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildProviderTile(String provider, String iconPath, Color color) {
    UserIdentity? identity;
    try {
      identity = _identities.firstWhere(
        (id) => (id.provider).toLowerCase() == provider,
      );
    } catch (_) {
      identity = null;
    }

    final isLinked = identity != null;
    final isOnlyIdentity = _identities.length <= 1 && isLinked;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              provider == 'google' ? Icons.g_mobiledata : Icons.email,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  provider.isNotEmpty
                      ? provider[0].toUpperCase() + provider.substring(1)
                      : '',
                  style: AppTextStyles.bodyBold,
                ),
                if (isLinked)
                  Text(
                    provider == 'email'
                        ? (_settingsRepository.currentUserEmail ?? 'Linked')
                        : 'Linked',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (isLinked)
            if (isOnlyIdentity)
              TextButton(
                onPressed: () {
                  CustomSnackbar.showInfo(
                    context,
                    "You must link another account before you can unlink this one.",
                  );
                },
                child: const Text(
                  "Unlink",
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              TextButton(
                onPressed: () => _unlinkIdentity(identity!),
                child: const Text(
                  "Unlink",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
          else
            TextButton(
              onPressed: provider == 'google' ? _linkGoogle : _linkEmail,
              child: const Text(
                "Link",
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text("Linked Accounts", style: AppTextStyles.h2),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textDark,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: AppColors.primaryGreen),
              )
              : ListView(
                padding: const EdgeInsets.all(24.0),
                children: [
                  const Text(
                    "Manage your signed-in accounts. Linking accounts allows you to sign in with any of them.",
                    style: TextStyle(color: AppColors.textLight, height: 1.5),
                  ),
                  const SizedBox(height: 32),
                  _buildProviderTile(
                    'email',
                    'assets/icons/email.svg',
                    AppColors.primaryGreen,
                  ),
                  _buildProviderTile(
                    'google',
                    'assets/icons/google.svg',
                    Colors.red,
                  ),
                ],
              ),
    );
  }
}
