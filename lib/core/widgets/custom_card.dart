import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_shapes.dart';
import '../theme/app_styles.dart';

class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? borderRadius;
  final bool hasShadow;
  final VoidCallback? onTap;

  const CustomCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
    this.hasShadow = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final defaultBgColor = isDark
        ? AppColors.darkSurface
        : Colors.white;

    final defaultBorderColor = isDark
        ? AppColors.darkBorder
        : context.colorBorder;

    final decoration = BoxDecoration(
      color: backgroundColor ?? defaultBgColor,
      borderRadius: BorderRadius.circular(borderRadius ?? AppShapes.radiusXl),
      border: Border.all(
        color: borderColor ?? defaultBorderColor,
      ),
      boxShadow: hasShadow
          ? AppStyles.elevatedShadow(context)
          : null,
    );

    Widget cardContent = Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(AppShapes.radiusLg),
      decoration: decoration,
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: cardContent,
      );
    }

    return cardContent;
  }
}
