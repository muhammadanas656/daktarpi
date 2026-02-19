import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../presentation/widgets/primary_button.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';
import '../../../../core/constants/app_routes.dart';

class Verify2FAScreen extends StatefulWidget {
  const Verify2FAScreen({super.key});

  @override
  State<Verify2FAScreen> createState() => _Verify2FAScreenState();
}

class _Verify2FAScreenState extends State<Verify2FAScreen> {
  final _codeController = TextEditingController();
  final _recoveryController = TextEditingController();
  
  bool _isLoading = false;
  bool _isRecoveryMode = false; // Toggle state

  @override
  void dispose() {
    _codeController.dispose();
    _recoveryController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _isRecoveryMode 
        ? _recoveryController.text.trim()
        : _codeController.text.trim();

    if (code.isEmpty) {
      CustomSnackbar.showError(context, "Please enter the code.");
      return;
    }

    // Basic format validation
    if (!_isRecoveryMode && code.length != 6) {
       CustomSnackbar.showError(context, "TOTP Code must be 6 digits.");
       return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isRecoveryMode) {
        // --- RECOVERY MODE ---
        final success = await Supabase.instance.client.rpc(
          'use_recovery_code', 
          params: {'input_code': code}
        );

        if (success == true) {
          if (mounted) {
            CustomSnackbar.showSuccess(context, "Access recovered! 2FA has been disabled.");
            context.go(AppRoutes.home);
          }
        } else {
          throw "Invalid recovery code.";
        }
      } else {
        // --- TOTP MODE ---
        await Supabase.instance.client.auth.mfa.challengeAndVerify(
          factorId: (await Supabase.instance.client.auth.mfa.listFactors()).all.first.id,
          code: code,
        );

        if (mounted) {
           context.go(AppRoutes.home);
        }
      }
    } on AuthException catch (e) {
      if (mounted) CustomSnackbar.showError(context, e.message);
    } catch (e) {
      if (mounted) CustomSnackbar.showError(context, e.toString().replaceAll("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                       color: Colors.black.withValues(alpha: 0.1),
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
                        color: _isRecoveryMode 
                            ? Colors.red.withValues(alpha: 0.1)
                            : AppColors.primaryGreen.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isRecoveryMode ? Icons.lock_open : Icons.security, 
                        size: 40, 
                        color: _isRecoveryMode ? Colors.red : AppColors.primaryGreen
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _isRecoveryMode ? "Enter Backup Code" : "Two-Factor Authentication", 
                        key: ValueKey(_isRecoveryMode),
                        style: AppTextStyles.h2, 
                        textAlign: TextAlign.center
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _isRecoveryMode 
                            ? "Enter one of your 8-character backup codes to disable 2FA and login."
                            : "Enter the 6-digit code from your authenticator app to continue.",
                        key: ValueKey(_isRecoveryMode),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textLight, fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // INPUT TOGGLE
                    AnimatedCrossFade(
                      firstChild: TextField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 6,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          counterText: "",
                          hintText: "000000",
                          hintStyle: TextStyle(color: Colors.grey[300]),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderColor)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderColor)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2)),
                        ),
                      ),
                      secondChild: TextField(
                        controller: _recoveryController,
                        keyboardType: TextInputType.text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2, fontFamily: 'monospace'),
                        decoration: InputDecoration(
                          hintText: "XXXX-XXXX-XXXX",
                          hintStyle: TextStyle(color: Colors.grey[300]),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderColor)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderColor)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 2)),
                        ),
                      ),
                      crossFadeState: _isRecoveryMode ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 300),
                    ),
                    
                    const SizedBox(height: 32),
            
                    PrimaryButton(
                      label: _isRecoveryMode ? "Unlock Account" : "Verify",
                      onTap: _verify,
                      isLoading: _isLoading,
                      backgroundColor: _isRecoveryMode ? Colors.red : AppColors.primaryGreen,
                    ),
                    const SizedBox(height: 16),
                    
                    // TOGGLE BUTTON
                    TextButton(
                       onPressed: () {
                         setState(() {
                           _isRecoveryMode = !_isRecoveryMode;
                           _codeController.clear();
                           _recoveryController.clear();
                         });
                       },
                       child: Text(
                         _isRecoveryMode ? "Use Authenticator App" : "Lost your phone? Use Backup Code",
                         style: TextStyle(
                           color: _isRecoveryMode ? AppColors.primaryGreen : Colors.grey[700], 
                           fontWeight: FontWeight.bold
                         )
                       ),
                    ),
                    
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        Supabase.instance.client.auth.signOut();
                        context.go(AppRoutes.login);
                      },
                      child: const Text("Cancel & Logout", style: TextStyle(color: Colors.grey)),
                    )
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
