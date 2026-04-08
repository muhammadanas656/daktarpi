import 'package:flutter/material.dart';
import '../../../../core/constants/app_routes.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../profile_notifier.dart';
// Imports removed as per user request (CustomSnackbar, ProfileRepository)
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../presentation/widgets/primary_button.dart';
import '../../../../presentation/widgets/app_network_image.dart';

class ProfileViewScreen extends StatefulWidget {
  final bool isBackgroundLayer;
  
  const ProfileViewScreen({super.key, this.isBackgroundLayer = false});

  @override
  State<ProfileViewScreen> createState() => _ProfileViewScreenState();
}

class _ProfileViewScreenState extends State<ProfileViewScreen> {
  final _profileNotifier = ProfileNotifier.instance;

  @override
  void initState() {
    super.initState();
    _profileNotifier.addListener(_onProfileChanged);
    if (!widget.isBackgroundLayer && !_profileNotifier.isLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _profileNotifier.isLoaded) return;
        _profileNotifier.loadProfile();
      });
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

  // _handleLogout removed as per user request

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dynamicBottomPadding = MediaQuery.paddingOf(context).bottom + 20;

    // Use Notifier Data
    final profile = _profileNotifier.profile;
    final name = profile?.fullName ?? 'No Name';
    final String phone =
        (profile?.countryCode != null && profile?.phoneNumber != null)
            ? '${profile!.countryCode} ${profile.phoneNumber}'
            : (profile?.phoneNumber ?? 'No Phone');
    final location = profile?.location ?? 'No Location';
    final avatarUrl = profile?.profilePictureUrl;

    String dob = "No DOB";
    if (profile?.dateOfBirth != null) {
      dob = DateFormat('dd MMM yyyy').format(profile!.dateOfBirth!);
    }

    return Scaffold(
      backgroundColor: context.colorScaffoldBackground,
      body: Container(
        decoration: BoxDecoration(gradient: AppStyles.pageGradient(context)),
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
            padding: EdgeInsets.only(bottom: dynamicBottomPadding),
            child: Column(
            children: [
              // --- HEADER ---
              Container(
                padding: EdgeInsets.only(
                  top: 60,
                  left: 20,
                  right: 20,
                  bottom: 40,
                ),
                decoration: BoxDecoration(
                  // PRO FIX: Deep Slate Medical Gradient for Dark Mode
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors:
                        isDark
                            ? const [Color(0xFF009668), Color(0xFF006B78)]
                            : const [Color(0xFF00C689), Color(0xFF008FA0)],
                  ),
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
                        Text(
                          "Profile",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),

                        // --- LOGOUT BUTTON REMOVED ---
                        // User requested removal.
                        SizedBox.shrink(), // Placeholder to keep layout valid if needed, or just remove
                        // ----------------------------------
                        // ----------------------------------
                      ],
                    ),
                    SizedBox(height: 30),

                    // Avatar
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        // PRO FIX: Softer, glassmorphic border with a floating shadow
                        border: Border.all(
                          color:
                              isDark
                                  ? Colors.white.withValues(alpha: 0.15)
                                  : Colors.white,
                          width: 3,
                        ),
                        boxShadow: AppStyles.cardShadow(context),
                        color: isDark ? AppColors.darkSurface : Colors.white,
                      ),
                      child: ClipOval(
                        child:
                            avatarUrl != null && avatarUrl.isNotEmpty
                                ? AppNetworkImage(
                                  imageUrl: avatarUrl,
                                  width: 110,
                                  height: 110,
                                  circular: true,
                                  fallbackIconSize: 60,
                                )
                                : const Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.grey,
                                ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      phone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              // --- INFO TILES ---
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Personal information",
                      style: AppTextStyles.h3(context),
                    ),
                    SizedBox(height: 20),

                    _InfoCard(
                      icon: Icons.cake,
                      label: "Date of Birth",
                      value: dob,
                    ),
                    SizedBox(height: 16),
                    _InfoCard(
                      icon: Icons.location_on,
                      label: "Location",
                      value: location,
                    ),

                    SizedBox(height: 40),

                    // EDIT BUTTON
                    PrimaryButton(
                      label: "Edit Profile",
                      onTap: () async {
                        await context.push(AppRoutes.profileEdit);
                        // No need to refresh manually, ProfileScreen updates the notifier
                      },
                      height: 56,
                    ),
                    SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
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
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: AppStyles.surfaceCard(
        context,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primaryGreen, size: 22),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey)),
                SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.colorTextDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
