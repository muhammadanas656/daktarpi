import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_text_styles.dart';

class DoctorStatsRow extends StatelessWidget {
  final String patients;
  final String experience;
  final String rating;

  const DoctorStatsRow({
    super.key,
    required this.patients,
    required this.experience,
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      // PRO FIX: Dynamic surface card
      decoration: AppStyles.surfaceCard(context, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              context,
              icon: Icons.star_rounded,
              iconColor: Color(0xFFFFB648),
              value: rating,
              label: 'Rating & Review',
            ),
          ),
          _buildDivider(context),
          Expanded(
            child: _buildStatItem(
              context,
              icon: Icons.work_outline_rounded,
              iconColor: Color(0xFF89B2B3),
              value: experience,
              label: 'Years of work',
            ),
          ),
          _buildDivider(context),
          Expanded(
            child: _buildStatItem(
              context,
              icon: Icons.people_alt_outlined,
              iconColor: Color(0xFF80B59A),
              value: patients,
              label: 'No. of patients',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 1,
      height: 36,
      // PRO FIX: Dynamic divider color
      color: isDark ? AppColors.darkBorder : const Color(0xFFF0F4F8), 
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 13),
            SizedBox(width: 4),
            Text(
              value,
              style: AppTextStyles.h3(context).copyWith(fontSize: 15),
            ),
          ],
        ),
        SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
