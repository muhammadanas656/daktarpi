import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';

class HomeSectionHeader extends StatelessWidget {
  final String title;
  final String? eyebrow; 
  final VoidCallback? onTap;

  const HomeSectionHeader({
    super.key, 
    required this.title, 
    this.eyebrow, 
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. THE EYEBROW (Optional tiny context label)
          if (eyebrow != null) ...[
            Text(
              eyebrow!.toUpperCase(),
              style: GoogleFonts.poppins(
                color: AppColors.primaryGreen,
                fontSize: 11,
                fontWeight: FontWeight.w600, // Reduced from w700
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center, // Aligns exactly with title
            children: [
              // 2. THE EDITORIAL TITLE
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: isDark ? Colors.white : const Color(0xFF1D1D1F),
                    fontSize: 20,
                    fontWeight: FontWeight.w600, // Reduced from w700
                    letterSpacing: -0.3,
                    height: 1.2, // Restored height to standard
                  ),
                ),
              ),

              // 3. THE TONAL ACTION PILL
              if (onTap != null) ...[
                const SizedBox(width: 8),
                Material(
                  color:
                      isDark
                          ? Colors.white12
                          : AppColors.primaryGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(100),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onTap!();
                    },
                    splashColor: AppColors.primaryGreen.withOpacity(0.12),
                    highlightColor: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "See all",
                            style: GoogleFonts.poppins(
                              color: isDark ? Colors.white : AppColors.primaryGreen,
                              fontWeight: FontWeight.w500, // Reduced from w600
                              fontSize: 12,
                              letterSpacing: 0.1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: isDark ? Colors.white : AppColors.primaryGreen,
                            size: 10,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}