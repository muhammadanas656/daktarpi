import 'dart:async';
import '../../../../core/constants/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';
import '../../../../presentation/widgets/auth_text_field.dart';
import '../../../../presentation/widgets/primary_button.dart';
import '../../../../presentation/widgets/social_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/auth_entry_route_service.dart';
import '../../data/auth_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final AuthRepository _authRepository = AuthRepository();
  late final AuthEntryRouteService _authEntryRouteService =
      AuthEntryRouteService(authRepository: _authRepository);

  bool _isGoogleInitialized = false;

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isInputValid = true;

  Timer? _timer;
  int _resendCountdown = 0;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onEmailChanged);
    unawaited(_initializeGoogleSignIn());
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
      setState(() {
        _isInputValid = !hasForbiddenChar;
      });
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

  Future<void> _initializeGoogleSignIn() async {
    if (_isGoogleInitialized) {
      return;
    }

    try {
      final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID']?.trim();
      await _googleSignIn.initialize(
        // Must be the Web OAuth client ID, not Android/iOS client IDs.
        serverClientId:
            webClientId != null && webClientId.isNotEmpty ? webClientId : null,
      );
      _isGoogleInitialized = true;
    } catch (_) {
      _isGoogleInitialized = false;
    }
  }

  void _showForgotPasswordSheet() {
    if (_resendCountdown > 0) {
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => _ForgotPasswordSheetContent(onCodeSent: _startCooldown),
    );
  }

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

    setState(() {
      _isLoading = true;
    });

    try {
      await _authRepository.signIn(email: email, password: password);

      if (mounted) {
        final route = await _authEntryRouteService.resolvePostAuthRoute();
        if (!mounted) {
          return;
        }
        context.go(route);
      }
    } on AuthException catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, e.message);
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(
          context,
          'Something went wrong. Please try again.',
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

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _initializeGoogleSignIn();

      if (!_googleSignIn.supportsAuthenticate()) {
        throw UnsupportedError(
          'Google Sign-In interactive flow is not supported on this platform.',
        );
      }

      // No null check needed here because authenticate() never returns null
      final googleUser = await _googleSignIn.authenticate();

      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw 'No ID Token found.';
      }

      await _authRepository.signInWithGoogleIdToken(idToken: idToken);

      if (mounted) {
        final route = await _authEntryRouteService.resolvePostAuthRoute();
        if (!mounted) {
          return;
        }
        context.go(route);
      }
    } on AuthException catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, e.message);
      }
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted ||
          e.code == GoogleSignInExceptionCode.uiUnavailable) {
        return;
      }

      if (!mounted) {
        return;
      }

      if (e.code == GoogleSignInExceptionCode.clientConfigurationError ||
          e.code == GoogleSignInExceptionCode.providerConfigurationError) {
        CustomSnackbar.showError(
          context,
          'Google Sign-In is not configured correctly. Use GOOGLE_WEB_CLIENT_ID as serverClientId and verify app SHA-1 in Google Cloud for release builds.',
        );
        return;
      }

      CustomSnackbar.showError(
        context,
        'Google Sign-In failed. Please try again.',
      );
    } on PlatformException catch (e) {
      if (e.code == 'sign_in_canceled' ||
          e.code == 'canceled' ||
          e.code == 'cancelled') {
        return;
      }
      if (mounted) {
        CustomSnackbar.showError(
          context,
          'Google Sign-In failed. Please try again.',
        );
      }
    } catch (e) {
      if (mounted) {
        final message = e.toString().toLowerCase();
        if (message.contains('signincancelederror') ||
            message.contains('sign_in_canceled') ||
            message.contains('signin canceled') ||
            message.contains('canceled') ||
            message.contains('cancelled')) {
          return;
        }
        CustomSnackbar.showError(
          context,
          'Google Sign-In failed. Please try again.',
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

class _ForgotPasswordSheetContent extends StatefulWidget {
  final VoidCallback? onCodeSent;
  const _ForgotPasswordSheetContent({this.onCodeSent});

  @override
  State<_ForgotPasswordSheetContent> createState() =>
      _ForgotPasswordSheetContentState();
}

class _ForgotPasswordSheetContentState
    extends State<_ForgotPasswordSheetContent>
    with WidgetsBindingObserver {
  int _currentStep = 0;
  bool _isLoading = false;

  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();
  final AuthRepository _authRepository = AuthRepository();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _emailController.dispose();
    _otpController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _currentStep == 1) {
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

      final cleanText = text.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanText.length == 8) {
        if (_otpController.text != cleanText) {
          setState(() {
            _otpController.text = cleanText;
          });
          _verifyOtp();
        }
      }
    } catch (_) {}
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

    setState(() {
      _isLoading = true;
    });

    try {
      await _authRepository.resetPasswordForEmail(email);
      if (widget.onCodeSent != null) {
        widget.onCodeSent!();
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentStep = 1;
        });
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        if (e.message.contains("Rate limit")) {
          CustomSnackbar.showError(context, "Too many attempts. Wait 60s.");
          if (widget.onCodeSent != null) {
            widget.onCodeSent!();
          }
        } else {
          CustomSnackbar.showError(context, e.message);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        CustomSnackbar.showError(context, "Network error. Try again.");
      }
    }
  }

  Future<void> _verifyOtp() async {
    String code = _otpController.text.trim();
    if (code.length != 8) {
      CustomSnackbar.showError(context, "Enter all 8 digits.");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final email = _emailController.text.trim();
      final response = await _authRepository.verifyRecoveryOtp(
        token: code,
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
        setState(() {
          _isLoading = false;
        });
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

    setState(() {
      _isLoading = true;
    });

    try {
      await _authRepository.signIn(email: email, password: newPass);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        CustomSnackbar.showError(
          context,
          "You cannot use your previous password.",
        );
      }
      return;
    } catch (e) {
      // User is using a new password
    }

    try {
      await _authRepository.updatePassword(newPass);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                SizedBox(width: 12),
                Flexible(
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
        setState(() {
          _isLoading = false;
        });
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
    return Column(
      children: [
        const Text(
          'Enter 8-Digit Code',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Enter the 8-digit code sent to your email.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Color(0xFF858585), height: 1.5),
        ),
        const SizedBox(height: 30),

        LayoutBuilder(
          builder: (context, constraints) {
            double availableWidth = constraints.maxWidth;
            double boxWidth = (availableWidth - (7 * 8)) / 8;
            boxWidth = boxWidth.clamp(25.0, 45.0);

            final defaultPinTheme = PinTheme(
              width: boxWidth,
              height: boxWidth + 10,
              textStyle: const TextStyle(
                fontSize: 22,
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.bold,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
            );

            return Pinput(
              length: 8,
              controller: _otpController,
              defaultPinTheme: defaultPinTheme,
              focusedPinTheme: defaultPinTheme.copyWith(
                decoration: defaultPinTheme.decoration!.copyWith(
                  border: Border.all(color: AppColors.primaryGreen, width: 2),
                ),
              ),
              autofocus: true,
              onCompleted: (pin) => _verifyOtp(),
            );
          },
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
