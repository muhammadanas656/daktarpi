import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_shapes.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_styles.dart';
import '../../features/profile/presentation/profile_notifier.dart';
import 'app_network_image.dart';

class FeaturedDoctorCard extends StatelessWidget {
  final int id;
  final String name;
  final String specialty;
  final String rating;
  final String views;
  final String price;
  final String? imageUrl;
  final bool isFavorite;
  final VoidCallback onFavoriteTap;
  final VoidCallback onCardTap;
  final String heroTagPrefix;

  const FeaturedDoctorCard({
    super.key,
    required this.id,
    required this.name,
    required this.specialty,
    required this.rating,
    required this.views,
    required this.price,
    required this.imageUrl,
    required this.isFavorite,
    required this.onFavoriteTap,
    required this.onCardTap,
    this.heroTagPrefix = 'doctor-featured-',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark; // PRO FIX

    return Container(
      // PRO FIX: Instantly adapts to Dark Mode (removes white background & glowing shadow)
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
                              style: AppTextStyles.h3(
                                context,
                              ).copyWith(fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: onFavoriteTap,
                            child: Padding(
                              padding: const EdgeInsets.only(
                                left: AppDimens.spaceXs,
                                bottom: AppDimens.space2xs,
                              ),
                              child: Icon(
                                isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color:
                                    isFavorite
                                        ? AppColors.dangerRed
                                        // PRO FIX: Dimmer heart icon for Dark Mode
                                        : (isDark
                                            ? AppColors.darkTextSecondary
                                            : Colors.grey),
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimens.space2xs),
                      Text(
                        specialty,
                        style: AppTextStyles.bodySmall(
                          context,
                        ).copyWith(color: context.colorTextLight),
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
                            style: AppTextStyles.bodyBold(
                              context,
                            ).copyWith(fontSize: 12),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.visibility_outlined,
                            // PRO FIX: Context-aware icon color for visibility
                            color:
                                isDark
                                    ? AppColors.darkTextSecondary
                                    : const Color(0xFF9FA8DA),
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
                          const Spacer(),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text:
                                      "${ProfileNotifier.instance.currencySymbol} ",
                                  style: AppTextStyles.bodyBold(
                                    context,
                                  ).copyWith(
                                    color: AppColors.primaryGreen,
                                    fontSize: 14,
                                  ),
                                ),
                                TextSpan(
                                  text: "$price/hour",
                                  style: AppTextStyles.bodySmall(
                                    context,
                                  ).copyWith(
                                    color: context.colorTextLight,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
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
