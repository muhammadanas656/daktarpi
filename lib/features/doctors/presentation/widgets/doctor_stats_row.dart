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
    // 1. Evaluate "Ghost UI" constraints mathematically
    final bool hasPatients = patients != '0' && patients != '0+' && patients != 'New' && patients.isNotEmpty;
    final bool hasRating = rating != '0.0' && rating != '0' && rating != 'N/A' && rating.isNotEmpty;
    final bool isCompletelyNew = !hasPatients && !hasRating;

    // 2. Dynamically build the layout array based on available data
    List<Widget> columns = [];

    if (isCompletelyNew) {
      // --- STATE A: Completely Fresh Doctor ---
      columns.add(
        Expanded(
          child: _buildStatItem(
            context,
            icon: Icons.work_outline_rounded,
            iconColor: const Color(0xFF89B2B3),
            value: "$experience yrs",
            label: 'Experience',
          ),
        ),
      );
      columns.add(_buildDivider(context));
      columns.add(
        Expanded(
          child: _buildNewBadge(context),
        ),
      );
    } else {
      // --- STATE B: Dynamic Combination Layout ---
      if (hasRating) {
        columns.add(
          Expanded(
            child: _buildStatItem(
              context,
              icon: Icons.star_rounded,
              iconColor: const Color(0xFFFFB648),
              value: rating,
              label: 'Rating',
            ),
          ),
        );
      }

      if (columns.isNotEmpty) {
        columns.add(_buildDivider(context));
      }

      columns.add(
        Expanded(
          child: _buildStatItem(
            context,
            icon: Icons.work_outline_rounded,
            iconColor: const Color(0xFF89B2B3),
            value: "$experience yrs",
            label: 'Experience',
          ),
        ),
      );

      if (hasPatients) {
        columns.add(_buildDivider(context));
        columns.add(
          Expanded(
            child: _buildStatItem(
              context,
              icon: Icons.people_alt_outlined,
              iconColor: const Color(0xFF80B59A),
              value: "$patients+",
              label: 'Patients',
            ),
          ),
        );
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: AppStyles.surfaceCard(context, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: columns,
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 1,
      height: 36,
      color: isDark ? AppColors.darkBorder : const Color(0xFFF0F4F8), 
    );
  }

  // --- THE NEW TO PLATFORM BADGE ---
  Widget _buildNewBadge(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.verified_rounded, color: AppColors.primaryGreen, size: 13),
            const SizedBox(width: 4),
            Text(
              "New",
              style: AppTextStyles.h3(context).copyWith(fontSize: 15, color: AppColors.primaryGreen),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          "To Platform",
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
            const SizedBox(width: 4),
            Text(
              value,
              style: AppTextStyles.h3(context).copyWith(fontSize: 15),
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