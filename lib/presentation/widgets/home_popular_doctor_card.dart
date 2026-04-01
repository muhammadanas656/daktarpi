import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_routes.dart';
import '../../core/theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import 'app_network_image.dart';

class HomePopularDoctorCard extends StatelessWidget {
  final int id;
  final String name;
  final String specialty;
  final String rating;
  final String? imageUrl;

  const HomePopularDoctorCard({
    super.key,
    required this.id,
    required this.name,
    required this.specialty,
    required this.rating,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: Container(
      width: 170,
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(24), // THE FIX: Flagship 24px curve
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04), // Soft glass edge
          width: 1,
        ),
        boxShadow: isDark ? [] : [
          BoxShadow(
            color: Colors.black.withOpacity(0.04), // THE FIX: Deep floating shadow
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
          onTap:
              () => context.push(
                AppRoutes.doctorDetailsById('$id'),
                extra: {
                  'id': id,
                  'full_name': name,
                  'specialties': {'name': specialty},
                  'rating': rating,
                  'profile_picture_url': imageUrl,
                },
              ),
          child: Column(
            children: [
              Expanded(
                flex: 3,
                child: ClipRRect(
                  // Mathematically nested to 23px so it slides perfectly inside the 1px border
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(23)),
                  child: Hero(
                    tag: 'doctor-hero-$id',
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
                      
                      // THE FIX: The Signature Grey Specialty Pill
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
                          style: TextStyle(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      Row(
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
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ));
  }
}