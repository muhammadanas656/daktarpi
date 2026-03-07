import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_shapes.dart';
import 'package:flutter/services.dart';

class AppTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String hintText;
  final bool isPhone;
  final bool isPassword;
  final bool readOnly;
  final VoidCallback? onTap;
  final String? label;
  final Widget? prefix;
  final Widget? suffixIcon;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool enabled;
  final bool isEmail;
  final bool? isPasswordVisible;
  final VoidCallback? onVisibilityToggle;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextAlign textAlign;
  final TextCapitalization textCapitalization;
  final bool autofocus;

  const AppTextField({
    super.key,
    this.controller,
    required this.hintText,
    this.isPhone = false,
    this.isPassword = false,
    this.readOnly = false,
    this.onTap,
    this.label,
    this.prefix,
    this.suffixIcon,
    this.inputFormatters,
    this.keyboardType,
    this.maxLines = 1,
    this.enabled = true,
    this.isEmail = false,
    this.isPasswordVisible,
    this.onVisibilityToggle,
    this.onChanged,
    this.onSubmitted,
    this.textAlign = TextAlign.start,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _internalIsVisible = false;

  @override
  Widget build(BuildContext context) {
    final radius = AppShapes.xl;
    final bool singleLine = widget.maxLines == 1;
    final isDark = Theme.of(context).brightness == Brightness.dark; // PRO FIX
    final isVisible = widget.isPasswordVisible ?? _internalIsVisible;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          RichText(
            text: TextSpan(
              text: widget.label!.replaceAll('*', ''),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.colorTextDark,
              ),
              children: [
                if (widget.label!.contains('*'))
                  TextSpan(
                    text: ' *',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: AppDimens.spaceSm),
        ],
        Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            // PRO FIX: Remove the hardcoded shadow in Dark Mode
            boxShadow:
                isDark
                    ? []
                    : [
                      BoxShadow(
                        color: const Color(0xFF1C222E).withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
          ),
          constraints:
              singleLine
                  ? BoxConstraints(
                    minHeight: AppDimens.fieldHeight,
                    maxHeight: AppDimens.fieldHeight,
                  )
                  : BoxConstraints(minHeight: AppDimens.fieldHeight),
          child: Center(
            child: TextField(
              controller: widget.controller,
              autofocus: widget.autofocus,
              obscureText: widget.isPassword && !isVisible,
              keyboardType:
                  widget.keyboardType ??
                  (widget.isEmail
                      ? TextInputType.emailAddress
                      : (widget.isPhone
                          ? TextInputType.phone
                          : TextInputType.text)),
              readOnly: widget.readOnly,
              onTap: widget.onTap,
              inputFormatters: widget.inputFormatters,
              enabled: widget.enabled,
              maxLines: widget.isPassword ? 1 : widget.maxLines,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              textAlign: widget.textAlign,
              textCapitalization: widget.textCapitalization,
              textAlignVertical:
                  singleLine ? TextAlignVertical.center : TextAlignVertical.top,
              cursorColor: AppColors.primaryGreen,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: context.colorTextDark,
                height: 1.1,
              ),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: context.colorTextGrey,
                  height: 1.1,
                ),
                filled: true,
                // PRO FIX: Dynamic background colors for the text input
                fillColor:
                    widget.enabled
                        ? Theme.of(context).colorScheme.surface
                        : (isDark
                            ? AppColors.darkScaffold
                            : const Color(0xFFF5F7FA)),
                prefixIcon:
                    widget.prefix == null
                        ? null
                        : Padding(
                          padding: EdgeInsetsDirectional.only(
                            start: AppDimens.spaceMd,
                            end: AppDimens.space2xs,
                          ),
                          child: widget.prefix,
                        ),
                prefixIconConstraints:
                    widget.prefix == null
                        ? null
                        : BoxConstraints(minWidth: 0, minHeight: 0),
                suffixIcon:
                    widget.isPassword
                        ? IconButton(
                          icon: Icon(
                            isVisible ? Icons.visibility : Icons.visibility_off,
                            color: const Color(0xFFC4C4C4),
                            size: 20,
                          ),
                          onPressed: () {
                            if (widget.onVisibilityToggle != null) {
                              widget.onVisibilityToggle!();
                            } else {
                              setState(
                                () => _internalIsVisible = !_internalIsVisible,
                              );
                            }
                          },
                        )
                        : widget.suffixIcon,
                border: OutlineInputBorder(
                  borderRadius: radius,
                  // PRO FIX: Dynamic border color removes the light halo
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkBorder : context.colorBorder,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: radius,
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkBorder : context.colorBorder,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: radius,
                  borderSide: BorderSide(
                    color: AppColors.primaryGreen,
                    width: 1.3,
                  ),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: radius,
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkBorder : context.colorBorder,
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
