import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_dimens.dart';
import 'app_shapes.dart';

class AppStyles {
  static const LinearGradient pageGradient = LinearGradient(
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

  static const EdgeInsets pagePadding = EdgeInsets.symmetric(
    horizontal: AppDimens.pageHorizontalPadding,
    vertical: AppDimens.pageVerticalPadding,
  );

  static final List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static final BorderRadius cardRadius = AppShapes.lg;

  static BoxDecoration surfaceCard({BorderRadius? borderRadius}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: borderRadius ?? cardRadius,
      border: Border.all(color: AppColors.borderColor),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }
}
