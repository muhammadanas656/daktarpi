import 'package:flutter/material.dart';
import '../../core/theme/app_styles.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/constants/app_routes.dart';
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
    return Container(
      width: 170,
      decoration: BoxDecoration(
        // PRO FIX: Synchronized the dynamic radius so the shadow escapes cleanly
        borderRadius: AppStyles.cardRadius,
        boxShadow: AppStyles.cardShadow(context),
      ),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppStyles.cardRadius,
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
          borderRadius: AppStyles.cardRadius,
          child: Column(
            children: [
              Expanded(
                flex: 3,
                child: ClipRRect(
                  // We only clip the top corners of the image to match the card
                  borderRadius: BorderRadius.vertical(
                    top: AppStyles.cardRadius.topLeft,
                  ),
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
                  padding: const EdgeInsets.all(AppDimens.spaceMd),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        specialty,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: AppDimens.spaceXs),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            rating,
                            style: const TextStyle(
                              fontSize: 12, 
                              fontWeight: FontWeight.w600
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
    );
  }
}