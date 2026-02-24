import 'package:flutter/material.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';

class NavigationHelper {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No navigation applications found on this device.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (BuildContext ctx) {
          return SafeArea(
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Navigate to $title',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...availableMaps.map((map) {
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 4,
                        ),
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: SvgPicture.string(
                            map.icon,
                            width: 32,
                            height: 32,
                          ),
                        ),
                        title: Text(
                          map.mapName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: Colors.grey,
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          map.showDirections(
                            destination: Coords(latitude, longitude),
                            destinationTitle: title,
                            directionsMode: DirectionsMode.driving,
                          );
                        },
                      );
                    }),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error launching maps: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}
