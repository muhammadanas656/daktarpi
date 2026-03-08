import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import 'app_text_field.dart';

class CustomSearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final bool readOnly;
  final VoidCallback? onTap;
  final String hintText;
  final VoidCallback? onClear;
  final bool showClearIcon;
  final ValueChanged<String>? onSubmitted;

  const CustomSearchBar({
    super.key,
    this.controller,
    this.readOnly = false,
    this.onTap,
    this.hintText = "Search",
    this.onClear,
    this.showClearIcon = false,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Ensure we always have a controller for AppTextField
    final safeController = controller ?? TextEditingController();

    return AppTextField(
      controller: safeController,
      readOnly: readOnly,
      onTap: onTap,
      onSubmitted: onSubmitted,
      hintText: hintText,
      // PRO FIX: Translucent styling destroys the "overlayed sticker" effect!
      fillColor: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.white,
      borderColor:
          isDark ? Colors.white.withValues(alpha: 0.1) : context.colorBorder,
      hasShadow: !isDark,
      prefix: Icon(
        Icons.search_rounded,
        color: isDark ? Colors.white70 : context.colorTextLight,
        size: AppDimens.iconLg,
      ),
      suffixIcon:
          showClearIcon && onClear != null
              ? IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  color: isDark ? Colors.white70 : context.colorTextLight,
                  size: AppDimens.iconLg,
                ),
                onPressed: onClear,
              )
              : (readOnly
                  ? Icon(
                    Icons.close_rounded,
                    color: isDark ? Colors.white70 : context.colorTextLight,
                    size: AppDimens.iconLg,
                  )
                  : null),
    );
  }
}
