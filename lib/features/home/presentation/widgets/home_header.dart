import 'package:flutter/material.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../presentation/widgets/custom_search_bar.dart';
import '../../../../presentation/widgets/app_network_image.dart';

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

    return Column(
      children: [
        // 1. The Expansive Gradient Background
        Container(
          // PRO FIX: Increased Top (80) and Bottom (65) padding to restore the lost volume!
          padding: const EdgeInsets.fromLTRB(24, 80, 24, 65),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? const [Color(0xFF009668), Color(0xFF006B78)]
                  : const [Color(0xFF00C689), Color(0xFF008FA0)],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(36), // Slightly softer curve for a taller header
              bottomRight: Radius.circular(36),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center, // Perfect vertical alignment
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Hi $fullName!",
                      style: AppTextStyles.body(context).copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 16,
                        fontWeight: FontWeight.w600, // Slightly bolder greeting
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 6), // Better breathing room
                    Text(
                      "Find Your Doctor",
                      style: AppTextStyles.h1(context).copyWith(
                        color: Colors.white,
                        fontSize: 25, // Bumped up from 26 to fill the taller header luxuriously
                        letterSpacing: -0.5,
                        height: 1.1, 
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16), // Safety gap for very long names
              
              // --- The "Halo" Avatar ---
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // Adds a beautiful, faint white ring around the profile picture
                  border: Border.all(color: Colors.white30, width: 2), 
                ),
                child: avatarUrl != null && avatarUrl!.isNotEmpty
                    ? AppNetworkImage(
                        imageUrl: avatarUrl!,
                        width: 52, // Increased from 48 to match the new text scale
                        height: 52,
                        circular: true,
                      )
                    : CircleAvatar(
                        radius: 26, // Increased from 24
                        backgroundColor: isDark ? Colors.black26 : Colors.white24,
                        child: const Icon(Icons.person, color: Colors.white, size: 30),
                      ),
              ),
            ],
          ),
        ),
        
        // 2. The Floating Search Bar Bridge
        Transform.translate(
          offset: const Offset(0, -28), // Pulled up just enough to sit 50/50 on the curve
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black45 : const Color(0xFF008FA0).withValues(alpha: 0.15),
                    blurRadius: 24, // Wider, softer blur for a more realistic ambient shadow
                    offset: const Offset(0, 10), // Dropped slightly lower
                  )
                ],
              ),
              child: CustomSearchBar(
                controller: searchController,
                readOnly: true,
                hintText: "Search doctor, specialty...", // Added a more helpful prompt
                onTap: onSearchTap,
              ),
            ),
          ),
        ),
      ],
    );
  }
}