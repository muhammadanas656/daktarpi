import 'dart:async';
import '../../../../core/constants/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';
import '../../../../presentation/widgets/auth_text_field.dart';
import '../../../../presentation/widgets/primary_button.dart';
import '../../../../presentation/widgets/social_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  // GoogleSignIn is a singleton in v7+
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isInputValid = true;


  // --- TIMER STATE ---
  Timer? _timer;
  int _resendCountdown = 0;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onEmailChanged);
    _initializeGoogleSignIn();
  }

  Future<void> _initializeGoogleSignIn() async {
    // In v7+, we configure via initialize
    await _googleSignIn.initialize(
       serverClientId: dotenv.env['GOOGLE_WEB_CLIENT_ID'],
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onEmailChanged() {
    final text = _emailController.text;
    final hasForbiddenChar = RegExp(r"[^a-zA-Z0-9@._-]").hasMatch(text);
    if (_isInputValid != !hasForbiddenChar) {
      setState(() => _isInputValid = !hasForbiddenChar);
    }
  }

  void _startCooldown() {
    setState(() {
      _resendCountdown = 60;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown == 0) {
        timer.cancel();
      } else {
        setState(() {
          _resendCountdown--;
        });
      }
    });
  }

  void _showForgotPasswordSheet() {
    if (_resendCountdown > 0) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => _ForgotPasswordSheetContent(onCodeSent: _startCooldown),
    );
  }

  // --- LOGIN LOGIC ---
  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty) {
      CustomSnackbar.showError(context, "Please enter your email address");
      return;
    }
    if (!_isInputValid || !email.contains('@') || !email.contains('.')) {
      CustomSnackbar.showError(context, "Please enter a valid email address");
      return;
    }
    if (password.isEmpty) {
      CustomSnackbar.showError(context, "Please enter your password");
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (mounted) {
        final user = Supabase.instance.client.auth.currentUser;
        final metadata = user?.userMetadata;
        final appMetadata = user?.appMetadata;

        // --- 2FA CHECK ---
        final aal = appMetadata?['aal'] as String?;
        final is2FAEnabled = appMetadata?['is_2fa_enabled'] == true; // Checked against app_metadata (Secure)
        // final factors = await Supabase.instance.client.auth.mfa.listFactors();
        // final hasVerifiedFactor = factors.all.any((factor) => factor.status == FactorStatus.verified); // Removed unused variable

        if (!mounted) return;

        // If 2FA is enabled in app_metadata, and we are at AAL1, enforce AAL2.
        if (is2FAEnabled && (aal == 'aal1' || aal == null)) {
           context.go(AppRoutes.verify2fa);
           return;
        }

        // Check if profile is complete (using DOB as the flag)
        final hasDob =
            metadata?['dob'] != null && metadata!['dob'].toString().isNotEmpty;

        if (!hasDob) {
          // UPDATED: Go directly to the Edit/Setup Form, not the Read-Only View
          context.go(AppRoutes.profileEdit);
        } else {
          // Go to Home if profile is complete
          context.go(AppRoutes.home);
        }
      }
    } on AuthException catch (e) {
      if (mounted) CustomSnackbar.showError(context, e.message);
    } catch (e) {
      if (mounted) CustomSnackbar.showError(context, 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      // google_sign_in v7 requires one-time explicit initialization.
      if (!_googleSignIn.supportsAuthenticate()) {
        throw UnsupportedError(
          'Google Sign-In interactive flow is not supported on this platform.',
        );
      }

      final googleUser = await _googleSignIn.authenticate();
      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw 'No ID Token found.';
      }

      // 2. Sign in to Supabase
      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );

      // 3. Post-Login Checks
       if (mounted) {
        final user = Supabase.instance.client.auth.currentUser;
        final metadata = user?.userMetadata;
        
        // Note: OAuth logins typically bypass 2FA unless configured otherwise in Supabase.
        
        // Check Profile
        final hasDob =
            metadata?['dob'] != null && metadata!['dob'].toString().isNotEmpty;

        if (!hasDob) {
          context.go(AppRoutes.profileEdit);
        } else {
          context.go(AppRoutes.home);
        }
      }

    } on AuthException catch (e) {
      if (mounted) CustomSnackbar.showError(context, e.message);
    } on PlatformException catch (e) {
      if (e.code == 'sign_in_canceled') {
        // User canceled, do nothing or show info
        return;
      }
      if (mounted) CustomSnackbar.showError(context, 'Google Sign-In error: ${e.message}');
    } catch (e) {
      if (mounted) {
        // Check for common cancellation messages in string
        if (e.toString().contains('canceled') || e.toString().contains('cancelled')) {
           return;
        }
        CustomSnackbar.showError(context, 'Google Sign-In failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        height: double.infinity,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.5, 1.0],
            colors: [Color(0xFFE0F4FF), Color(0xFFFFFFFF), Color(0xFFE0F8F1)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        constraints.maxHeight -
                        MediaQuery.of(context).padding.top,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        const SizedBox(height: 100),
                        Text(
                          'Welcome back',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.h1,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Manage your appointments and medical records securely',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body.copyWith(height: 1.5),
                        ),
                        const SizedBox(height: 35),
                        SocialButton(
                          label: "Continue with Google",
                          icon: Icons.g_mobiledata,
                          iconColor: Colors.red,
                          onTap: _signInWithGoogle,
                        ),
                        const SizedBox(height: 35),
                        // --- EMAIL ---
                        AuthTextField(
                          controller: _emailController,
                          hintText: "Email",
                          isEmail: true,
                          suffixIcon:
                              _isInputValid
                                  ? const Icon(
                                    Icons.check,
                                    color: AppColors.primaryGreen,
                                    size: 20,
                                  )
                                  : const Icon(
                                    Icons.close,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                        ),
                        const SizedBox(height: 16),
                        // --- PASSWORD ---
                        AuthTextField(
                          controller: _passwordController,
                          hintText: "Password",
                          isPassword: true,
                          isPasswordVisible: _isPasswordVisible,
                          onVisibilityToggle: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                        const SizedBox(height: 30),
                        // --- LOGIN BUTTON ---
                        PrimaryButton(
                          label: "Login",
                          onTap: _signIn,
                          isLoading: _isLoading,
                        ),
                        const SizedBox(height: 24),
                        GestureDetector(
                          onTap: _showForgotPasswordSheet,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Forgot password',
                                  style: AppTextStyles.body.copyWith(
                                    color:
                                        _resendCountdown > 0
                                            ? Colors.grey
                                            : AppColors.primaryGreen,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (_resendCountdown > 0) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    "Wait 00:${_resendCountdown.toString().padLeft(2, '0')}",
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.dangerRed,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 30),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Don't have an account? ",
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.primaryGreen,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => context.go(AppRoutes.signup),
                                child: Text(
                                  'Join us',
                                  style: AppTextStyles.body.copyWith(
                                    color: AppColors.primaryGreen,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// --- FORGOT PASSWORD SHEET ---
class _ForgotPasswordSheetContent extends StatefulWidget {
  final VoidCallback? onCodeSent;
  const _ForgotPasswordSheetContent({this.onCodeSent});

  @override
  State<_ForgotPasswordSheetContent> createState() =>
      _ForgotPasswordSheetContentState();
}

class _ForgotPasswordSheetContentState
    extends State<_ForgotPasswordSheetContent> {
  int _currentStep = 0;
  bool _isLoading = false;

  final _emailController = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(
    8,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(8, (_) => FocusNode());
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }



  Future<void> _pasteOtpCode() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;

    if (data != null && data.text != null) {
      String clipboardText = data.text!.trim();
      String digits = clipboardText.replaceAll(RegExp(r'[^0-9]'), '');

      if (digits.length == 8) {
        for (int i = 0; i < 8; i++) {
          _otpControllers[i].text = digits[i];
        }
        if (mounted) FocusScope.of(context).unfocus();
      } else {
        CustomSnackbar.showError(context, "Clipboard must contain exactly 8 digits.");
      }
    } else {
      CustomSnackbar.showError(context, "Clipboard is empty.");
    }
  }

  Future<void> _sendResetCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) { 
       CustomSnackbar.showError(context, "Please enter your email.");
       return;
    }
    if (!email.contains('@')) {
       CustomSnackbar.showError(context, "Invalid email format.");
       return;
    }

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (widget.onCodeSent != null) widget.onCodeSent!();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentStep = 1;
        });
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        if (e.message.contains("Rate limit")) {
          CustomSnackbar.showError(context, "Too many attempts. Wait 60s.");
          if (widget.onCodeSent != null) widget.onCodeSent!();
        } else {
          CustomSnackbar.showError(context, e.message);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomSnackbar.showError(context, "Network error. Try again.");
      }
    }
  }

  Future<void> _verifyOtp() async {
    String code = _otpControllers.map((c) => c.text).join();
    if (code.length != 8) {
       CustomSnackbar.showError(context, "Enter all 8 digits.");
       return;
    }

    setState(() => _isLoading = true);
    try {
      final email = _emailController.text.trim();
      final response = await Supabase.instance.client.auth.verifyOTP(
        token: code,
        type: OtpType.recovery,
        email: email,
      );
      if (response.session != null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _currentStep = 2;
          });
        }
      } else {
        throw const AuthException('Invalid code');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomSnackbar.showError(context, "Invalid code or expired.");
      }
    }
  }

  Future<void> _updatePassword() async {
    final newPass = _newPassController.text.trim();
    final confirmPass = _confirmPassController.text.trim();
    final email = _emailController.text.trim();

    if (newPass.length < 6) {
       CustomSnackbar.showError(context, "Password too short (min 6).");
       return;
    }
    if (newPass != confirmPass) {
       CustomSnackbar.showError(context, "Passwords do not match.");
       return;
    }

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: newPass,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        CustomSnackbar.showError(context, "You cannot use your previous password.");
      }
      return;
    } catch (e) {
      // Continue if password is new
    }

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPass),
      );

      if (mounted) {
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 12),
                const Flexible(
                  child: Text(
                    "Password updated! Please login.",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF00C689),
            behavior: SnackBarBehavior.floating,
            elevation: 6,
            margin: const EdgeInsets.only(bottom: 40, left: 20, right: 20),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomSnackbar.showError(context, "Failed to update password.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 40,
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 30),
            if (_currentStep == 0) _buildEmailStep(),
            if (_currentStep == 1) _buildOtpStep(),
            if (_currentStep == 2) _buildResetPasswordStep(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailStep() {
    return Column(
      children: [
        const Text(
          'Forgot password',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Enter your email to receive an 8-digit code.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Color(0xFF858585), height: 1.5),
        ),
        const SizedBox(height: 30),
        AuthTextField(
          controller: _emailController, 
          hintText: "Email",
          isEmail: true,
        ),
        const SizedBox(height: 30),
        PrimaryButton(
          label: "Continue",
          onTap: _sendResetCode,
          isLoading: _isLoading,
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    double gap = 8.0;
    double availableWidth = MediaQuery.of(context).size.width - 48;
    double boxSize = (availableWidth - (gap * 5)) / 6;

    if (boxSize < 40) boxSize = 40;
    if (boxSize > 60) boxSize = 60;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Enter 8-Digit Code',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            TextButton.icon(
              onPressed: _pasteOtpCode,
              icon: const Icon(
                Icons.paste_rounded,
                size: 18,
                color: Color(0xFF00C689),
              ),
              label: const Text(
                "Paste",
                style: TextStyle(
                  color: Color(0xFF00C689),
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                backgroundColor: const Color(0xFF00C689).withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Enter the 8-digit code sent to your email.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Color(0xFF858585), height: 1.5),
        ),
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            6,
            (index) => _OtpDigitBox(
              index: index,
              controller: _otpControllers[index],
              focusNode: _otpFocusNodes[index],
              size: boxSize,
              onChanged: (value) {
                if (value.isNotEmpty && index < 7) {
                  _otpFocusNodes[index + 1].requestFocus();
                }
              },
              onBackspace: () {
                if (index > 0) {
                  _otpFocusNodes[index - 1].requestFocus();
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _OtpDigitBox(
              index: 6,
              controller: _otpControllers[6],
              focusNode: _otpFocusNodes[6],
              size: boxSize,
              onChanged: (value) {
                if (value.isNotEmpty) _otpFocusNodes[7].requestFocus();
              },
              onBackspace: () {
                _otpFocusNodes[5].requestFocus();
              },
            ),
            SizedBox(width: gap),
            _OtpDigitBox(
              index: 7,
              controller: _otpControllers[7],
              focusNode: _otpFocusNodes[7],
              size: boxSize,
              onChanged: (value) {
                if (value.isNotEmpty) FocusScope.of(context).unfocus();
              },
              onBackspace: () {
                _otpFocusNodes[6].requestFocus();
              },
            ),
          ],
        ),
        const SizedBox(height: 30),
        PrimaryButton(
          label: "Verify Code",
          onTap: _verifyOtp,
          isLoading: _isLoading,
        ),
      ],
    );
  }

  Widget _buildResetPasswordStep() {
    return Column(
      children: [
        const Text(
          'Reset Password',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Set your new password.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Color(0xFF858585), height: 1.5),
        ),
        const SizedBox(height: 30),
        AuthTextField(
          controller: _newPassController,
          hintText: "New Password",
          isPassword: true,
        ),
        const SizedBox(height: 16),
        AuthTextField(
          controller: _confirmPassController,
          hintText: "Re-enter Password",
          isPassword: true,
        ),
        const SizedBox(height: 30),
        PrimaryButton(
          label: "Update Password",
          onTap: _updatePassword,
          isLoading: _isLoading,
        ),
      ],
    );
  }
}

class _OtpDigitBox extends StatelessWidget {
  final int index;
  final TextEditingController controller;
  final FocusNode focusNode;
  final double size;
  final ValueChanged<String> onChanged;
  final VoidCallback onBackspace;

  const _OtpDigitBox({
    required this.index,
    required this.controller,
    required this.focusNode,
    required this.size,
    required this.onChanged,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size + 5,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace) {
            if (controller.text.isEmpty) {
              onBackspace();
            }
          }
        },
        child: Center(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00C689),
              height: 1.0,
            ),
            strutStyle: const StrutStyle(
              fontSize: 22,
              height: 1.0,
              forceStrutHeight: true,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isCollapsed: true,
              contentPadding: EdgeInsets.zero,
              counterText: "",
            ),
            keyboardType: TextInputType.number,
            maxLength: 1,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

// Removed _FloatingInput, _GreenButton, and _SocialCard as they are now replaced by reusability widgets
