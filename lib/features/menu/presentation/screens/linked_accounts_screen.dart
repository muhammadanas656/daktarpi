import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pinput/pinput.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';
import '../../../../presentation/widgets/auth_text_field.dart';
import '../../../../core/utils/security_formatters.dart';
import '../../../../core/security/sensitive_action_step_up_service.dart';
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
  final Map<String, bool> _expandedTiles = {};

  final AuthRepository _authRepository = AuthRepository();
  late final SettingsRepository _settingsRepository = SettingsRepository(
    authRepository: _authRepository,
  );
  late final SecurityGateService _securityGateService = SecurityGateService(
    authProvider: AuthRepositorySecurityProvider(_authRepository),
  );

  final SensitiveActionStepUpService _stepUpService =
      SensitiveActionStepUpService();

  @override
  void initState() {
    super.initState();
    final user = _settingsRepository.currentUser;
    _identities = user?.identities ?? [];
    _fetchIdentities(withLoading: _identities.isEmpty);
  }

  Future<void> _fetchIdentities({bool withLoading = false}) async {
    if (withLoading && mounted) {
      setState(() => _isLoading = true);
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
      if (mounted && withLoading) {
        CustomSnackbar.showError(context, "Failed to refresh linked accounts.");
      }
    } finally {
      if (withLoading && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _enforceAAL2(String localizedReason) async {
    final gateDecision = _securityGateService.evaluateAal2Gate();
    if (gateDecision.isAllowed) return true;
    if (gateDecision.isUnauthenticated) return false;

    final biometricSuccess = await _stepUpService.authenticateIfTrusted(
      localizedReason: localizedReason,
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
                  final rpcSuccess = await _securityGateService
                      .verifyWithRecoveryCode(code);
                  if (rpcSuccess != true) throw "Invalid backup code.";
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
                        onCompleted: submitCode,
                      ),
                      secondChild: TextField(
                        controller: recoveryController,
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [BackupCodeFormatter()],
                        textAlign: TextAlign.center,
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
    setState(() => _isLoading = true);
    try {
      await _settingsRepository.linkGoogleIdentity(
        redirectTo: 'io.supabase.daktarpi://login-callback',
      );
      await _settingsRepository.refreshSession();

      if (!mounted) return;
      await _fetchIdentities();
      if (!mounted) return;
      CustomSnackbar.showSuccess(
        context,
        "Google account linked successfully!",
      );
    } catch (e) {
      if (!mounted) return;
      CustomSnackbar.showError(context, "Failed to link Google: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _linkEmail() async {
    final passedSecurity = await _enforceAAL2('Verify identity to link Email');
    if (!passedSecurity || !mounted) return;

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

                            setDialogState(() => isDialogLoading = true);

                            try {
                              try {
                                await _settingsRepository.updatePassword(
                                  passwordController.text,
                                );
                                await Supabase.instance.client.auth.updateUser(
                                  UserAttributes(
                                    data: {'has_email_password': true},
                                  ),
                                );
                              } catch (e) {
                                if (e.toString().toLowerCase().contains(
                                  'authentication failed',
                                )) {
                                  await Supabase.instance.client.auth
                                      .updateUser(
                                        UserAttributes(
                                          data: {'has_email_password': true},
                                        ),
                                      );
                                } else {
                                  rethrow;
                                }
                              }

                              await _settingsRepository.refreshSession();
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);

                              await _fetchIdentities();
                              if (!mounted) return;

                              CustomSnackbar.showSuccess(
                                context,
                                "Email account linked successfully!",
                              );
                            } catch (e) {
                              setDialogState(() => isDialogLoading = false);
                              if (!ctx.mounted) return;
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

  // STANDARD UNLINK (For explicit identities like Google)
  Future<void> _unlinkIdentity(UserIdentity identity) async {
    final passedSecurity = await _enforceAAL2(
      'Verify identity to unlink ${identity.provider}',
    );
    if (!passedSecurity || !mounted) return;

    final providerName =
        identity.provider[0].toUpperCase() + identity.provider.substring(1);

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                const Icon(Icons.link_off, color: Colors.red),
                const SizedBox(width: 10),
                Text("Unlink $providerName?"),
              ],
            ),
            content: Text(
              "Are you sure you want to unlink your $providerName account? You won't be able to sign in with this method anymore.",
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

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      await _settingsRepository.unlinkIdentity(identity);
      await _settingsRepository.refreshSession();

      if (!mounted) return;
      CustomSnackbar.showSuccess(
        context,
        "$providerName account unlinked successfully.",
      );
      _fetchIdentities();
    } catch (e) {
      if (!mounted) return;

      final errorStr = e.toString().toLowerCase();
      // Catch Supabase rejecting the deletion of a Primary Identity
      if (errorStr.contains('primary identity') ||
          errorStr.contains('authentication failed') ||
          errorStr.contains('auth_exception')) {
        CustomSnackbar.showError(
          context,
          "You cannot unlink the account you originally used to sign up.",
        );
      } else {
        CustomSnackbar.showError(context, "Failed to unlink $providerName: $e");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // PSEUDO-UNLINK (For implicitly added passwords/email)
  Future<void> _unlinkImplicitEmail() async {
    final passedSecurity = await _enforceAAL2(
      'Verify identity to unlink Email',
    );
    if (!passedSecurity || !mounted) return;

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
                Text("Unlink Email?"),
              ],
            ),
            content: const Text(
              "Are you sure you want to unlink your Email/Password account? You won't be able to sign in with this method anymore.",
              style: TextStyle(height: 1.4, color: AppColors.textDark),
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

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'has_email_password': false}),
      );
      await _settingsRepository.refreshSession();
      if (!mounted) return;
      CustomSnackbar.showSuccess(
        context,
        "Email account unlinked successfully.",
      );
      _fetchIdentities();
    } catch (e) {
      if (!mounted) return;
      CustomSnackbar.showError(context, "Failed to unlink Email: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildProviderTile(String provider, String iconPath, Color color) {
    final user = _settingsRepository.currentUser;
    final providersList = List<String>.from(
      user?.appMetadata['providers'] ?? [],
    );
    final hasEmailMetadata = user?.userMetadata?['has_email_password'] == true;

    // 1. Calculate the TRUE total of linked providers
    Set<String> allLinkedProviders = {...providersList};
    for (var id in _identities) {
      allLinkedProviders.add(id.provider);
    }
    if (hasEmailMetadata) {
      allLinkedProviders.add('email');
    }

    final int totalLinkedCount = allLinkedProviders.length;

    // 2. Identify the Primary Provider (the original account creation method)
    String primaryProvider =
        user?.appMetadata['provider']?.toString().toLowerCase() ?? '';
    if (primaryProvider.isEmpty && _identities.isNotEmpty) {
      // Fallback: the oldest identity is the primary one
      var oldest = _identities.first;
      for (var id in _identities) {
        final idDate = DateTime.tryParse(id.createdAt ?? '') ?? DateTime.now();
        final oldestDate =
            DateTime.tryParse(oldest.createdAt ?? '') ?? DateTime.now();

        if (idDate.isBefore(oldestDate)) {
          oldest = id;
        }
      }
      primaryProvider = oldest.provider.toLowerCase();
    }

    UserIdentity? identity;
    try {
      identity = _identities.firstWhere(
        (id) => (id.provider).toLowerCase() == provider,
      );
    } catch (_) {
      identity = null;
    }

    // Evaluate link status and primary status
    final isLinked = allLinkedProviders.contains(provider);
    final isPrimary = (primaryProvider == provider);
    final isOnlyIdentity = (totalLinkedCount <= 1) && isLinked;

    // Logic for the expanding drawer
    final identityEmail = identity?.identityData?['email']?.toString();
    final canExpand = isLinked && identityEmail != null && provider != 'email';
    final isExpanded = _expandedTiles[provider] ?? false;

    return GestureDetector(
      onTap:
          canExpand
              ? () {
                setState(() {
                  _expandedTiles[provider] = !isExpanded;
                });
              }
              : null,
      child: AnimatedContainer(
        duration: AppMotion.fast,
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
          border:
              isExpanded
                  ? Border.all(color: color.withValues(alpha: 0.3), width: 1)
                  : Border.all(color: Colors.transparent, width: 1),
        ),
        child: Column(
          children: [
            Row(
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
                      Row(
                        children: [
                          Text(
                            provider.isNotEmpty
                                ? provider[0].toUpperCase() +
                                    provider.substring(1)
                                : '',
                            style: AppTextStyles.bodyBold,
                          ),
                          if (canExpand) ...[
                            const SizedBox(width: 6),
                            AnimatedRotation(
                              turns: isExpanded ? 0.5 : 0.0,
                              duration: AppMotion.fast,
                              child: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 18,
                                color: AppColors.textLight,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (isLinked)
                        Text(
                          provider == 'email'
                              ? (_settingsRepository.currentUserEmail ??
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
                  if (isPrimary || isOnlyIdentity)
                    // --- THE FIX: Primary accounts get NO BUTTON ---
                    const SizedBox.shrink()
                  else
                    // Secondary accounts get the Unlink button
                    TextButton(
                      onPressed: () {
                        if (identity != null) {
                          _unlinkIdentity(identity);
                        } else if (provider == 'email') {
                          _unlinkImplicitEmail();
                        }
                      },
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

            AnimatedSize(
              duration: AppMotion.fast,
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child:
                  isExpanded
                      ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.only(top: 12, left: 56),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.subdirectory_arrow_right_rounded,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "$identityEmail",
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textLight,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )
                      : const SizedBox.shrink(),
            ),
          ],
        ),
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
