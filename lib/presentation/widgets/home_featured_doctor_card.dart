import 'package:flutter/material.dart';
import '../../core/theme/app_styles.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_shapes.dart';
import '../../core/constants/app_routes.dart';
import 'package:go_router/go_router.dart';
import '../../features/profile/presentation/profile_notifier.dart';
import 'app_network_image.dart';

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
        boxShadow: AppStyles.cardShadow(context),
      ),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppShapes.xl,
        child: InkWell(
          onTap:
              () => context.push(
                AppRoutes.doctorDetailsById('$id'),
                extra: {
                  'id': id,
                  'full_name': name,
                  'hourly_rate': price,
                  'rating': rating,
                  'profile_picture_url': imageUrl,
                },
              ),
          borderRadius: AppShapes.xl,
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
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
                const SizedBox(height: AppDimens.spaceXs),
                Container(
                  width: AppDimens.avatarSm,
                  height: AppDimens.avatarSm,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkBorder
                            : Colors.grey[200],
                  ),
                  child: Hero(
                    tag: 'doctor-hero-$id',
                    child: AppNetworkImage(
                      imageUrl: imageUrl,
                      width: AppDimens.avatarSm,
                      height: AppDimens.avatarSm,
                      fit: BoxFit.cover,
                      circular: true,
                    ),
                  ),
                ),
                const SizedBox(height: AppDimens.spaceXs),
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
