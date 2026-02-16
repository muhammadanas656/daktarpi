import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'package:flutter/services.dart';

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
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20); // Premium Radius
    final bool singleLine = maxLines == 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          RichText(
            text: TextSpan(
              text: label!.replaceAll('*', ''),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
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
          const SizedBox(height: 10),
        ],
        Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1C222E).withValues(alpha: 0.05), // Soft Premium Shadow
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          constraints:
              singleLine
                  ? const BoxConstraints(minHeight: 56, maxHeight: 56)
                  : const BoxConstraints(minHeight: 56),
          child: Center(
            child: TextField(
              controller: controller,
              keyboardType:
                  keyboardType ??
                  (isPhone ? TextInputType.phone : TextInputType.text),
              readOnly: readOnly,
              onTap: onTap,
              inputFormatters: inputFormatters,
              enabled: enabled,
              maxLines: maxLines,
              textAlignVertical:
                  singleLine ? TextAlignVertical.center : TextAlignVertical.top,
              cursorColor: AppColors.primaryGreen,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textDark,
                height: 1.1,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textGrey,
                  height: 1.1,
                ),
                filled: true,
                fillColor: enabled ? Colors.white : const Color(0xFFF5F7FA),
                prefixIcon:
                    prefix == null
                        ? null
                        : Padding(
                          padding: const EdgeInsetsDirectional.only(
                            start: 12,
                            end: 4,
                          ),
                          child: prefix,
                        ),
                prefixIconConstraints:
                    prefix == null
                        ? null
                        : const BoxConstraints(minWidth: 0, minHeight: 0),
                suffixIcon: suffixIcon,
                border: OutlineInputBorder(
                  borderRadius: radius,
                  borderSide: const BorderSide(color: AppColors.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: radius,
                  borderSide: const BorderSide(color: AppColors.borderColor),
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
                  borderSide: const BorderSide(color: AppColors.borderColor),
                ),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: singleLine ? 18 : 14,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
