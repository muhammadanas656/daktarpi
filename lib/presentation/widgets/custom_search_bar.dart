import 'package:flutter/material.dart';
import '../../core/theme/app_styles.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_shapes.dart';
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
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface, // PRO FIX
        borderRadius: AppShapes.lg,
        border: Border.all(color: context.colorBorder),
        boxShadow: AppStyles.cardShadow(context), // PRO FIX
      ),
      child: AppTextField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        onSubmitted: onSubmitted,
        hintText: hintText,
        prefix: Icon(
          Icons.search_rounded,
          color: context.colorTextLight,
          size: AppDimens.iconLg,
        ),
        suffixIcon:
            showClearIcon && onClear != null
                ? IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: context.colorTextLight,
                    size: AppDimens.iconLg,
                  ),
                  onPressed: onClear,
                )
                : (readOnly
                    ? Icon(
                      Icons.close_rounded,
                      color: context.colorTextLight,
                      size: AppDimens.iconLg,
                    )
                    : null), // Keep legacy icon for Home if needed, or remove
      ),
    );
  }
}
