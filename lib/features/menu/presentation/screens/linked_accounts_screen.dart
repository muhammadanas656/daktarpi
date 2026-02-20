import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pinput/pinput.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';
import '../../../../presentation/widgets/auth_text_field.dart';

class LinkedAccountsScreen extends StatefulWidget {
  const LinkedAccountsScreen({super.key});

  @override
  State<LinkedAccountsScreen> createState() => _LinkedAccountsScreenState();
}

class _LinkedAccountsScreenState extends State<LinkedAccountsScreen> {
  bool _isLoading = false;
  List<UserIdentity> _identities = [];

  @override
  void initState() {
    super.initState();
    _fetchIdentities();
  }

  Future<void> _fetchIdentities() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      if (mounted) {
        setState(() {
          _identities = user.identities ?? [];
        });
      }
    }
  }

  Future<bool> _enforceAAL2() async {
    final user = Supabase.instance.client.auth.currentUser;
    final is2FAEnabled = user?.appMetadata['is_2fa_enabled'] == true;
    final currentAal = user?.appMetadata['aal'];

    if (!is2FAEnabled || currentAal == 'aal2') {
      return true;
    }

    bool success = false;
    final otpController = TextEditingController();
    final recoveryController = TextEditingController();
    bool isDialogLoading = false;
    bool isRecoveryMode = false;

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
                  final rpcSuccess = await Supabase.instance.client.rpc(
                    'use_recovery_code',
                    params: {'input_code': code},
                  );
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
                  final factors =
                      await Supabase.instance.client.auth.mfa.listFactors();
                  final verifiedFactor = factors.totp.firstWhere(
                    (f) => f.status == FactorStatus.verified,
                  );
                  await Supabase.instance.client.auth.mfa.challengeAndVerify(
                    factorId: verifiedFactor.id,
                    code: code,
                  );
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
                        ], // Digits only
                        onCompleted: submitCode,
                      ),
                      secondChild: TextField(
                        controller: recoveryController,
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

    if (success) {
      await Supabase.instance.client.auth.refreshSession();
    }
    return success;
  }

  Future<void> _linkGoogle() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await Supabase.instance.client.auth.linkIdentity(
        OAuthProvider.google,
        redirectTo: 'io.supabase.daktarpi://login-callback',
      );

      await Supabase.instance.client.auth.refreshSession();

      if (!mounted) {
        return;
      }
      _fetchIdentities();
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
                              await Supabase.instance.client.auth.updateUser(
                                UserAttributes(
                                  password: passwordController.text,
                                ),
                              );

                              await Supabase.instance.client.auth
                                  .refreshSession();

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
      await Supabase.instance.client.auth.unlinkIdentity(identity);
      await Supabase.instance.client.auth.refreshSession();

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
      identity = _identities.firstWhere((id) => id.provider == provider);
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
              children: [
                Text(
                  provider[0].toUpperCase() + provider.substring(1),
                  style: AppTextStyles.bodyBold,
                ),
                if (isLinked)
                  Text(
                    provider == 'email'
                        ? (Supabase.instance.client.auth.currentUser?.email ??
                            'Linked')
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
              : Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
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
              ),
    );
  }
}

// --- NEW MAGIC AUTO-FORMATTER CLASS ---
class BackupCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String cleanText = newValue.text.toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );
    if (cleanText.length > 8) {
      cleanText = cleanText.substring(0, 8);
    }
    String formattedText = cleanText;
    if (cleanText.length > 4) {
      formattedText = '${cleanText.substring(0, 4)}-${cleanText.substring(4)}';
    }
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}
