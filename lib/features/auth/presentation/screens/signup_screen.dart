import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/constants/app_routes.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/gestures.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';
import '../../../../presentation/widgets/app_text_field.dart';
import '../../../../presentation/widgets/primary_button.dart';
import '../../../../presentation/widgets/social_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/auth_repository.dart';
import '../../data/auth_entry_route_service.dart';
import '../../../../core/theme/app_styles.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _agreedToTerms = false;

  final AuthRepository _authRepository = AuthRepository();

  // PRO FIX: Added Google Sign-in dependencies
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  late final AuthEntryRouteService _authEntryRouteService =
      AuthEntryRouteService(authRepository: _authRepository);
  bool _isGoogleInitialized = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeGoogleSignIn());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- GOOGLE SIGN-IN LOGIC ---
  Future<void> _initializeGoogleSignIn() async {
    if (_isGoogleInitialized) return;
    try {
      final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID']?.trim();
      await _googleSignIn.initialize(
        serverClientId:
            webClientId != null && webClientId.isNotEmpty ? webClientId : null,
      );
      _isGoogleInitialized = true;
    } catch (_) {
      _isGoogleInitialized = false;
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await _initializeGoogleSignIn();
      if (!_googleSignIn.supportsAuthenticate()) {
        throw UnsupportedError(
          'Google Sign-In is not supported on this platform.',
        );
      }

      final googleUser = await _googleSignIn.authenticate();
      final idToken = googleUser.authentication.idToken;

      if (idToken == null) throw 'No ID Token found.';

      await _authRepository.signInWithGoogleIdToken(idToken: idToken);

      if (mounted) {
        final route = await _authEntryRouteService.resolvePostAuthRoute(
          intendedRoute: null,
        );
        if (mounted) context.go(route);
      }
    } on AuthException catch (e) {
      if (mounted) CustomSnackbar.showError(context, e.message);
    } on PlatformException catch (e) {
      if (e.code != 'sign_in_canceled' && e.code != 'canceled' && mounted) {
        CustomSnackbar.showError(
          context,
          'Google Sign-In failed. Please try again.',
        );
      }
    } catch (e) {
      if (mounted && !e.toString().toLowerCase().contains('canceled')) {
        CustomSnackbar.showError(
          context,
          'Google Sign-In failed. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- EMAIL SIGN-UP LOGIC ---
  Future<void> _signUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // 1. VALIDATION
    if (name.isEmpty) {
      CustomSnackbar.showError(context, "Please enter your name");
      return;
    }
    if (email.isEmpty) {
      CustomSnackbar.showError(context, "Please enter your email address");
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      CustomSnackbar.showError(context, "Please enter a valid email address");
      return;
    }
    if (password.isEmpty) {
      CustomSnackbar.showError(context, "Please enter your password");
      return;
    }
    if (password.length < 6) {
      CustomSnackbar.showError(
        context,
        "Password must be at least 6 characters",
      );
      return;
    }
    if (!_agreedToTerms) {
      CustomSnackbar.showError(
        context,
        "Please agree to the Terms & Privacy Policy",
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 2. SIGN UP LOGIC
      final AuthResponse res = await _authRepository.signUp(
        email: email,
        password: password,
        data: {'full_name': name}, // Save name to metadata initially
      );

      if (mounted) {
        if (res.session != null) {
          // SUCCESS: New users ALWAYS go to /profile/edit to complete setup
          context.go(AppRoutes.profileEdit);
        } else {
          // Email confirmation required flow
          CustomSnackbar.showSuccess(
            context,
            "Account created! Please check your email.",
          );
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) context.go(AppRoutes.login);
        }
      }
    } on AuthException catch (e) {
      if (mounted) CustomSnackbar.showError(context, e.message);
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(
          context,
          'Something went wrong. Please try again.',
        );
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
        // PRO FIX: Contextual dynamic gradient
        decoration: BoxDecoration(gradient: AppStyles.pageGradient(context)),
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
                        const SizedBox(height: 60),

                        Text(
                          'Join us to start searching',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.h1(context),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Connect with top doctors and manage your health journey',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body(
                            context,
                          ).copyWith(height: 1.5),
                        ),

                        const SizedBox(height: 35),

                        // --- SOCIAL BUTTONS ---
                        SocialButton(
                          label: "Continue with Google",
                          icon: Icons.g_mobiledata,
                          iconColor: Colors.red,
                          // PRO FIX: Google Auth Logic successfully wired
                          onTap: _signInWithGoogle,
                        ),

                        const SizedBox(height: 35),

                        // --- NAME ---
                        AppTextField(
                          controller: _nameController,
                          hintText: "Name",
                        ),
                        const SizedBox(height: 16),

                        // --- EMAIL ---
                        AppTextField(
                          controller: _emailController,
                          hintText: "Email",
                          isEmail: true,
                        ),
                        const SizedBox(height: 16),

                        // --- PASSWORD ---
                        AppTextField(
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

                        const SizedBox(height: 20),

                        // --- TERMS CHECKBOX ---
                        Row(
                          children: [
                            SizedBox(
                              height: 24,
                              width: 24,
                              child: Checkbox(
                                value: _agreedToTerms,
                                activeColor: AppColors.primaryGreen,
                                shape: const CircleBorder(),
                                side: BorderSide(
                                  color: context.colorBorder,
                                  width: 1.5,
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _agreedToTerms = value ?? false;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: AppTextStyles.bodySmall(context),
                                  children: [
                                    const TextSpan(text: 'I agree with the '),
                                    TextSpan(
                                      text: 'Terms of Service',
                                      style: const TextStyle(
                                        color: AppColors.primaryGreen,
                                        fontWeight: FontWeight.bold,
                                        decoration: TextDecoration.underline,
                                      ),
                                      recognizer:
                                          TapGestureRecognizer()
                                            ..onTap =
                                                () => context.push(
                                                  AppRoutes.termsOfService,
                                                ),
                                    ),
                                    const TextSpan(text: ' & '),
                                    TextSpan(
                                      text: 'Privacy Policy',
                                      style: const TextStyle(
                                        color: AppColors.primaryGreen,
                                        fontWeight: FontWeight.bold,
                                        decoration: TextDecoration.underline,
                                      ),
                                      recognizer:
                                          TapGestureRecognizer()
                                            ..onTap =
                                                () => context.push(
                                                  AppRoutes.privacyPolicy,
                                                ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 30),

                        // --- SIGN UP BUTTON ---
                        PrimaryButton(
                          label: "Sign Up",
                          onTap: _signUp,
                          isLoading: _isLoading,
                        ),

                        const Spacer(),

                        // --- FOOTER ---
                        Padding(
                          padding: const EdgeInsets.only(bottom: 30),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Have an account? ",
                                style: AppTextStyles.body(context).copyWith(
                                  color: AppColors.primaryGreen,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => context.go(AppRoutes.login),
                                child: Text(
                                  'Log in',
                                  style: AppTextStyles.body(context).copyWith(
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
