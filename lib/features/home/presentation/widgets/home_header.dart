import 'package:flutter/material.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../presentation/widgets/custom_search_bar.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark; // PRO FIX

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 70, 24, 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          // PRO FIX: Deeper, richer gradient for Dark Mode
          colors:
              isDark
                  ? const [Color(0xFF009668), Color(0xFF006B78)]
                  : const [Color(0xFF00C689), Color(0xFF008FA0)],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        // PRO FIX: Disable glowing shadow in Dark Mode
        boxShadow:
            isDark
                ? []
                : [
                  const BoxShadow(
                    color: Color(0x33008FA0),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
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
              avatarUrl != null
                  ? CircleAvatar(
                    radius: 24,
                    backgroundImage: NetworkImage(avatarUrl!),
                  )
                  : CircleAvatar(
                    radius: 24,
                    // PRO FIX: Darker placeholder background in Dark Mode
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
