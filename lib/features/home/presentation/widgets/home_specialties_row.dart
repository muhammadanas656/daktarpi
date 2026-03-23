import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../presentation/widgets/app_network_image.dart';

class HomeSpecialtiesRow extends StatelessWidget {
  final List<Map<String, dynamic>> specialties;
  final void Function(int id, String name, String? iconUrl) onSpecialtyTap;

  const HomeSpecialtiesRow({
    super.key,
    required this.specialties,
    required this.onSpecialtyTap,
  });

  Widget _getFallbackIcon(String name) {
    IconData iconData = Icons.medical_services_rounded;
    if (name.toLowerCase().contains('dentist')) iconData = Icons.masks_rounded;
    if (name.toLowerCase().contains('cardio')) iconData = Icons.favorite_rounded;
    if (name.toLowerCase().contains('eye')) iconData = Icons.remove_red_eye_rounded;

    // PRO FIX: Solid Primary Green for the crisp, modern look
    return Icon(iconData, color: AppColors.primaryGreen, size: 28);
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
        separatorBuilder: (_, __) => const SizedBox(width: 16), 
        itemBuilder: (context, index) {
          final item = specialties[index];
          final name = item['name'] ?? '';

          return GestureDetector(
            onTap: () => onSpecialtyTap(item['id'], name, item['icon_url']?.toString()),
            child: SizedBox(
              width: 83, 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      // PRO FIX: Soft-Tint Background (No Borders, No Shadows!)
                      color: AppColors.primaryGreen.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: item['icon_url'] != null && item['icon_url'].toString().isNotEmpty
                        ? SizedBox(
                            width: 32,
                            height: 32,
                            child: AppNetworkImage(
                              imageUrl: item['icon_url'],
                              circular: false,
                              fit: BoxFit.contain,
                            ),
                          )
                        : _getFallbackIcon(name),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 36,
                    child: OverflowBox(
                      maxWidth: 92,
                      maxHeight: 36,
                      child: Text(
                        name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall(context).copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.colorTextDark,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}