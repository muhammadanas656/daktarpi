import 'package:flutter/material.dart';
import 'package:map_launcher/map_launcher.dart';
// Notice we completely removed flutter_svg to avoid the rendering crash!

import '../theme/app_colors.dart';
import '../../presentation/widgets/custom_snackbar.dart';
import '../../presentation/widgets/app_floating_dialog.dart';

class NavigationHelper {
  
  // THE FIX: Smart Mapper that replaces broken SVGs with beautiful glowing icons
  static IconData _getPremiumIcon(String mapName) {
    final name = mapName.toLowerCase();
    if (name.contains('google')) return Icons.pin_drop_rounded;
    if (name.contains('apple')) return Icons.explore_rounded;
    if (name.contains('waze')) return Icons.navigation_rounded;
    return Icons.map_rounded; // The perfect, generic placeholder!
  }

  static Color _getPremiumColor(String mapName) {
    final name = mapName.toLowerCase();
    if (name.contains('google')) return const Color(0xFFEA4335);
    if (name.contains('apple')) return const Color(0xFF007AFF);
    if (name.contains('waze')) return const Color(0xFF1E90FF);
    return AppColors.primaryGreen; // Matches your app's theme as a fallback
  }

  static Future<void> showMapOptions({
    required BuildContext context,
    required double latitude,
    required double longitude,
    required String title,
    String? description,
  }) async {
    try {
      final availableMaps = await MapLauncher.installedMaps;

      if (!context.mounted) return;

      if (availableMaps.isEmpty) {
        CustomSnackbar.showError(
          context,
          'No navigation applications found on this device.',
        );
        return;
      }

      await showDialog(
        context: context,
        builder: (BuildContext ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          
          return AppFloatingDialog(
            headerIcon: Icons.map_rounded,
            iconColor: AppColors.infoBlue,
            title: "Get Directions",
            description: "Choose your preferred maps application to navigate to $title.",
            content: Column(
              mainAxisSize: MainAxisSize.min,
              // Dynamically render installed maps using the premium mapped icons
              children: availableMaps.map((map) {
                final iconData = _getPremiumIcon(map.mapName);
                final iconColor = _getPremiumColor(map.mapName);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.pop(ctx);
                      map.showDirections(
                        destination: Coords(latitude, longitude),
                        destinationTitle: title,
                        directionsMode: DirectionsMode.driving,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
                        boxShadow: isDark ? [] : [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
                        ],
                      ),
                      child: Row(
                        children: [
                          // THE FIX: The beautiful circular colored icon background!
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(iconData, color: iconColor, size: 20),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              map.mapName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : AppColors.textDark,
                              ),
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios_rounded, color: isDark ? Colors.white30 : Colors.black26, size: 14),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            actions: SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                ),
                child: Text(
                  "Cancel", 
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54, 
                    fontWeight: FontWeight.w700, 
                    fontSize: 16
                  )
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (context.mounted) {
        CustomSnackbar.showError(context, 'Error launching maps: $e');
      }
    }
  }
}