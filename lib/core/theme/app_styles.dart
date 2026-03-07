import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_dimens.dart';
import 'app_shapes.dart';

class AppStyles {
  // PRO FIX: Dynamic Gradient that shifts to deep slate in dark mode
  static LinearGradient pageGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return isDark
        ? const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.darkScaffold, AppColors.darkScaffold],
        )
        : const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.lightGreenBg,
            Colors.white,
            Colors.white,
            Color(0xFFE8F5E9),
          ],
          stops: [0.0, 0.3, 0.7, 1.0],
        );
  }

  static EdgeInsets pagePadding = const EdgeInsets.symmetric(
    horizontal: AppDimens.pageHorizontalPadding,
    vertical: AppDimens.pageVerticalPadding,
  );

  // PRO FIX: Shadows automatically turn off in Dark Mode
  static List<BoxShadow> cardShadow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isDark) return []; // No shadows on dark surfaces!

    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ];
  }

  static final BorderRadius cardRadius = AppShapes.lg;

  // PRO FIX: Context-aware surface cards
  static BoxDecoration surfaceCard(
    BuildContext context, {
    BorderRadius? borderRadius,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BoxDecoration(
      color: Theme.of(context).colorScheme.surface, // Adapts automatically
      borderRadius: borderRadius ?? cardRadius,
      border: Border.all(
        color: isDark ? AppColors.darkBorder : AppColors.borderColor,
      ),
      boxShadow: cardShadow(context),
    );
  }
}
