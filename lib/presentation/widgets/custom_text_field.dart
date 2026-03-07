import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_shapes.dart';
import 'app_text_field.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      hintText: hintText,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
    );
  }
}

class ProfileInputCard extends StatelessWidget {
  final String label;
  final Widget child;

  const ProfileInputCard({super.key, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: context.colorTextDark,
          ),
        ),
        SizedBox(height: AppDimens.spaceXs),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppDimens.spaceLg,
            vertical: AppDimens.spaceMdPlus,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppShapes.md,
            border: Border.all(color: context.colorBorder),
          ),
          child: child,
        ),
      ],
    );
  }
}
