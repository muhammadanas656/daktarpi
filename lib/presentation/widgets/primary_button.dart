import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isLoading;
  final Color backgroundColor;
  final double height;
  final double borderRadius;
  final double fontSize;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.isLoading = false,
    this.backgroundColor = AppColors.primaryGreen,
    this.height = 56,
    this.borderRadius = 16,
    this.fontSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: Colors.white,
          shadowColor: backgroundColor.withValues(alpha: 0.4),
          elevation: 8, // Elevated Premium Look
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), // Premium Radius
          ),
        ),
        child:
            isLoading
                ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                : Text(
                  label,
                  style: AppTextStyles.button.copyWith(fontSize: fontSize),
                ),
      ),
    );
  }
}
