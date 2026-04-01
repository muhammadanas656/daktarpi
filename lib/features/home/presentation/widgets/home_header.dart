import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../presentation/widgets/custom_search_bar.dart';
import '../../../../presentation/widgets/app_network_image.dart';
import '../../../notifications/presentation/notification_notifier.dart';

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
        Container(
          padding: const EdgeInsets.fromLTRB(24, 64, 24, 54), 
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? const [Color(0xFF009668), Color(0xFF006B78)]
                  : const [Color(0xFF00C689), Color(0xFF008FA0)],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32), 
              bottomRight: Radius.circular(32),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center, 
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getGreeting(fullName),
                      style: AppTextStyles.body(context).copyWith(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w600, 
                        letterSpacing: 0.2, // TYPOGRAPHY UPGRADE
                      ),
                    ),
                    const SizedBox(height: 2), 
                    Text(
                      "Find Your Doctor",
                      style: AppTextStyles.h1(context).copyWith(
                        color: Colors.white,
                        fontSize: 26, 
                        fontWeight: FontWeight.w800, // TYPOGRAPHY UPGRADE
                        letterSpacing: -0.5,
                        height: 1.1, 
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildNotificationBell(context, isDark),
                  const SizedBox(width: 12),
                  _buildAvatar(isDark),
                ],
              ),
            ],
          ),
        ),
        
        Transform.translate(
          offset: const Offset(0, -26), 
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20), 
                boxShadow: [
                  BoxShadow(
                    color: isDark 
                        ? Colors.black.withOpacity(0.4) 
                        : const Color(0xFF008FA0).withOpacity(0.15),
                    blurRadius: 24, 
                    spreadRadius: 2, 
                    offset: const Offset(0, 10), 
                  )
                ],
              ),
              child: CustomSearchBar(
                controller: searchController,
                readOnly: true,
                hintText: "Search doctor, specialty...", 
                onTap: onSearchTap,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationBell(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.notifications),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.15),
            ),
            child: const Icon(
              Icons.notifications_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
          ListenableBuilder(
            listenable: NotificationNotifier.instance,
            builder: (context, _) {
              final unreadCount = NotificationNotifier.instance.unreadCount;
              if (unreadCount == 0) return const SizedBox.shrink();
              
              return Positioned(
                top: 0,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: AppColors.dangerRed,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? const Color(0xFF006B78) : Colors.white,
                      width: 2.5,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(bool isDark) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.4), width: 2), 
      ),
      child: avatarUrl != null && avatarUrl!.isNotEmpty
          ? AppNetworkImage(
              imageUrl: avatarUrl!,
              width: 46,
              height: 46,
              circular: true,
            )
          : CircleAvatar(
              radius: 23,
              backgroundColor: isDark ? Colors.black26 : Colors.white.withOpacity(0.2),
              child: const Icon(Icons.person_rounded, color: Colors.white, size: 24),
            ),
    );
  }

  String _getGreeting(String name) {
    final hour = DateTime.now().hour;
    String timeOfDay = "Good Evening";
    if (hour < 12) timeOfDay = "Good Morning";
    else if (hour < 17) timeOfDay = "Good Afternoon";
    final firstName = name.split(' ').first; 
    return "$timeOfDay, $firstName";
  }
}