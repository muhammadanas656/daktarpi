import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

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
    final specialty = doctor['specialties']?['name']?.toString() ?? 'Specialist';
    final doctorName = doctor['full_name']?.toString() ?? 'Unknown';
    final displayPrice =
        (visitPrice ?? doctor['hourly_rate']?.toString() ?? '0').toString();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EDF3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: 'doctor-hero-${doctor['id']}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                doctor['profile_picture_url'] ?? 'https://i.pravatar.cc/300',
                width: 76,
                height: 76,
                cacheWidth: 152,
                cacheHeight: 152,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) => Container(
                      width: 76,
                      height: 76,
                      color: const Color(0xFFEAF2F8),
                      child: const Icon(Icons.person),
                    ),
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
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
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
                      "${'\u09F3'}$displayPrice/visit",
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
