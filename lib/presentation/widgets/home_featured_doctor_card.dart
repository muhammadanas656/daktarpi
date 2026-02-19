import 'package:flutter/material.dart';
import '../../core/theme/app_styles.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_routes.dart';
import 'package:go_router/go_router.dart';
import '../../features/profile/presentation/profile_notifier.dart';

class HomeFeaturedDoctorCard extends StatelessWidget {
  final int id;
  final String name;
  final String price;
  final String rating;
  final String? imageUrl;
  final bool isFavorite;

  const HomeFeaturedDoctorCard({
    super.key,
    required this.id,
    required this.name,
    required this.price,
    required this.rating,
    required this.imageUrl,
    this.isFavorite = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      decoration: BoxDecoration(
        borderRadius: AppStyles.cardRadius,
        boxShadow: AppStyles.cardShadow,
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => context.push(AppRoutes.doctorDetailsById('$id')),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : Colors.grey,
                      size: 16,
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 12),
                        Text(
                          rating,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[200],
                  ),
                  child: Hero(
                    tag: 'doctor-hero-$id',
                    child: ClipOval(
                      child: (imageUrl != null && imageUrl!.isNotEmpty)
                          ? Image.network(
                              imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.person, color: Colors.grey),
                            )
                          : const Icon(Icons.person, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  "${ProfileNotifier.instance.currencySymbol} $price/hour",
                  style: const TextStyle(
                    color: AppColors.primaryGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
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
