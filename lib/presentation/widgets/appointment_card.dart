import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_shapes.dart';

import '../../core/theme/app_text_styles.dart';

class AppointmentCard extends StatelessWidget {
  final String name;
  final String specialty;
  final String date;
  final String time;
  final String imageUrl;
  final VoidCallback onTap;
  final VoidCallback onMoreTap;

  const AppointmentCard({
    super.key,
    required this.name,
    required this.specialty,
    required this.date,
    required this.time,
    required this.imageUrl,
    required this.onTap,
    required this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onMoreTap,
      child: Container(
        padding: const EdgeInsets.all(AppDimens.spaceXl),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppShapes.xl, // Premium Radius
          border: Border.all(
            color: AppColors.borderColor.withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(
                0xFF1C222E,
              ).withValues(alpha: 0.06), // Soft Shadow
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Avatar
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    borderRadius: AppShapes.lg,
                    color: Colors.grey[100],
                    image:
                        imageUrl.isNotEmpty
                            ? DecorationImage(
                              image: NetworkImage(imageUrl),
                              fit: BoxFit.cover,
                            )
                            : null,
                  ),
                  child:
                      imageUrl.isEmpty
                          ? const Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.grey,
                          )
                          : null,
                ),
                const SizedBox(width: AppDimens.spaceLg),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppTextStyles.h3.copyWith(fontSize: 18),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppDimens.space2xs),
                      Text(
                        specialty,
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textLight,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // Action Button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onMoreTap,
                    borderRadius: AppShapes.pill,
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimens.spaceXs),
                      child: Icon(Icons.more_vert, color: AppColors.textLight),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceLg),

            // Date & Time Row
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(Icons.calendar_today_outlined, date),
                ),
                Expanded(
                  child: _buildInfoItem(
                    Icons.access_time_rounded,
                    time,
                    alignRight: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text, {bool alignRight = false}) {
    return Row(
      mainAxisAlignment:
          alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: AppDimens.iconMd,
          color: AppColors.textGrey,
        ), // Slightly larger icon
        const SizedBox(width: AppDimens.spaceXs),
        Flexible(
          child: Text(
            text,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textDark, // Darker text for better readability
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
