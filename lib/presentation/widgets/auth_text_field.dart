import 'package:flutter/material.dart';

class AuthTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final bool isPassword;
  final bool isEmail;
  final Widget? suffixIcon;
  final bool? isPasswordVisible;
  final VoidCallback? onVisibilityToggle;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.isPassword = false,
    this.isEmail = false,
    this.suffixIcon,
    this.isPasswordVisible,
    this.onVisibilityToggle,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _internalIsVisible = false;

  @override
  Widget build(BuildContext context) {
    final isVisible = widget.isPasswordVisible ?? _internalIsVisible;
    return Container(
      height: 60,
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
      alignment: Alignment.center,
      child: Center(
        child: TextField(
          controller: widget.controller,
          obscureText: widget.isPassword && !isVisible,
          keyboardType:
              widget.isEmail ? TextInputType.emailAddress : TextInputType.text,
          textAlignVertical: TextAlignVertical.center,
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            hintText: widget.hintText,
            hintStyle: const TextStyle(color: Color(0xFFC4C4C4), fontSize: 14),
            suffixIcon:
                widget.isPassword
                    ? IconButton(
                      icon: Icon(
                        isVisible ? Icons.visibility : Icons.visibility_off,
                        color: const Color(0xFFC4C4C4),
                        size: 20,
                      ),
                      onPressed: () {
                        if (widget.onVisibilityToggle != null) {
                          widget.onVisibilityToggle!();
                        } else {
                          setState(
                            () => _internalIsVisible = !_internalIsVisible,
                          );
                        }
                      },
                    )
                    : widget.suffixIcon,
          ),
        ),
      ),
    );
  }
}
