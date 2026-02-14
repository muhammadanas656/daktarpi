import 'package:flutter/material.dart';
import '../../core/theme/app_styles.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

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
  });

  @override
  Widget build(BuildContext context) {
    // 1. Calculate star values
    final double ratingVal = double.tryParse(rating) ?? 0.0;
    final int fullStars = ratingVal.floor();
    final bool hasHalfStar = (ratingVal - fullStars) >= 0.5;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20), // Premium Radius
        border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1C222E).withValues(alpha: 0.06), // Soft Shadow
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onCardTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- IMAGE ---
                Hero(
                  tag: 'doctor-hero-$id',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: (imageUrl != null && imageUrl!.isNotEmpty)
                          ? Image.network(
                              imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                color: Colors.grey[200],
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.grey,
                                  size: 40,
                                ),
                              ),
                            )
                          : Container(
                              color: Colors.grey[200],
                              child: const Icon(
                                Icons.person,
                                color: Colors.grey,
                                size: 40,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // --- INFO COLUMN ---
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
                          GestureDetector(
                            onTap: onFavoriteTap,
                            child: Padding(
                              padding: const EdgeInsets.only(
                                left: 8.0,
                                bottom: 4.0,
                              ),
                              child: Icon(
                                isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: isFavorite ? AppColors.dangerRed : Colors.grey,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        specialty,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),

                      // --- DYNAMIC STAR ROW ---
                      Row(
                        children: [
                          ...List.generate(5, (index) {
                            if (index < fullStars) {
                              return const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 14,
                              );
                            } else if (index == fullStars && hasHalfStar) {
                              return const Icon(
                                Icons.star_half,
                                color: Colors.amber,
                                size: 14,
                              );
                            } else {
                              return Icon(
                                Icons.star_border,
                                color: Colors.grey[300],
                                size: 14,
                              );
                            }
                          }),
                          const SizedBox(width: 8),
                          Flexible(
                            child: RichText(
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: rating,
                                    style: AppTextStyles.bodyBold.copyWith(
                                      fontSize: 12,
                                    ),
                                  ),
                                  TextSpan(
                                    text: "  ($views views)",
                                    style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                                  ),
                                ],
                              ),
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
