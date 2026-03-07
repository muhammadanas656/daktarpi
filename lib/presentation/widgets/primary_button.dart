import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_shapes.dart';
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
    this.height = AppDimens.buttonHeight,
    this.borderRadius = AppShapes.radiusLg,
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
          shadowColor: Theme.of(context).brightness == Brightness.dark 
              ? Colors.transparent 
              : backgroundColor.withValues(alpha: 0.4),
          elevation: Theme.of(context).brightness == Brightness.dark ? 0 : AppDimens.elevationHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        child:
            isLoading
                ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: AppTextStyles.button(context).copyWith(
                      fontSize: fontSize,
                      // PRO FIX: Ensures contrast is always maintained
                      color: Colors.white, 
                    ),
                  ),
                ),
      ),
    );
  }
}
