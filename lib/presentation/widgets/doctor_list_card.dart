import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_shapes.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_styles.dart'; // PRO FIX: Imported AppStyles
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // PRO FIX: RepaintBoundary forces Flutter to cache this entire complex shadowed card as a flat raster graphic.
    // This utterly eliminates GPU recalculations during 120fps fast-scrolling!
    return RepaintBoundary(
      child: Container(
      // PRO FIX: Instantly adapts to Dark Mode (removes shadow, shifts to Deep Slate)
      decoration: AppStyles.surfaceCard(context, borderRadius: AppShapes.xl),
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
                              style: AppTextStyles.h3(context).copyWith(fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          trailingWidget ??
                              Material(
                                // PRO FIX: Context-aware favorite button background
                                color: isDark 
                                    ? AppColors.darkBorder 
                                    : const Color(0xFFF2F4F7),
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
                                      color: isFavorite
                                          ? AppColors.dangerRed
                                          : (isDark ? AppColors.darkTextSecondary : const Color(0xFF9CA3AF)),
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
                        style: AppTextStyles.bodySmall(context).copyWith(
                          color: context.colorTextLight, // Already context-aware!
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
                            style: AppTextStyles.bodyBold(context).copyWith(
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.visibility_outlined,
                            // PRO FIX: Shifted to a color that works on both light and dark
                            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9FA8DA),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            views,
                            style: AppTextStyles.bodySmall(context).copyWith(
                              fontSize: 12,
                              color: context.colorTextLight,
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
    ));
  }
}
