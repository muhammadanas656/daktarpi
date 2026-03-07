import 'package:flutter/material.dart';
import 'app_text_field.dart';

class AuthTextField extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      hintText: hintText,
      isPassword: isPassword,
      isEmail: isEmail,
      suffixIcon: suffixIcon,
      isPasswordVisible: isPasswordVisible,
      onVisibilityToggle: onVisibilityToggle,
    );
  }
}
