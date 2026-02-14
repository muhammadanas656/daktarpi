import 'package:flutter/material.dart';
import '../../../../core/constants/app_routes.dart';
import 'package:go_router/go_router.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../profile/presentation/profile_notifier.dart';
import '../../../../core/theme/app_colors.dart';

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
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Log Out',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Colors.black,
            ),
          ),
          content: const Text(
            'Are you sure you want to logout?',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                // Clear notifier state
                _profileNotifier.clear();
                await _profileRepo.signOut();
                if (parentContext.mounted) {
                  parentContext.go('/login');
                }
              },
              child: Text(
                'Ok',
                style: TextStyle(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use notifier data
    final userName = _profileNotifier.fullName.isNotEmpty
        ? _profileNotifier.fullName
        : "Guest User";
    final phone = (_profileNotifier.phoneNumber?.isNotEmpty ?? false)
        ? _profileNotifier.phoneNumber!
        : "No Contact Info";
    final avatar = _profileNotifier.avatarUrl;

    return Container(
      color: drawerContentColor,
      padding: const EdgeInsets.fromLTRB(20, 80, 0, 20), // Increased top padding for better alignment
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.white,
                  backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                  child: avatar == null
                      ? const Icon(Icons.person,
                          color: AppColors.textLight, size: 35)
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                   const Icon(Icons.phone, color: Colors.white70, size: 14),
                   const SizedBox(width: 6),
                   Text(
                     phone,
                     style: const TextStyle(
                       color: Colors.white70, 
                       fontSize: 14,
                     ),
                   ),
                ],
              )
            ],
          ),
          
          const SizedBox(height: 40),
          
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(Icons.person, "My Doctors", () {
                  widget.onClose();
                }, isSelected: true),
                _buildDrawerItem(Icons.assignment, "Medical Records", () {
                  widget.onClose();
                }),
                _buildDrawerItem(Icons.calendar_today, "My Appointments", () {
                  widget.onClose();
                  widget.onNavigateToTab(2);
                }),
                _buildDrawerItem(Icons.security, "Privacy & Policy", () {
                  widget.onClose();
                  context.push(AppRoutes.privacyPolicy);
                }),
                _buildDrawerItem(Icons.help_outline, "Help Center", () {
                  widget.onClose();
                }),
                _buildDrawerItem(Icons.settings, "Settings", () {
                  widget.onClose();
                }),
              ],
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout, color: Colors.white, size: 24),
            title: const Text(
              "Logout",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () {
              _showLogoutDialog(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isSelected = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      decoration: isSelected
          ? BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        leading: Icon(icon, color: Colors.white, size: 24),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Colors.white30,
          size: 14,
        ),
        onTap: onTap,
      ),
    );
  }
}
