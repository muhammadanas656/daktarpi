import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileViewScreen extends StatefulWidget {
  const ProfileViewScreen({super.key});

  @override
  State<ProfileViewScreen> createState() => _ProfileViewScreenState();
}

class _ProfileViewScreenState extends State<ProfileViewScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  // Reload data when coming back from Edit Screen
  void _refresh() {
    setState(() => _isLoading = true);
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final data =
          await Supabase.instance.client
              .from('profiles')
              .select()
              .eq('id', userId)
              .maybeSingle();

      if (mounted) {
        setState(() {
          _profileData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) context.go('/login');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error logging out: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF00C689);

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFBFBFB),
        body: Center(child: CircularProgressIndicator(color: primaryGreen)),
      );
    }

    // Default Fallbacks
    final name = _profileData?['full_name'] ?? 'No Name';
    final phone = _profileData?['phone_number'] ?? 'No Phone';
    final location = _profileData?['location'] ?? 'No Location';
    final avatarUrl = _profileData?['profile_picture_url'];

    String dob = "No DOB";
    if (_profileData?['date_of_birth'] != null) {
      final date = DateTime.parse(_profileData!['date_of_birth']);
      dob = DateFormat('dd MMM yyyy').format(date);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- HEADER ---
            Container(
              padding: const EdgeInsets.only(
                top: 60,
                left: 20,
                right: 20,
                bottom: 40,
              ),
              decoration: const BoxDecoration(
                color: primaryGreen,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  // App Bar Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Profile",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),

                      // --- LIGHTER SOFT LOGOUT BUTTON ---
                      InkWell(
                        onTap: _handleLogout,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            // 1. Lighter Gradient: Pastel Red / Salmon
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFFFFCDD2), // Very Light Red (Top Left)
                                Color(0xFFEF9A9A), // Soft Red (Bottom Right)
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            // 2. Very Subtle Shadow
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFE57373,
                                ).withValues(alpha: 0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                            // 3. White Border for "fresh" look
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          // 4. Icon: Slightly darker red to stand out on the light background
                          child: const Icon(
                            Icons.logout,
                            color: Color(
                              0xFFD32F2F,
                            ), // Darker Red Icon for contrast
                            size: 20,
                          ),
                        ),
                      ),
                      // ----------------------------------
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Avatar
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      color: Colors.white,
                    ),
                    child: ClipOval(
                      child:
                          avatarUrl != null && avatarUrl.isNotEmpty
                              ? Image.network(
                                avatarUrl,
                                fit: BoxFit.cover,
                                width: 110,
                                height: 110,
                                key: ValueKey(avatarUrl),
                                errorBuilder:
                                    (_, __, ___) => const Icon(
                                      Icons.person,
                                      size: 60,
                                      color: Colors.grey,
                                    ),
                              )
                              : const Icon(
                                Icons.person,
                                size: 60,
                                color: Colors.grey,
                              ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    phone,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // --- INFO TILES ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Personal information",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 20),

                  _InfoCard(
                    icon: Icons.cake,
                    label: "Date of Birth",
                    value: dob,
                  ),
                  const SizedBox(height: 16),
                  _InfoCard(
                    icon: Icons.location_on,
                    label: "Location",
                    value: location,
                  ),

                  const SizedBox(height: 40),

                  // EDIT BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        await context.push('/profile/edit');
                        _refresh();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "Edit Profile",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF00C689).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF00C689), size: 22),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
