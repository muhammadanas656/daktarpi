import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../presentation/widgets/app_network_image.dart';

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
        // The uniform visual gap between items
        separatorBuilder: (_, __) => const SizedBox(width: 16), 
        itemBuilder: (context, index) {
          final item = specialties[index];
          final name = item['name'] ?? '';

          return GestureDetector(
            onTap: () => onSpecialtyTap(item['id'], name),
            child: SizedBox(
              // 1. PHYSICAL LAYOUT: Locks the circles so they never spread apart awkwardly
              width: 83, 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      shape: BoxShape.circle,
                      border: Theme.of(context).brightness == Brightness.dark
                          ? Border.all(color: AppColors.darkBorder)
                          : null,
                      boxShadow: AppStyles.cardShadow(context),
                    ),
                    child: item['icon_url'] != null &&
                            item['icon_url'].toString().isNotEmpty
                        ? SizedBox(
                            width: 35,
                            height: 35,
                            child: AppNetworkImage(
                              imageUrl: item['icon_url'],
                              circular: false,
                              fit: BoxFit.contain,
                            ),
                          )
                        : _getFallbackIcon(name),
                  ),
                  const SizedBox(height: 8),
                  
                  // 2. DYNAMIC OVERFLOW: Text stays full size and naturally bleeds into 
                  // the invisible margins without disrupting the circle layout!
                  SizedBox(
                    height: 36, // Explicit height for exactly 2 lines of text
                    child: OverflowBox(
                      maxWidth: 92, // Text gets 92px of breathing room (no shrinking!)
                      maxHeight: 36,
                      child: Text(
                        name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis, // Softly adds "..." if it's absurdly long
                        style: AppTextStyles.bodySmall(context).copyWith(
                          fontWeight: FontWeight.w500,
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