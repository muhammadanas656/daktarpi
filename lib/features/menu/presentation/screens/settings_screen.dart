import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_routes.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';
import '../../../profile/presentation/profile_notifier.dart';
import '../../../../presentation/widgets/auth_text_field.dart'; // Reusing AuthTextField for consistent style
import '../../../settings/presentation/settings_notifier.dart';
import '../../../../core/localization/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = false;
  bool _is2FAEnabled = false;

  @override
  void initState() {
    super.initState();
    // Ensure settings are loaded when entering screen
    SettingsNotifier.instance.loadSettings();
    _check2FAStatus();
  }

  String? _verifiedFactorId;

  bool _hasRecoveryCodes = false;

  Future<void> _check2FAStatus() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final factors = await Supabase.instance.client.auth.mfa.listFactors();
      
      // Check for recovery codes (RPC)
      bool hasCodes = false;
      try {
        hasCodes = await Supabase.instance.client.rpc('user_has_recovery_codes');
      } catch (_) {
         // RPC might not exist yet or error, default to false
      }

      if (mounted) {
        setState(() {
          // Check if we have a verified factor AND if the flag (app_metadata) is set
          final totpFactors = factors.totp;
          final hasFactor = totpFactors.isNotEmpty;
          final isEnabledInMetadata = user?.appMetadata['is_2fa_enabled'] == true;
          
          _is2FAEnabled = hasFactor && isEnabledInMetadata;
          _hasRecoveryCodes = hasCodes;
          
          if (hasFactor) {
            // Store the ID of the first verified factor (or just the first one if we assume single factor support)
            // Ideally we check for status == verified, but listFactors returns all.
            final verifiedFactor = totpFactors.firstWhere(
              (f) => f.status == FactorStatus.verified,
              orElse: () => totpFactors.first, // Fallback
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

  Future<void> _toggle2FA(bool value) async {
    // If turning ON
    if (value) {
      setState(() => _isLoading = true);
      try {
        final factors = await Supabase.instance.client.auth.mfa.listFactors();
        
        // 2. Check for VERIFIED factor (State recovery)
        if (factors.totp.isNotEmpty) {
           if (mounted) CustomSnackbar.showInfo(context, "2FA is already enrolled.");
           await _check2FAStatus(); // Refresh status
           return;
        }

        // 3. Cleanup UNVERIFIED factors (Prevent "already exists" error)
        final unverifiedTotp = factors.all.where((f) => 
          f.factorType == FactorType.totp && f.status != FactorStatus.verified
        ).toList();

        for (final factor in unverifiedTotp) {
          await Supabase.instance.client.auth.mfa.unenroll(factor.id);
        }

        // 4. Enroll
        // Note: The backend trigger (Smart Sync) will set app_metadata['is_2fa_enabled'] = true
        await _setup2FA();

      } catch (e) {
        if (mounted) CustomSnackbar.showError(context, "Error toggling 2FA: $e");
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      // Turning OFF
      // Just unenroll the factor. The Smart Sync trigger handles the flag update.
      if (_verifiedFactorId != null) {
         await _disable2FA(_verifiedFactorId!);
      } else {
         // Should not happen if UI is correct, but safe fallback
         CustomSnackbar.showError(context, "No active 2FA factor found to disable.");
         await _check2FAStatus();
      }
    }
  }

  Future<void> _disable2FA(String factorId) async {
     setState(() => _isLoading = true);
     try {
       // Deleting the factor triggers the backend to update app_metadata
       await Supabase.instance.client.auth.mfa.unenroll(factorId);

       await _check2FAStatus();
       if (mounted) {
         CustomSnackbar.showSuccess(context, "2FA Disabled");
       }
     } catch (e) {
       if (mounted) CustomSnackbar.showError(context, "Failed to disable 2FA: $e");
     } finally {
       if (mounted) setState(() => _isLoading = false);
     }
  }

  // --- CHANGE PASSWORD LOGIC ---
  Future<void> _showChangePasswordDialog() async {
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    bool isDialogLoading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                "Change Password",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isDialogLoading ? null : () => Navigator.pop(dialogCtx),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                TextButton(
                  onPressed: isDialogLoading
                      ? null
                      : () async {
                          final newPass = newPassController.text.trim();
                          final confirmPass = confirmPassController.text.trim();

                          if (newPass.length < 6) {
                            // Use dialogCtx for Snackbar within dialog if possible, or parent context
                            // But usually best to use parent context for SnackBar
                            CustomSnackbar.showError(context, "Password must be at least 6 characters");
                            return;
                          }
                          if (newPass != confirmPass) {
                            CustomSnackbar.showError(context, "Passwords do not match");
                            return;
                          }

                          setDialogState(() => isDialogLoading = true);

                          try {
                            await Supabase.instance.client.auth.updateUser(
                              UserAttributes(password: newPass),
                            );
                            if (mounted) {
                              // ignore: use_build_context_synchronously
                              Navigator.pop(dialogCtx); // Close dialog
                              // ignore: use_build_context_synchronously
                              CustomSnackbar.showSuccess(
                                  context, "Password updated successfully!");
                            }
                          } on AuthException catch (e) {
                             if (mounted) CustomSnackbar.showError(context, e.message);
                          } catch (e) {
                             if (mounted) CustomSnackbar.showError(context, "Failed to update password");
                          } finally {
                            // Check if dialog is still mounted before setting state
                            // Difficult to check 'dialogCtx.mounted' directly safely in some versions
                            // But we closed it in success case.
                            // Only set state if we didn't close it (failure case)
                            if (isDialogLoading && mounted) {
                               setDialogState(() => isDialogLoading = false);
                            }
                          }
                        },
                  child: isDialogLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
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

  // --- DELETE ACCOUNT LOGIC ---
  Future<void> _showDeleteConfirmation(BuildContext context) async {
    final confirmController = TextEditingController();
    
    await showDialog(
      context: context,
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
                   Text("Delete Account", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
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
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmController,
                    decoration: InputDecoration(
                      hintText: "DELETE",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    onChanged: (val) {
                      setDialogState(() {});
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: canDelete
                      ? () {
                          Navigator.pop(ctx);
                          _executeAccountDeletion();
                        }
                      : null, // Disabled until matches
                  child: Text(
                    "Delete",
                    style: TextStyle(
                      color: canDelete ? Colors.red : Colors.red.withValues(alpha: 0.5),
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
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw "No active session";

      // 1. DELETE STORAGE FILES (Client-side)
      // Note: This relies on Policies allowing user to list/delete own files
      try {
        final List<FileObject> objects = await Supabase.instance.client.storage
            .from('medical_docs')
            .list(path: user.id);
        
        if (objects.isNotEmpty) {
           final List<String> paths = objects.map((e) => '${user.id}/${e.name}').toList();
           await Supabase.instance.client.storage
             .from('medical_docs')
             .remove(paths);
        }
      } catch (e) {
        debugPrint("Storage cleanup error (continuing): $e");
      }

      // 2. TRIGGER DB DELETION (RPC)
      await Supabase.instance.client.rpc('delete_user_account');

      // 3. SIGN OUT LOCALLY
      await Supabase.instance.client.auth.signOut();

      // 4. NAVIGATE TO LOGIN
      if (mounted) {
        context.go(AppRoutes.login);
        CustomSnackbar.showSuccess(context, "Account deleted successfully.");
      }

    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, "Account deletion failed: ${e.toString()}");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- 2FA ENROLLMENT LOGIC ---
  Future<void> _setup2FA() async {
    try {
      setState(() => _isLoading = true);
      final response = await Supabase.instance.client.auth.mfa.enroll(
        factorType: FactorType.totp,
        issuer: 'DaktarPi',
        friendlyName: 'DaktarPi (${Supabase.instance.client.auth.currentUser?.email})',
      );
      final factorId = response.id;
      final totp = response.totp;
      if (totp == null) {
         throw "TOTP data not returned from Supabase";
      }
      final qrCode = totp.qrCode;
      final secret = totp.secret;

      if (!mounted) return;

      // Show Dialog with QR Code and Verify Input
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) {
          final codeController = TextEditingController();
          bool isVerifying = false;
          String? errorMsg;

          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              return AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Text("Enable 2FA", style: TextStyle(fontWeight: FontWeight.bold)),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Scan this QR code with your authenticator app:",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      // SVG Display
                      SizedBox(
                        height: 200,
                        width: 200,
                        child: SvgPicture.string(qrCode),
                      ),
                      const SizedBox(height: 16),
                      SelectableText(
                        "Secret: $secret", 
                        style: const TextStyle(fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        "Enter the 6-digit code to verify:",
                        style: TextStyle(fontSize: 14, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: codeController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 6,
                        style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 4),
                         decoration: InputDecoration(
                           hintText: "000000",
                           counterText: "",
                           errorText: errorMsg,
                           border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                           contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                         ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isVerifying ? null : () => Navigator.pop(dialogCtx),
                    child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                  ),
                  TextButton(
                    onPressed: isVerifying 
                      ? null 
                      : () async {
                        final code = codeController.text.trim();
                        if (code.length != 6) {
                          setDialogState(() => errorMsg = "Invalid code");
                          return;
                        }
                        
                        setDialogState(() {
                          isVerifying = true;
                          errorMsg = null;
                        });

                        try {
                          // 1. Verify Code
                          await Supabase.instance.client.auth.mfa.challengeAndVerify(
                            factorId: factorId, 
                            code: code
                          );
                          
                          // 2. Update Metadata (Handled by Backend Trigger on verification)
                          // await Supabase.instance.client.auth.updateUser(...) -> REMOVED
                          
                          // 3. Pop Dialog
                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);
                          }

                          // 4. Show Success & Refresh (using parent context)
                          if (mounted) {
                            CustomSnackbar.showSuccess(context, "2FA Enabled Successfully!");
                            // Wait a moment for trigger to fire/propagate if needed, mostly redundant but safe
                            await Future.delayed(const Duration(milliseconds: 500));
                            // Refresh Token to get new claims (app_metadata)
                            await Supabase.instance.client.auth.refreshSession();
                            _check2FAStatus();
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            setDialogState(() {
                               isVerifying = false;
                               errorMsg = "Verification failed";
                            });
                          }
                        }
                      },
                    child: isVerifying 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                      : const Text("Verify & Enable", style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
                  ),
                ],
              );
            }
          );
        }
      );

    } catch (e) {
      if (mounted) CustomSnackbar.showError(context, "Failed to start 2FA enrollment: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- RECOVERY CODES LOGIC ---
  List<String> _generateLocalCodes() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    return List.generate(
      10,
      (_) =>
          '${List.generate(4, (_) => chars[rnd.nextInt(chars.length)]).join()}-'
          '${List.generate(4, (_) => chars[rnd.nextInt(chars.length)]).join()}',
    );
  }

  void _handleRecoveryCodesTap() {
    if (_hasRecoveryCodes) {
      _showRegenerateConfirmation();
    } else {
      _generateAndShowCodes();
    }
  }

  Future<void> _showRegenerateConfirmation() async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Regenerate Codes?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          "This will invalidate your existing backup codes. Any saved codes you have will no longer work.\n\nAre you sure you want to generate new ones?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
             onPressed: () {
               Navigator.pop(ctx);
               _generateAndShowCodes();
             },
             child: const Text("Regenerate", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Future<void> _generateAndShowCodes() async {
    // 1. Generate & Save Logic
    setState(() => _isLoading = true);
    List<String> codes = [];
    try {
      codes = _generateLocalCodes();
      // Save to Supabase (Hash them server-side via RPC)
      await Supabase.instance.client.rpc('save_recovery_codes', params: {
        'codes': codes,
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) CustomSnackbar.showError(context, "Failed to generate codes: $e");
      return;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
    
    if (!mounted) return;

    // 2. Show Enhanced Dialog
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isCheckboxChecked = false;
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                   Icon(Icons.lock_person_outlined, color: AppColors.primaryGreen),
                   SizedBox(width: 10),
                   Text("Save Backup Codes", style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Warning Banner
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                             SizedBox(width: 8),
                             Expanded(
                               child: Text(
                                 "Keep these safe! If you lose your phone, these codes are the ONLY way to access your DaktarPi account.",
                                 style: TextStyle(fontSize: 12, color: AppColors.textDark, height: 1.4),
                               ),
                             ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Grid of Codes
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
                          children: codes.map((code) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                             decoration: BoxDecoration(
                               color: Colors.white,
                               borderRadius: BorderRadius.circular(8),
                               border: Border.all(color: Colors.grey[300]!),
                             ),
                             child: Text(
                               code,
                               style: const TextStyle(
                                 fontFamily: 'monospace',
                                 fontWeight: FontWeight.bold,
                                 fontSize: 14,
                                 letterSpacing: 1.0,
                                 color: AppColors.textDark,
                               ),
                             ),
                          )).toList(),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: codes.join('\n')));
                                CustomSnackbar.showSuccess(context, "Codes copied to clipboard");
                              },
                              icon: const Icon(Icons.copy, size: 18),
                              label: const Text("Copy Codes"),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryGreen,
                                side: const BorderSide(color: AppColors.primaryGreen),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                CustomSnackbar.showInfo(context, "Save to File: Coming Soon");
                                // Implement saving to file logic here if needed
                              },
                              icon: const Icon(Icons.download, size: 18),
                              label: const Text("Save as .txt"),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textDark,
                                side: const BorderSide(color: Colors.grey),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      Divider(color: Colors.grey[200]),
                      const SizedBox(height: 8),

                      // Gatekeeper Checkbox
                      CheckboxListTile(
                        value: isCheckboxChecked,
                        onChanged: (val) {
                          setDialogState(() => isCheckboxChecked = val == true);
                        },
                        title: const Text(
                          "I have securely saved these codes.",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
                  onPressed: isCheckboxChecked 
                    ? () => Navigator.pop(ctx)
                    : null, // Disabled until checked
                  child: Text(
                    "Done",
                    style: TextStyle(
                      color: isCheckboxChecked ? AppColors.primaryGreen : Colors.grey,
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
    
    // Refresh status after dialog closes
    if (mounted) await _check2FAStatus();
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
                // --- SECTION 1: ACCOUNT & SECURITY ---
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
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  secondary: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.security, color: AppColors.primaryGreen, size: 20),
                  ),
                  title: const Text(
                    "Two-Factor Authentication",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textDark,
                    ),
                  ),
                  value: _is2FAEnabled,
                  activeColor: AppColors.primaryGreen,
                  onChanged: _toggle2FA,
                ),
                if (_is2FAEnabled)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4),
                    child: _buildSettingsTile(
                      context,
                      icon: Icons.key_off_outlined,
                      title: _hasRecoveryCodes ? "Regenerate Recovery Codes" : "Generate Recovery Codes",
                      subtitle: _hasRecoveryCodes 
                          ? "You have active backup codes" 
                          : "Get backup codes for account recovery",
                      onTap: _handleRecoveryCodesTap,
                    ),
                  ),
                _buildSettingsTile(
                  context,
                  icon: Icons.delete_forever,
                  title: AppLocalizations.of(context).translate('delete'),
                  isDestructive: true,
                  onTap: () => _showDeleteConfirmation(context),
                ),
                const SizedBox(height: 32),

                // --- SECTION 2: PREFERENCES ---
                _buildSectionHeader(AppLocalizations.of(context).translate('settings_preferences')),
                _buildSettingsTile(
                  context,
                  icon: Icons.notifications_none,
                  title: AppLocalizations.of(context).translate('tile_notifications'),
                  onTap: () => CustomSnackbar.showInfo(context, "Notifications: Coming Soon"),
                ),
                _buildSettingsTile(
                  context,
                  icon: Icons.language,
                  title: AppLocalizations.of(context).translate('tile_language'),
                  value: _getLanguageName(SettingsNotifier.instance.locale.languageCode),
                  onTap: () async {
                    await showDialog(
                      context: context,
                      builder: (context) => SimpleDialog(
                        title: Text(AppLocalizations.of(context).translate('select_language')),
                        children: [
                          _buildLanguageOption(context, 'en', 'English'),
                          _buildLanguageOption(context, 'bn', 'বাংলা'),
                          _buildLanguageOption(context, 'es', 'Español'),
                          _buildLanguageOption(context, 'fr', 'Français'),
                          _buildLanguageOption(context, 'hi', 'हिन्दी'),
                          _buildLanguageOption(context, 'ar', 'العربية'),
                        ],
                      ),
                    );
                    setState(() {});
                  },
                ),
                _buildSettingsTile(
                  context,
                  icon: Icons.attach_money,
                  title: AppLocalizations.of(context).translate('tile_currency'),
                  value: "${ProfileNotifier.instance.currencySymbol} - ${AppLocalizations.of(context).translate('tile_currency')}",
                  onTap: () => CustomSnackbar.showInfo(context, "Currency is automatic based on location"),
                ),
                _buildSettingsTile(
                  context,
                  icon: Icons.dark_mode_outlined,
                  title: AppLocalizations.of(context).translate('tile_appearance'),
                  value: _getThemeName(SettingsNotifier.instance.themeMode, AppLocalizations.of(context)),
                  onTap: () async {
                     await showModalBottomSheet(
                       context: context,
                       shape: const RoundedRectangleBorder(
                         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                       ),
                       builder: (context) {
                         final loc = AppLocalizations.of(context);
                         return Padding(
                           padding: const EdgeInsets.all(16.0),
                           child: Column(
                             mainAxisSize: MainAxisSize.min,
                             children: [
                               Text(loc.translate('tile_appearance'), style: AppTextStyles.h3),
                               const SizedBox(height: 16),
                               ListTile(
                                 leading: const Icon(Icons.brightness_auto),
                                 title: Text(loc.translate('theme_system')),
                                 trailing: SettingsNotifier.instance.themeMode == ThemeMode.system 
                                     ? const Icon(Icons.check, color: AppColors.primaryGreen) : null,
                                 onTap: () {
                                   SettingsNotifier.instance.updateThemeMode(ThemeMode.system);
                                   Navigator.pop(context);
                                 },
                               ),
                               ListTile(
                                 leading: const Icon(Icons.light_mode),
                                 title: Text(loc.translate('theme_light')),
                                 trailing: SettingsNotifier.instance.themeMode == ThemeMode.light 
                                     ? const Icon(Icons.check, color: AppColors.primaryGreen) : null,
                                 onTap: () {
                                   SettingsNotifier.instance.updateThemeMode(ThemeMode.light);
                                   Navigator.pop(context);
                                 },
                               ),
                               ListTile(
                                 leading: const Icon(Icons.dark_mode),
                                 title: Text(loc.translate('theme_dark')),
                                 trailing: SettingsNotifier.instance.themeMode == ThemeMode.dark 
                                     ? const Icon(Icons.check, color: AppColors.primaryGreen) : null,
                                 onTap: () {
                                   SettingsNotifier.instance.updateThemeMode(ThemeMode.dark);
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      secondary: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.animation, color: AppColors.primaryGreen, size: 20),
                      ),
                      title: const Text(
                        "Menu Drawer Hint",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textDark,
                        ),
                      ),
                      subtitle: const Text("Show animation on startup", style: TextStyle(fontSize: 12, color: AppColors.textLight)),
                      value: SettingsNotifier.instance.showDrawerHint,
                      activeColor: AppColors.primaryGreen,
                      onChanged: (val) {
                         SettingsNotifier.instance.updateShowDrawerHint(val);
                      },
                    );
                  },
                ),
                const SizedBox(height: 32),

                // --- SECTION 3: SUPPORT & LEGAL ---
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
        
        // --- LOADING OVERLAY ---
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
            color: isDestructive
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
        subtitle: subtitle != null
            ? Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textLight))
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  value,
                  style: const TextStyle(fontSize: 14, color: AppColors.textLight),
                ),
              ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }
  // Helper to get display name for language code
  String _getLanguageName(String code) {
    switch (code) {
      case 'en': return "English";
      case 'bn': return "বাংলা";
      case 'es': return "Español";
      case 'fr': return "Français";
      case 'hi': return "हिन्दी";
      case 'ar': return "العربية";
      default: return "English";
    }
  }

  // Helper to get display name for theme mode
  String _getThemeName(ThemeMode mode, AppLocalizations loc) {
    switch (mode) {
      case ThemeMode.system: return loc.translate('theme_system');
      case ThemeMode.light: return loc.translate('theme_light');
      case ThemeMode.dark: return loc.translate('theme_dark');
    }
  }

  // Helper to build language option
  Widget _buildLanguageOption(BuildContext context, String code, String name) {
    return SimpleDialogOption(
      onPressed: () {
        SettingsNotifier.instance.updateLocale(Locale(code));
        Navigator.pop(context);
      },
      child: Text(name, style: TextStyle(
        fontWeight: SettingsNotifier.instance.locale.languageCode == code ? FontWeight.bold : FontWeight.normal,
        color: SettingsNotifier.instance.locale.languageCode == code ? AppColors.primaryGreen : Colors.black87,
      )),
    );
  }
}
