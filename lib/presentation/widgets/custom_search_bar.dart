import 'package:flutter/material.dart';
import '../../core/theme/app_styles.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_shapes.dart';

class CustomSearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final bool readOnly;
  final VoidCallback? onTap;
  final String hintText;
  final VoidCallback? onClear;
  final bool showClearIcon;

  const CustomSearchBar({
    super.key,
    this.controller,
    this.readOnly = false,
    this.onTap,
    this.hintText = "Search",
    this.onClear,
    this.showClearIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppShapes.lg,
        border: Border.all(color: AppColors.borderColor),
        boxShadow: AppStyles.cardShadow,
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        style: const TextStyle(
          color: AppColors.textDark,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 14),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.textLight,
            size: AppDimens.iconLg,
          ),
          suffixIcon:
              showClearIcon && onClear != null
                  ? IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textLight,
                      size: AppDimens.iconLg,
                    ),
                    onPressed: onClear,
                  )
                  : (readOnly
                      ? const Icon(
                        Icons.close_rounded,
                        color: AppColors.textLight,
                        size: AppDimens.iconLg,
                      )
                      : null), // Keep legacy icon for Home if needed, or remove
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: AppDimens.spaceLg,
          ),
        ),
      ),
    );
  }
}
