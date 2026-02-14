import 'package:flutter/material.dart';
import '../../../../core/constants/app_routes.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../profile_notifier.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';
import '../../data/profile_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../presentation/widgets/primary_button.dart';

class ProfileViewScreen extends StatefulWidget {
  const ProfileViewScreen({super.key});

  @override
  State<ProfileViewScreen> createState() => _ProfileViewScreenState();
}

class _ProfileViewScreenState extends State<ProfileViewScreen> {
  final _profileNotifier = ProfileNotifier.instance;

  @override
  void initState() {
    super.initState();
    _profileNotifier.addListener(_onProfileChanged);
    if (!_profileNotifier.isLoaded) {
      _profileNotifier.loadProfile();
    }
  }

  @override
  void dispose() {
    _profileNotifier.removeListener(_onProfileChanged);
    super.dispose();
  }

  void _onProfileChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _handleLogout() async {
    try {
      await ProfileRepository().signOut();
      _profileNotifier.clear();
      if (mounted) context.go(AppRoutes.login);
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, "Error logging out: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_profileNotifier.isLoaded) {
      return const Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
      );
    }

    // Use Notifier Data
    final profile = _profileNotifier.profile;
    final name = profile?.fullName ?? 'No Name';
    final phone = profile?.phoneNumber ?? 'No Phone';
    final location = profile?.location ?? 'No Location';
    final avatarUrl = profile?.profilePictureUrl;

    String dob = "No DOB";
    if (profile?.dateOfBirth != null) {
      dob = DateFormat('dd MMM yyyy').format(profile!.dateOfBirth!);
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Container(
        decoration: const BoxDecoration(gradient: AppStyles.pageGradient),
        child: SingleChildScrollView(
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
                  color: AppColors.primaryGreen,
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
                                  Color(
                                    0xFFFFCDD2,
                                  ), // Very Light Red (Top Left)
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

              const SizedBox(height: 20),

              // --- INFO TILES ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Personal information", style: AppTextStyles.h3),
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
                    PrimaryButton(
                      label: "Edit Profile",
                      onTap: () async {
                        await context.push(AppRoutes.profileEdit);
                        // No need to refresh manually, ProfileScreen updates the notifier
                      },
                      height: 56,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
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
              color: AppColors.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primaryGreen, size: 22),
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
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
