import 'package:flutter/material.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_colors.dart';

class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? actionButton;
  final double iconSize;

  const EmptyStateWidget({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.actionButton,
    this.iconSize = 42,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.03)
                : AppColors.primaryGreen.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : AppColors.primaryGreen.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGreen.withValues(alpha: 0.2),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  size: iconSize,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.h2(context).copyWith(
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : const Color(0xFF1D1D1F),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 12),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.black54,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
              if (actionButton != null) ...[
                const SizedBox(height: 32),
                actionButton!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
