import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_shapes.dart';
import '../../core/theme/app_text_styles.dart';
import 'app_network_image.dart';

class DoctorListCard extends StatelessWidget {
  final int id;
  final String name;
  final String specialty;
  final String rating;
  final String views;
  final String? imageUrl;
  final bool isFavorite;
  final VoidCallback onFavoriteTap;
  final VoidCallback onCardTap;
  final String heroTagPrefix;
  final Widget? trailingWidget;

  const DoctorListCard({
    super.key,
    required this.id,
    required this.name,
    required this.specialty,
    required this.rating,
    required this.views,
    required this.imageUrl,
    required this.isFavorite,
    required this.onFavoriteTap,
    required this.onCardTap,
    this.heroTagPrefix = 'doctor-list-',
    this.trailingWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppShapes.xl,
        border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1C222E).withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppShapes.xl,
        child: InkWell(
          onTap: onCardTap,
          borderRadius: AppShapes.lg,
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Hero(
                  tag: '$heroTagPrefix$id',
                  child: ClipRRect(
                    borderRadius: AppShapes.md,
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: AppNetworkImage(
                        imageUrl: imageUrl,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        fallbackIconSize: 40,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimens.spaceLg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: AppTextStyles.h3.copyWith(fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          trailingWidget ??
                              Material(
                                color: const Color(0xFFF2F4F7),
                                borderRadius: AppShapes.md,
                                child: InkWell(
                                  onTap: onFavoriteTap,
                                  borderRadius: AppShapes.md,
                                  child: Container(
                                    padding: const EdgeInsets.all(
                                      AppDimens.spaceXs,
                                    ),
                                    child: Icon(
                                      isFavorite
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color:
                                          isFavorite
                                              ? AppColors.dangerRed
                                              : const Color(0xFF9CA3AF),
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                        ],
                      ),
                      const SizedBox(height: AppDimens.space2xs),
                      Text(
                        specialty,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppDimens.spaceXs),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            rating,
                            style: AppTextStyles.bodyBold.copyWith(
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.visibility_outlined,
                            color: Color(0xFF9FA8DA),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            views,
                            style: AppTextStyles.bodySmall.copyWith(
                              fontSize: 12,
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
