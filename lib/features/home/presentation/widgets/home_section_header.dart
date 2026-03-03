import 'package:flutter/material.dart';
import '../../../../core/theme/app_text_styles.dart';

class HomeSectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;

  const HomeSectionHeader({super.key, required this.title, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 25, 24, 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppTextStyles.h3),
          InkWell(
            onTap: onTap,
            child: Text("See all >", style: AppTextStyles.bodySmall),
          ),
        ],
      ),
    );
  }
}
