import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../presentation/widgets/app_network_image.dart';
import '../../../profile/presentation/profile_notifier.dart';

class DoctorDetailsHeader extends StatelessWidget {
  final Map<String, dynamic> doctor;
  final VoidCallback onFavoriteTap;
  final bool isFavorite;
  final String? visitPrice;
  final VoidCallback? onBookNowTap;

  const DoctorDetailsHeader({
    super.key,
    required this.doctor,
    required this.onFavoriteTap,
    required this.isFavorite,
    this.visitPrice,
    this.onBookNowTap,
  });

  @override
  Widget build(BuildContext context) {
    final specialty =
        doctor['specialties']?['name']?.toString() ?? 'Specialist';
    final doctorName = doctor['full_name']?.toString() ?? 'Unknown';
    final displayPrice =
        (visitPrice ?? doctor['hourly_rate']?.toString() ?? '0').toString();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20), // Premium Radius
        border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1C222E).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: 'doctor-hero-${doctor['id']}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AppNetworkImage(
                imageUrl: doctor['profile_picture_url']?.toString(),
                width: 76,
                height: 76,
                fit: BoxFit.cover,
                fallbackIconSize: 28,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctorName,
                  style: AppTextStyles.h3.copyWith(fontSize: 18),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  "Specialist $specialty",
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: Color(0xFF6AB9AE),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "${ProfileNotifier.instance.currencySymbol} $displayPrice/visit",
                      style: const TextStyle(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    SizedBox(
                      height: 34,
                      width: 108,
                      child: ElevatedButton(
                        onPressed: onBookNowTap,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: AppColors.primaryGreen,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text(
                          "Book Now",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: onFavoriteTap,
                      child: Icon(
                        isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: Colors.red,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
