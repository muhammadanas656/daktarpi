import 'package:flutter/material.dart';

class AppColors {
  // --- Light Theme Colors ---
  static const Color primaryGreen = Color(0xFF00C689);
  static const Color textDark = Color(0xFF1A1A1A);
  static const Color textLight = Color(0xFF626F8D);
  static const Color borderColor = Color(0xFFE0E0E0);
  static const Color dangerRed = Color(0xFFE53935);
  static const Color cyanHeader = Color(0xFFE0F7FA);
  static const Color bgColor = Color(0xFFFBFBFB);
  static const Color scaffoldBackground = bgColor;
  static const Color lightGreenBg = Color(0xFFE0F7FA);
  static const Color hintText = Color(0xFFC4C4C4);
  static const Color textGrey = Color(0xFF9E9E9E);
  static const Color infoBlue = Color(0xFF2979FF);

  // --- Premium Dark Theme Colors ("Deep Medical Slate") ---
  static const Color darkScaffold = Color(0xFF0F172A); // Slate 900
  static const Color darkSurface = Color(
    0xFF1E293B,
  ); // Slate 800 (Elevated cards)
  static const Color darkBorder = Color(0xFF334155); // Slate 700
  static const Color deepMedicalSlate = Color(0xFF1E2833);
  static const Color darkTextPrimary = Color(
    0xFFF8FAFC,
  ); // Slate 50 (Off-white, no glare)
  static const Color darkTextSecondary = Color(
    0xFF94A3B8,
  ); // Slate 400 (Cool grey)
}

extension AppThemeColors on BuildContext {
  Color get colorPrimaryGreen => AppColors.primaryGreen;
  Color get colorTextDark =>
      Theme.of(this).brightness == Brightness.dark
          ? AppColors.darkTextPrimary
          : AppColors.textDark;
  Color get colorTextLight =>
      Theme.of(this).brightness == Brightness.dark
          ? AppColors.darkTextSecondary
          : AppColors.textLight;
  Color get colorBorder =>
      Theme.of(this).brightness == Brightness.dark
          ? AppColors.darkBorder
          : AppColors.borderColor;
  Color get colorDangerRed => AppColors.dangerRed;
  Color get colorCyanHeader =>
      Theme.of(this).brightness == Brightness.dark
          ? AppColors.darkScaffold
          : AppColors.cyanHeader;
  Color get colorBg =>
      Theme.of(this).brightness == Brightness.dark
          ? AppColors.darkScaffold
          : AppColors.bgColor;
  Color get colorScaffoldBackground =>
      Theme.of(this).brightness == Brightness.dark
          ? AppColors.darkScaffold
          : AppColors.scaffoldBackground;
  Color get colorLightGreenBg =>
      Theme.of(this).brightness == Brightness.dark
          ? AppColors.darkSurface
          : AppColors.lightGreenBg;
  Color get colorHintText =>
      Theme.of(this).brightness == Brightness.dark
          ? AppColors.darkTextSecondary
          : AppColors.hintText;
  Color get colorTextGrey =>
      Theme.of(this).brightness == Brightness.dark
          ? AppColors.darkTextSecondary
          : AppColors.textGrey;
  Color get colorInfoBlue => AppColors.infoBlue;
}
