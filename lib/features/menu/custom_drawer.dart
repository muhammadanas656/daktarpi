import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// NOTE: You no longer need to import 'privacy_policy_screen.dart' here
// because we are navigating using the route string '/privacy_policy'.

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
  final Color primaryGreen = const Color(0xFF00C689);

  String _userName = "Abdullah Mamun";
  String _phone = "01303-527300";
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final data =
            await Supabase.instance.client
                .from('profiles')
                .select('full_name, profile_picture_url, phone_number')
                .eq('id', user.id)
                .maybeSingle();

        if (mounted && data != null) {
          setState(() {
            _userName = data['full_name'] ?? "Abdullah Mamun";
            _avatarUrl = data['profile_picture_url'];
            _phone = data['phone_number'] ?? "01303-527300";
          });
        }
      } catch (e) {
        debugPrint('Error fetching profile: $e');
      }
    }
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
                  color: primaryGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await Supabase.instance.client.auth.signOut();
                if (parentContext.mounted) {
                  parentContext.go('/login');
                }
              },
              child: Text(
                'Ok',
                style: TextStyle(
                  color: primaryGreen,
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
    return Container(
      color: drawerContentColor,
      padding: const EdgeInsets.fromLTRB(20, 40, 0, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white,
                backgroundImage:
                    _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                child:
                    _avatarUrl == null
                        ? const Icon(Icons.person, color: Color(0xFF626F8D))
                        : null,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.phone,
                          color: Colors.white70,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _phone,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 50),
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
                // --- UPDATED NAVIGATION ---
                _buildDrawerItem(Icons.security, "Privacy & Policy", () {
                  widget.onClose();
                  // Use the named route defined in app_router.dart
                  context.push('/privacy_policy');
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
      decoration:
          isSelected
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
