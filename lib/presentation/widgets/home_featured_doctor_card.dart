import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../features/profile/presentation/profile_notifier.dart';
import 'app_network_image.dart';

class HomeFeaturedDoctorCard extends StatelessWidget {
  final int id;
  final String name;
  final String specialty;
  final String price;
  final String rating;
  final String? imageUrl;
  final bool isFavorite;

  const HomeFeaturedDoctorCard({
    super.key,
    required this.id,
    required this.name,
    required this.specialty,
    required this.price,
    required this.rating,
    required this.imageUrl,
    this.isFavorite = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? Theme.of(context).colorScheme.surface : Colors.white;

    // THE FIX: Evaluate rating for the cutout badge fallback
    final double numericRating = double.tryParse(rating) ?? 0.0;
    final bool hasRating = numericRating > 0.0;

    return RepaintBoundary(
      child: Container(
      width: 155, 
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04), 
          width: 1,
        ),
        boxShadow: isDark ? [] : [
          BoxShadow(
            color: Colors.black.withOpacity(0.04), 
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            context.push(
              AppRoutes.doctorDetailsById('$id'),
              extra: {
                'id': id,
                'full_name': name,
                'specialties': {'name': specialty},
                'hourly_rate': price,
                'rating': rating,
                'profile_picture_url': imageUrl,
              },
            );
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.topCenter,
                  clipBehavior: Clip.none,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isFavorite 
                              ? AppColors.dangerRed.withOpacity(0.12)
                              : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03)),
                        ),
                        child: Icon(
                          isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isFavorite ? AppColors.dangerRed : (isDark ? Colors.white30 : Colors.black26),
                          size: 14,
                        ),
                      ),
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.bottomCenter,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? Colors.white12 : AppColors.primaryGreen.withOpacity(0.15), 
                                width: 1,
                              ),
                            ),
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))
                                ],
                              ),
                              child: Hero(
                                tag: 'doctor-hero-$id',
                                child: ClipOval(
                                  child: AppNetworkImage(
                                    imageUrl: imageUrl,
                                    width: 64,
                                    height: 64,
                                    fit: BoxFit.cover,
                                    circular: true,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          
                          Positioned(
                            bottom: -12, 
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), 
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: surfaceColor, width: 2.5),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))
                                ],
                              ),
                              child: hasRating 
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          rating,
                                          style: TextStyle(
                                            color: isDark ? Colors.white : Colors.black87,
                                            fontSize: 11, 
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      "NEW",
                                      style: TextStyle(
                                        color: isDark ? Colors.amber : Colors.orange.shade800,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const Spacer(),
                const SizedBox(height: 18), 
                
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle( 
                    color: isDark ? Colors.white : const Color(0xFF1D1D1F),
                    fontWeight: FontWeight.w800, 
                    letterSpacing: -0.3, 
                    fontSize: 14,
                  ),
                ),
                
                const SizedBox(height: 2),
                
                Text(
                  specialty,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle( 
                    color: AppColors.primaryGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white12 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? Colors.transparent : Colors.black.withOpacity(0.03),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      "${ProfileNotifier.instance.currencySymbol} $price/hour",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle( 
                        color: isDark ? Colors.white70 : const Color(0xFF86868B),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
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
