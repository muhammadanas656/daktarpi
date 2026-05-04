import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final specialty =
        doctor['specialty']?.toString() ??
        doctor['specialties']?['name']?.toString() ??
        'Specialist';
    final doctorName = doctor['full_name']?.toString() ?? 'Unknown';
    final displayPrice =
        (visitPrice ?? doctor['hourly_rate']?.toString() ?? '0').toString();

    return Container(
      padding: EdgeInsets.all(12),
      decoration: AppStyles.surfaceCard(context, borderRadius: BorderRadius.circular(20)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: doctor['hero_tag'] ?? 'doctor-hero-${doctor['id']}',
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
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctorName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1D1D1F),
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  specialty,
                  style: TextStyle(
                    color: AppColors.primaryGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: Color(0xFF6AB9AE),
                    ),
                    SizedBox(width: 4),
                    Text(
                      "${ProfileNotifier.instance.currencySymbol} $displayPrice/visit",
                      style: TextStyle(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
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
                        child: Text(
                          "Book Now",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    Spacer(),
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
