import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_dimens.dart';
import 'app_shapes.dart';

enum VolumetricTier { 
  base,     // For root tabs (Home, Doctors, etc.)
  elevated  // For pushed detail screens (Booking, Settings, etc.)
}

class AppStyles {
  static BoxDecoration ambientVolumetricTheme(BuildContext context, {VolumetricTier tier = VolumetricTier.elevated}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.primaryGreen;
    
    // The secret to 2050 design: A secondary light source to create "Atmosphere"
    final accent = isDark ? const Color(0xFF00E5FF) : const Color(0xFF00B0FF); // Deep Cyan

    final double baseAlpha = tier == VolumetricTier.elevated ? (isDark ? 0.18 : 0.04) : (isDark ? 0.05 : 0.015);
    final Color baseCanvas = isDark ? const Color(0xFF050608) : const Color(0xFFFAFAFC); // OLED-friendly deep void or crisp pearl

    return BoxDecoration(
      color: baseCanvas,
      gradient: RadialGradient(
        // An elliptical stretch makes the light wrap around the top of the phone
        center: const Alignment(-0.5, -1.2), 
        radius: tier == VolumetricTier.elevated ? 2.8 : 3.5,
        colors: [
          primary.withValues(alpha: baseAlpha),               // Core glow
          accent.withValues(alpha: baseAlpha * 0.4),          // Secondary atmospheric bleed
          baseCanvas.withValues(alpha: 0.0),                  // Fade into the void
        ],
        // The multi-stop transition creates physical light decay
        stops: const [0.0, 0.45, 1.0], 
      ),
    );
  }
  // PRO FIX: Dynamic Gradient that shifts to deep slate in dark mode
  static LinearGradient pageGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return isDark
        ? const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.darkScaffold, AppColors.darkScaffold],
        )
        : const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.lightGreenBg,
            Colors.white,
            Colors.white,
            Color(0xFFE8F5E9),
          ],
          stops: [0.0, 0.3, 0.7, 1.0],
        );
  }

  static EdgeInsets pagePadding = const EdgeInsets.symmetric(
    horizontal: AppDimens.pageHorizontalPadding,
    vertical: AppDimens.pageVerticalPadding,
  );

  // PRO FIX: Shadows automatically turn off in Dark Mode
  static List<BoxShadow> cardShadow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isDark) return []; // No shadows on dark surfaces!

    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ];
  }

  static final BorderRadius cardRadius = AppShapes.lg;

  // Premium, floating shadow for modals, bottom sheets, and floating cards
  static List<BoxShadow> elevatedShadow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) return [];
    
    return [
      BoxShadow(
        color: Color(0xFF1C222E).withValues(alpha: 0.06),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ];
  }

  // Colored shadow that adapts based on dark mode. Used for Primary buttons/banners
  static List<BoxShadow> primaryShadow(BuildContext context, Color color, {double alpha = 0.3}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) return [];

    return [
      BoxShadow(
        color: color.withValues(alpha: alpha),
        blurRadius: 15,
        offset: const Offset(0, 8),
      ),
    ];
  }

  // Intense 3D shadow for the 3D drawer effect
  static List<BoxShadow> drawerShadow(BuildContext context) {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.3),
        blurRadius: 40,
        offset: const Offset(-30, 30),
      ),
    ];
  }

  // Soft shadow for inner elements like TextFields or Tabs
  static List<BoxShadow> innerShadow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) return [];

    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];
  }

  // PRO FIX: Context-aware surface cards
  static BoxDecoration surfaceCard(
    BuildContext context, {
    BorderRadius? borderRadius,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BoxDecoration(
      color: Theme.of(context).colorScheme.surface, // Adapts automatically
      borderRadius: borderRadius ?? cardRadius,
      border: Border.all(
        color: isDark ? AppColors.darkBorder : AppColors.borderColor,
      ),
      boxShadow: cardShadow(context),
    );
  }
}
