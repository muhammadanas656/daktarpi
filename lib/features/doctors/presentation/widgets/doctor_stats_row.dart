import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
        children: [
          Expanded(
            child: _buildStatItem(
              icon: Icons.star_rounded,
              iconColor: const Color(0xFFFFB648),
              value: rating,
              label: 'Rating & Review',
            ),
          ),
          _buildDivider(),
          Expanded(
            child: _buildStatItem(
              icon: Icons.work_outline_rounded,
              iconColor: const Color(0xFF89B2B3),
              value: experience,
              label: 'Years of work',
            ),
          ),
          _buildDivider(),
          Expanded(
            child: _buildStatItem(
              icon: Icons.people_alt_outlined,
              iconColor: const Color(0xFF80B59A),
              value: patients,
              label: 'No. of patients',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 36,
      color: const Color(0xFFF0F4F8), // Softer divider
    );
  }

  Widget _buildStatItem({
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
            const SizedBox(width: 4),
            Text(value, style: AppTextStyles.h3.copyWith(fontSize: 15)),
          ],
        ),
        const SizedBox(height: 4),
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
