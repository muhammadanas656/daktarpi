import 'package:flutter/material.dart';
import '../../../../core/constants/app_routes.dart';
import 'package:go_router/go_router.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';
import '../../../../presentation/widgets/auth_text_field.dart';
import '../../../../presentation/widgets/primary_button.dart';
import '../../../../presentation/widgets/social_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

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

  Future<void> _signUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // --- 1. VALIDATION ---
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
      CustomSnackbar.showError(context, "Password must be at least 6 characters");
      return;
    }
    if (!_agreedToTerms) {
      CustomSnackbar.showError(context, "Please agree to the Terms & Privacy Policy");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // --- 2. SIGN UP LOGIC ---
      final AuthResponse res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': name}, // Save name to metadata initially
      );

      if (mounted) {
        if (res.session != null) {
          // SUCCESS: New users ALWAYS go to /profile/edit to complete setup (Phone, DOB, Location)
          context.go(AppRoutes.profileEdit);
        } else {
          // Email confirmation required flow
          CustomSnackbar.showSuccess(context, "Account created! Please check your email.");
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) context.go(AppRoutes.login);
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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
                        const SizedBox(height: 60),

                        Text(
                          'Join us to start searching',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.h1,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'You can search course, apply course and find\nscholarship for abroad studies',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body.copyWith(height: 1.5),
                        ),

                        const SizedBox(height: 35),

                        // --- SOCIAL BUTTONS ---
                        Row(
                          children: [
                            Expanded(
                              child: SocialButton(
                                label: "Google",
                                icon: Icons.g_mobiledata,
                                iconColor: Colors.red,
                                onTap: () {},
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: SocialButton(
                                label: "Facebook",
                                icon: Icons.facebook,
                                iconColor: Color(0xFF1877F2),
                                onTap: () {},
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 35),

                        // --- NAME ---
                        AuthTextField(
                          controller: _nameController,
                          hintText: "Name",
                        ),
                        const SizedBox(height: 16),

                        // --- EMAIL ---
                        AuthTextField(
                          controller: _emailController,
                          hintText: "Email",
                          isEmail: true,
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
                                side: const BorderSide(
                                  color: AppColors.borderColor,
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
                              child: Text(
                                'I agree with the Terms of Service & Privacy Policy',
                                  style: AppTextStyles.bodySmall,
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
                                  style: AppTextStyles.body.copyWith(
                                    color: AppColors.primaryGreen,
                                    fontWeight: FontWeight.w500,
                                  ),
                              ),
                              GestureDetector(
                                onTap: () => context.go(AppRoutes.login),
                                child: Text(
                                  'Log in',
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

// Removed _FloatingInput, _GreenButton, and _SocialCard as they are now replaced by reusability widgets
