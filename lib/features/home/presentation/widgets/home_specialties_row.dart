import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

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
    if (name.toLowerCase().contains('dentist')) {
      iconData = Icons.masks_rounded;
    }
    if (name.toLowerCase().contains('cardio')) {
      iconData = Icons.favorite_rounded;
    }
    if (name.toLowerCase().contains('eye')) {
      iconData = Icons.remove_red_eye_rounded;
    }
    return Icon(iconData, color: Color(0xFF008FA0), size: 28);
  }

  @override
  Widget build(BuildContext context) {
    if (specialties.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Text("No specialties found"),
      );
    }

    return SizedBox(
      height: 100,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        itemCount: specialties.length,
        separatorBuilder: (_, __) => SizedBox(width: 24),
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
                    // PRO FIX: Dynamic surface color
                    color: Theme.of(context).colorScheme.surface, 
                    shape: BoxShape.circle,
                    // PRO FIX: Add subtle border in Dark Mode, disable shadow
                    border: Theme.of(context).brightness == Brightness.dark 
                        ? Border.all(color: AppColors.darkBorder) 
                        : null,
                    boxShadow: Theme.of(context).brightness == Brightness.dark ? [] : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: item['icon_url'] != null
                      ? Image.network(item['icon_url'])
                      : _getFallbackIcon(name),
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  style: AppTextStyles.bodySmall(context).copyWith(
                    fontWeight: FontWeight.w500,
                    // PRO FIX: Ensure text stays visible on dark backgrounds
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
