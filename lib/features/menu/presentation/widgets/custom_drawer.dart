import 'package:flutter/material.dart';
import '../../../../core/constants/app_routes.dart';
import 'package:go_router/go_router.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../profile/presentation/profile_notifier.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../presentation/widgets/app_network_image.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../presentation/widgets/app_floating_dialog.dart';
import '../../../../presentation/widgets/primary_button.dart';

class CustomDrawer extends StatefulWidget {
  final VoidCallback onClose;
  final Function(int) onNavigateToTab;

  const CustomDrawer({
    super.key,
    required this.onClose,
    required this.onNavigateToTab,
  });

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  final Color drawerContentColor = Colors.transparent;
  final _profileRepo = ProfileRepository();
  final _profileNotifier = ProfileNotifier.instance;

  @override
  void initState() {
    super.initState();
    _profileNotifier.addListener(_update);
    // Ensure data is loaded if not already
    if (!_profileNotifier.isLoaded) {
      _profileNotifier.loadProfile();
    }
  }

  @override
  void dispose() {
    _profileNotifier.removeListener(_update);
    super.dispose();
  }

  void _update() {
    if (mounted) setState(() {});
  }

  Future<void> _showLogoutDialog(BuildContext parentContext) async {
    return showDialog<void>(
      context: parentContext,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (BuildContext dialogContext) {
        bool isLoggingOut = false;

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AppFloatingDialog(
              headerIcon: Icons.logout_rounded,
              iconColor: Colors.redAccent,
              title: "Log Out",
              description: "Are you sure you want to log out of your account?",
              isUpdating: isLoggingOut,
              content: const SizedBox.shrink(),
              actions: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed:
                          isLoggingOut
                              ? null
                              : () => Navigator.pop(dialogContext),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: PrimaryButton(
                      label: "Log Out",
                      backgroundColor: Colors.redAccent,
                      onTap:
                          isLoggingOut
                              ? () {}
                              : () async {
                                setDialogState(() => isLoggingOut = true);
                                try {
                                  _profileNotifier.clear();
                                  await _profileRepo.signOut();
                                  if (parentContext.mounted) {
                                    parentContext.go('/login');
                                  }
                                } catch (e) {
                                  // Silent catch for logout failure
                                } finally {
                                  if (ctx.mounted) {
                                    setDialogState(() => isLoggingOut = false);
                                  }
                                }
                              },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use notifier data
    final userName =
        _profileNotifier.fullName.isNotEmpty
            ? _profileNotifier.fullName
            : "Guest User";
    final phone =
        (_profileNotifier.phoneNumber?.isNotEmpty ?? false)
            ? _profileNotifier.phoneNumber!
            : "No Contact Info";
    final avatar = _profileNotifier.avatarUrl;

    return Container(
      color: drawerContentColor,
      // PRO FIX: Adjusted padding so the design breathes properly
      padding: const EdgeInsets.fromLTRB(20, 70, 0, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- PRO PROFILE SECTION ---
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.8),
                      width: 2,
                    ),
                    boxShadow: AppStyles.cardShadow(context),
                  ),
                  // PRO FIX: Removed NetworkImage, using AppNetworkImage for offline support
                  child: CircleAvatar(
                    radius: 38,
                    backgroundColor: Colors.white,
                    child:
                        avatar != null && avatar.isNotEmpty
                            ? AppNetworkImage(
                              imageUrl: avatar,
                              width: 76,
                              height: 76,
                              circular: true,
                            )
                            : const Icon(
                              Icons.person,
                              color: Colors.grey,
                              size: 38,
                            ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.phone, color: Colors.white70, size: 12),
                      const SizedBox(width: 6),
                      Text(
                        phone,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 48),

          // --- PRO NAVIGATION LIST ---
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              physics: const BouncingScrollPhysics(),
              children: [
                _buildDrawerItem(
                  Icons.person_outline_rounded,
                  "My Doctors",
                  () {
                    widget.onClose();
                    context.push(AppRoutes.myDoctors);
                  },
                ),
                _buildDrawerItem(
                  Icons.assignment_outlined,
                  "Medical Records",
                  () {
                    widget.onClose();
                    context.push(AppRoutes.medicalRecords);
                  },
                ),
                _buildDrawerItem(
                  Icons.calendar_today_rounded,
                  "My Appointments",
                  () {
                    widget.onClose();
                    widget.onNavigateToTab(2);
                  },
                ),
                _buildDrawerItem(Icons.settings_outlined, "Settings", () {
                  widget.onClose();
                  context.push(AppRoutes.settings);
                }),
              ],
            ),
          ),

          // --- PRO LOGOUT BUTTON ---
          Container(
            margin: const EdgeInsets.only(right: 32, top: 20),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(
                alpha: 0.15,
              ), // Destructive Glassmorphism
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(30),
                left: Radius.circular(12),
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: const Icon(
                Icons.logout_rounded,
                color: Colors.redAccent,
                size: 24,
              ),
              title: const Text(
                "Logout",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                _showLogoutDialog(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- PRO DRAWER ITEM ---
  Widget _buildDrawerItem(
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isSelected = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(
        bottom: 8,
        right: 16,
      ), // Leave space on the right for pill effect
      decoration:
          isSelected
              ? BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(30),
                  left: Radius.circular(12),
                ),
                border: const Border(
                  left: BorderSide(color: AppColors.primaryGreen, width: 4),
                ),
              )
              : const BoxDecoration(
                border: Border(
                  left: BorderSide(color: Colors.transparent, width: 4),
                ),
              ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        horizontalTitleGap: 8,
        minLeadingWidth: 24,
        leading: Icon(
          icon,
          color: Colors.white.withValues(alpha: 0.9),
          size: 24,
        ),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 15,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
        trailing:
            isSelected
                ? null
                : const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white24,
                  size: 14,
                ),
        onTap: onTap,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(
            right: Radius.circular(30),
            left: Radius.circular(12),
          ),
        ),
      ),
    );
  }
}
