import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      return _showBottomError("Please enter your name");
    }
    if (email.isEmpty) {
      return _showBottomError("Please enter your email address");
    }
    if (!email.contains('@') || !email.contains('.')) {
      return _showBottomError("Please enter a valid email address");
    }
    if (password.isEmpty) {
      return _showBottomError("Please enter your password");
    }
    if (password.length < 6) {
      return _showBottomError("Password must be at least 6 characters");
    }
    if (!_agreedToTerms) {
      return _showBottomError("Please agree to the Terms & Privacy Policy");
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
          context.go('/profile/edit');
        } else {
          // Email confirmation required flow
          _showBottomError("Account created! Please check your email.");
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) context.go('/login');
        }
      }
    } on AuthException catch (e) {
      if (mounted) _showBottomError(e.message);
    } catch (e) {
      if (mounted) _showBottomError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- REUSABLE ERROR SNACKBAR (Matches Login Style) ---
  void _showBottomError(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        margin: const EdgeInsets.only(bottom: 40, left: 20, right: 20),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
      ),
    );
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
    const primaryGreen = Color(0xFF00C689);
    const primaryText = Color(0xFF1A1A1A);
    const secondaryText = Color(0xFF858585);

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
                        const SizedBox(height: 80),

                        const Text(
                          'Join us to start searching',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: primaryText,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'You can search course, apply course and find\nscholarship for abroad studies',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: secondaryText,
                            height: 1.5,
                          ),
                        ),

                        const SizedBox(height: 35),

                        // --- SOCIAL BUTTONS ---
                        Row(
                          children: [
                            Expanded(
                              child: _SocialCard(
                                label: "Google",
                                icon: Icons.g_mobiledata,
                                iconColor: Colors.red,
                                onTap: () {},
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _SocialCard(
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
                        _FloatingInput(
                          controller: _nameController,
                          hintText: "Name",
                        ),
                        const SizedBox(height: 16),

                        // --- EMAIL ---
                        _FloatingInput(
                          controller: _emailController,
                          hintText: "Email",
                          isEmail: true,
                        ),
                        const SizedBox(height: 16),

                        // --- PASSWORD ---
                        _FloatingInput(
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
                                activeColor: primaryGreen,
                                shape: const CircleBorder(),
                                side: const BorderSide(
                                  color: Color(0xFFC4C4C4),
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
                            const Expanded(
                              child: Text(
                                'I agree with the Terms of Service & Privacy Policy',
                                style: TextStyle(
                                  color: secondaryText,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 30),

                        // --- SIGN UP BUTTON ---
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _signUp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryGreen,
                              foregroundColor: Colors.white,
                              elevation: 10,
                              shadowColor: primaryGreen.withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child:
                                _isLoading
                                    ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                    : const Text(
                                      'Sign up',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                          ),
                        ),

                        const Spacer(),

                        // --- FOOTER ---
                        Padding(
                          padding: const EdgeInsets.only(bottom: 30),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "Have an account? ",
                                style: TextStyle(
                                  color: primaryGreen,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => context.go('/login'),
                                child: const Text(
                                  'Log in',
                                  style: TextStyle(
                                    color: primaryGreen,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
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

// --- REUSABLE WIDGETS (Same as LoginScreen for consistency) ---

class _FloatingInput extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool isPassword;
  final bool isEmail;
  final bool isPasswordVisible;
  final VoidCallback? onVisibilityToggle;

  const _FloatingInput({
    required this.controller,
    required this.hintText,
    this.isPassword = false,
    this.isEmail = false,
    this.isPasswordVisible = false,
    this.onVisibilityToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && !isPasswordVisible,
        keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
        style: const TextStyle(
          color: Color(0xFF1A1A1A),
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 20,
          ),
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0xFFC4C4C4), fontSize: 14),
          suffixIcon:
              isPassword
                  ? IconButton(
                    icon: Icon(
                      isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: const Color(0xFFC4C4C4),
                      size: 20,
                    ),
                    onPressed: onVisibilityToggle,
                  )
                  : null,
        ),
      ),
    );
  }
}

class _SocialCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _SocialCard({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF666666),
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
