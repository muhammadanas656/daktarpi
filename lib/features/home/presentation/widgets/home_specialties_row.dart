import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../presentation/widgets/app_network_image.dart'; // PRO FIX

class HomeSpecialtiesRow extends StatelessWidget {
  final List<Map<String, dynamic>> specialties;
  final void Function(int id, String name) onSpecialtyTap;

  const HomeSpecialtiesRow({
    super.key,
    required this.specialties,
    required this.onSpecialtyTap,
  });

  Widget _getFallbackIcon(String name) {
    IconData iconData = Icons.medical_services_rounded;
    if (name.toLowerCase().contains('dentist')) iconData = Icons.masks_rounded;
    if (name.toLowerCase().contains('cardio')) {
      iconData = Icons.favorite_rounded;
    }
    if (name.toLowerCase().contains('eye')) {
      iconData = Icons.remove_red_eye_rounded;
    }

    return Icon(iconData, color: const Color(0xFF008FA0), size: 28);
  }

  @override
  Widget build(BuildContext context) {
    if (specialties.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Text("No specialties found"),
      );
    }

    return SizedBox(
      height: 115,
      child: ListView.separated(
        clipBehavior: Clip.none,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        itemCount: specialties.length,
        separatorBuilder: (_, __) => const SizedBox(width: 24),
        itemBuilder: (context, index) {
          final item = specialties[index];
          final name = item['name'] ?? '';
          return GestureDetector(
            onTap: () => onSpecialtyTap(item['id'], name),
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    shape: BoxShape.circle,
                    border:
                        Theme.of(context).brightness == Brightness.dark
                            ? Border.all(color: AppColors.darkBorder)
                            : null,
                    boxShadow: AppStyles.cardShadow(context),
                  ),
                  // PRO FIX: Replaced Image.network with cached variant
                  child:
                      item['icon_url'] != null &&
                              item['icon_url'].toString().isNotEmpty
                          ? AppNetworkImage(
                            imageUrl: item['icon_url'],
                            width: 36,
                            height: 36,
                            circular: true, // PRO FIX: Makes the loading shimmer circular!
                            fit: BoxFit.contain,
                          )
                          : _getFallbackIcon(name),
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  style: AppTextStyles.bodySmall(context).copyWith(
                    fontWeight: FontWeight.w500,
                    color: context.colorTextDark,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
