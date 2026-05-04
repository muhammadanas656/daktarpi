import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_shapes.dart';
import '../../core/theme/app_styles.dart';

class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool isPhone;
  final bool readOnly;
  final VoidCallback? onTap;
  final String? label;
  final Widget? prefix;
  final Widget? suffixIcon;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;

  // RESTORED: Original interaction parameters
  final bool isPassword;
  final bool isEmail;
  final bool? isPasswordVisible;
  final VoidCallback? onVisibilityToggle;
  final bool autofocus;
  final TextCapitalization textCapitalization;
  final TextAlign textAlign;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;

  // PRO FIX: Styling overrides to allow seamless blending in Search Bars
  final Color? fillColor;
  final Color? borderColor;
  final bool hasShadow;

  const AppTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.isPhone = false,
    this.readOnly = false,
    this.onTap,
    this.label,
    this.prefix,
    this.suffixIcon,
    this.inputFormatters,
    this.keyboardType,
    this.maxLines = 1,
    this.enabled = true,
    this.onSubmitted,
    this.fillColor,
    this.borderColor,
    this.hasShadow = true,
    this.isPassword = false,
    this.isEmail = false,
    this.isPasswordVisible,
    this.onVisibilityToggle,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.textAlign = TextAlign.start,
    this.onChanged,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final radius = AppShapes.xl;
    final bool singleLine = maxLines == 1;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text.rich(
            TextSpan(
              text: label!.replaceAll('*', ''),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color:
                    isDark
                        ? Colors.white.withValues(alpha: 0.9)
                        : context.colorTextDark,
              ),
              children: [
                if (label!.contains('*'))
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
        ],
        Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            // PRO FIX: Suppress the glowing shadow in Dark Mode unless requested
            boxShadow: hasShadow ? AppStyles.innerShadow(context) : [],
          ),
          constraints:
              singleLine
                  ? const BoxConstraints(
                    minHeight: AppDimens.fieldHeight,
                    maxHeight: AppDimens.fieldHeight,
                  )
                  : const BoxConstraints(minHeight: AppDimens.fieldHeight),
          child: Center(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType:
                  keyboardType ??
                  (isPhone
                      ? TextInputType.phone
                      : (isEmail
                          ? TextInputType.emailAddress
                          : TextInputType.text)),
              readOnly: readOnly,
              onTap: onTap,
              onSubmitted: onSubmitted,
              onChanged: onChanged,
              autofocus: autofocus,
              textCapitalization: textCapitalization,
              textAlign: textAlign,
              obscureText: isPassword && !(isPasswordVisible ?? false),
              inputFormatters: inputFormatters,
              enabled: enabled,
              maxLines: maxLines,
              textAlignVertical:
                  singleLine ? TextAlignVertical.center : TextAlignVertical.top,
              cursorColor: AppColors.primaryGreen,
              style: TextStyle(
                fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                // PRO FIX: Adaptive text contrast inside the field
                color: isDark ? Colors.white : context.colorTextDark,
                height: 1.1,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(
                  fontFamily:
                      Theme.of(context).textTheme.bodyMedium?.fontFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: isDark ? Colors.white54 : context.colorTextGrey,
                  height: 1.1,
                ),
                filled: true,
                // PRO FIX: Context-aware background fill
                fillColor:
                    fillColor ??
                    (enabled
                        ? (isDark
                            ? Theme.of(context).colorScheme.surface
                            : Colors.white)
                        : (isDark
                            ? AppColors.darkScaffold
                            : const Color(0xFFF5F7FA))),
                prefixIcon:
                    prefix == null
                        ? null
                        : Padding(
                          padding: const EdgeInsetsDirectional.only(
                            start: AppDimens.spaceMd,
                            end: AppDimens.space2xs,
                          ),
                          child: prefix,
                        ),
                prefixIconConstraints:
                    prefix == null
                        ? null
                        : const BoxConstraints(minWidth: 0, minHeight: 0),
                suffixIcon:
                    suffixIcon ??
                    (isPassword
                        ? IconButton(
                          icon: Icon(
                            (isPasswordVisible ?? false)
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color:
                                isDark
                                    ? Colors.white70
                                    : context.colorTextLight,
                            size: 20,
                          ),
                          onPressed: onVisibilityToggle,
                        )
                        : null),
                // PRO FIX: Context-aware seamless borders
                border: OutlineInputBorder(
                  borderRadius: radius,
                  borderSide: BorderSide(
                    color:
                        borderColor ??
                        (isDark
                            ? const Color(0xFF2A3441)
                            : context.colorBorder),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: radius,
                  borderSide: BorderSide(
                    color:
                        borderColor ??
                        (isDark
                            ? const Color(0xFF2A3441)
                            : context.colorBorder),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: radius,
                  borderSide: const BorderSide(
                    color: AppColors.primaryGreen,
                    width: 1.3,
                  ),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: radius,
                  borderSide: BorderSide(
                    color:
                        borderColor ??
                        (isDark
                            ? const Color(0xFF2A3441)
                            : context.colorBorder),
                  ),
                ),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceLg,
                  vertical:
                      singleLine
                          ? AppDimens.spaceLgPlus
                          : AppDimens.spaceMdPlus,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
