import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EDF3)),
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
      color: const Color(0xFFE7ECF1),
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
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppColors.textDark,
              ),
            ),
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
