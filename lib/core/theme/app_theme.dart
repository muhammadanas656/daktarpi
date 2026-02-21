// lib/core/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_dimens.dart';
import 'app_shapes.dart';

class AppTheme {
  static const scaffoldBackgroundColor = Colors.white;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.scaffoldBackground,

      // Color Scheme
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryGreen,
        primary: AppColors.primaryGreen,
        surface: AppColors.scaffoldBackground,
      ),

      // Typography
      textTheme: GoogleFonts.poppinsTextTheme(),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: AppShapes.lg),
          elevation: AppDimens.elevationNone,
          textStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: GoogleFonts.poppins(color: AppColors.hintText, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: AppShapes.md,
          borderSide: const BorderSide(color: AppColors.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppShapes.md,
          borderSide: const BorderSide(color: AppColors.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppShapes.md,
          borderSide: const BorderSide(color: AppColors.primaryGreen),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(
        0xFF121212,
      ), // Standard dark background
      // Color Scheme
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryGreen,
        brightness: Brightness.dark,
        surface: const Color(0xFF121212),
      ),

      // Typography
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: AppShapes.lg),
          elevation: AppDimens.elevationNone,
          textStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E1E1E), // Darker surface
        hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: AppShapes.md,
          borderSide: const BorderSide(color: Colors.grey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppShapes.md,
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppShapes.md,
          borderSide: const BorderSide(color: AppColors.primaryGreen),
        ),
      ),
    );
  }
}
