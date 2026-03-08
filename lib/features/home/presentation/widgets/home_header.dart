import 'package:flutter/material.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../presentation/widgets/custom_search_bar.dart';
import '../../../../presentation/widgets/app_network_image.dart'; // PRO FIX

class HomeHeader extends StatelessWidget {
  final String fullName;
  final String? avatarUrl;
  final VoidCallback onSearchTap;
  final TextEditingController searchController;

  const HomeHeader({
    super.key,
    required this.fullName,
    this.avatarUrl,
    required this.onSearchTap,
    required this.searchController,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 70, 24, 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors:
              isDark
                  ? const [Color(0xFF009668), Color(0xFF006B78)]
                  : const [Color(0xFF00C689), Color(0xFF008FA0)],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: AppStyles.primaryShadow(
          context,
          const Color(0xFF008FA0),
          alpha: 0.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Hi $fullName!",
                    style: AppTextStyles.body(
                      context,
                    ).copyWith(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "Find Your Doctor",
                    style: AppTextStyles.h1(
                      context,
                    ).copyWith(color: Colors.white),
                  ),
                ],
              ),
              // PRO FIX: Replaced NetworkImage with AppNetworkImage
              avatarUrl != null && avatarUrl!.isNotEmpty
                  ? AppNetworkImage(
                    imageUrl: avatarUrl,
                    width: 48,
                    height: 48,
                    circular: true,
                  )
                  : CircleAvatar(
                    radius: 24,
                    backgroundColor: isDark ? Colors.black26 : Colors.white24,
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
            ],
          ),
          const SizedBox(height: 25),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 0),
            child: CustomSearchBar(
              controller: searchController,
              readOnly: true,
              hintText: "Search.....",
              onTap: onSearchTap,
            ),
          ),
        ],
      ),
    );
  }
}
