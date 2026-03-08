import 'package:flutter/material.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_shapes.dart';
import '../../core/theme/app_styles.dart';

class SocialButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const SocialButton({
    super.key,
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // PRO FIX: Detect theme to apply Deep Medical Slate adjustments
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: AppDimens.buttonHeight,
      decoration: BoxDecoration(
        // PRO FIX: Dynamic surface color instead of hardcoded Colors.white
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppShapes.lg,
        // PRO FIX: Subtle border in dark mode, soft shadow in light mode
        border: isDark ? Border.all(color: const Color(0xFF2A3441)) : null,
        boxShadow: AppStyles.cardShadow(context),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppShapes.lg,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: AppDimens.spaceMd),
              Text(
                label,
                style: TextStyle(
                  // PRO FIX: Dynamic text color to ensure readability
                  color: isDark ? Colors.white : const Color(0xFF666666),
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
