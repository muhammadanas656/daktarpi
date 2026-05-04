import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_routes.dart';
import '../../core/theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import 'app_network_image.dart';

class HomePopularDoctorCard extends StatelessWidget {
  final int index;
  final int id;
  final String name;
  final String specialty;
  final String rating;
  final String? imageUrl;
  final bool isHighlighted;
  final Color? customBorderColor;
  final Widget? customBadgeOverlay;

  const HomePopularDoctorCard({
    super.key,
    required this.index,
    required this.id,
    required this.name,
    required this.specialty,
    required this.rating,
    required this.imageUrl,
    this.isHighlighted = false,
    this.customBorderColor,
    this.customBadgeOverlay,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveBorderColor =
        customBorderColor ?? (isHighlighted ? AppColors.primaryGreen : null);

    final double numericRating = double.tryParse(rating) ?? 0.0;
    final bool hasRating = numericRating > 0.0;

    return RepaintBoundary(
      child: Container(
        width: 170,
        // 1. BACKGROUND & SHADOW (Ultra-soft "Whisper" Tint)
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: effectiveBorderColor != null
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    effectiveBorderColor.withOpacity(isDark ? 0.08 : 0.02),
                    effectiveBorderColor.withOpacity(0.0),
                  ],
                )
              : null,
          color: effectiveBorderColor == null
              ? (isDark
                    ? Theme.of(context).colorScheme.surface
                    : Colors.white)
              : null,
          boxShadow: [
            if (effectiveBorderColor != null)
              BoxShadow(
                color: effectiveBorderColor.withOpacity(isDark ? 0.12 : 0.06),
                blurRadius: 20,
                offset: const Offset(0, 6),
              )
            else
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.1 : 0.03),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        // 2. THE BORDER (Hairline thickness)
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: effectiveBorderColor != null
                ? effectiveBorderColor.withOpacity(isDark ? 0.2 : 0.04)
                : (isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.02)),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        // 3. THE CONTENT
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.push(
              AppRoutes.doctorDetailsById('$id'),
              extra: {
                'id': id,
                'full_name': name,
                'specialties': {'name': specialty},
                'rating': rating,
                'profile_picture_url': imageUrl,
                'hero_tag': 'popular-hero-$id',
              },
            ),
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      flex: 3,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(23)),
                        child: Hero(
                          tag: 'popular-hero-$id',
                          child: AppNetworkImage(
                            imageUrl: imageUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            fallbackIconSize: 50,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF1D1D1F),
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.05) : AppColors.primaryGreen.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                specialty,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.primaryGreen,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            hasRating
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        rating,
                                        style: TextStyle(
                                          color: isDark ? Colors.white : Colors.black87,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  )
                                : Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.amber.withOpacity(0.12) : Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      "NEW",
                                      style: TextStyle(
                                        color: isDark ? Colors.amber : Colors.orange.shade800,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                
                if (customBadgeOverlay != null)
                  Positioned(
                    top: 0,
                    left: 0,
                    child: customBadgeOverlay!,
                  )
                else if (isHighlighted)
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(isDark ? 0.15 : 0.08),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(22),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star_rounded,
                            color: AppColors.primaryGreen,
                            size: 9,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            "TOP RATED",
                            style: TextStyle(
                              color: AppColors.primaryGreen,
                              fontSize: 8.0,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate(delay: (300 + (index * 60)).ms)
        .fade(duration: 500.ms, curve: Curves.easeOut)
        .slideX(
          begin: 0.15,
          end: 0,
          duration: 500.ms,
          curve: Curves.easeOutCubic,
        );
  }
}
