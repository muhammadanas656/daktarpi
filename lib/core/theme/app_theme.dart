// lib/core/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // We define the colors here so we can change them easily later
  static const primaryColor = Color(0xFF00C689);
  static const scaffoldBackgroundColor = Colors.white;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,

      // 1. Set the Background Color
      scaffoldBackgroundColor: scaffoldBackgroundColor,

      // 2. Define the Color Scheme
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        // You can add secondary/tertiary colors here if needed
      ),

      // 3. Apply Poppins Font Globally
      // This automatically applies Poppins to all Text widgets in the app
      textTheme: GoogleFonts.poppinsTextTheme(),

      // 4. (Optional) Set Default Button Styles
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}
