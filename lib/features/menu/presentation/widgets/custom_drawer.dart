import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../presentation/widgets/app_floating_dialog.dart';
import '../../../../presentation/widgets/app_network_image.dart';
import '../../../../presentation/widgets/primary_button.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../profile/presentation/profile_notifier.dart';

class CustomDrawer extends StatefulWidget {
  final VoidCallback onClose;
  final Function(int) onNavigateToTab;
  final Animation<double> drawerAnimation;

  const CustomDrawer({
    super.key,
    required this.onClose,
    required this.onNavigateToTab,
    required this.drawerAnimation,
  });

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  final _profileRepo = ProfileRepository();
  final _profileNotifier = ProfileNotifier.instance;

  @override
  void initState() {
    super.initState();
    _profileNotifier.addListener(_update);
    if (!_profileNotifier.isLoaded) _profileNotifier.loadProfile();
  }

  @override
  void dispose() {
    _profileNotifier.removeListener(_update);
    super.dispose();
  }

  void _update() {
    if (mounted) setState(() {});
  }

  Widget _buildOrbitalItem(Widget child, int index, int totalItems) {
    return AnimatedBuilder(
      animation: widget.drawerAnimation,
      builder: (context, childWidget) {
        final double val = widget.drawerAnimation.value;
        final double clampedVal = val.clamp(0.0, 1.0).toDouble();
        final double startX = 80.0 + (index * 15.0);
        final double startY = 40.0 + (index * 10.0);
        final double startRot = 0.15;
        final double offsetX = -startX * (1 - val);
        final double offsetY = startY * (1 - val);
        final double rotZ = -startRot * (1 - val);
        final double curveOffset =
            math.sin((index / (totalItems - 1)) * math.pi) * 35.0;

        return Transform(
          alignment: Alignment.centerLeft,
          transform:
              Matrix4.identity()
                ..translate(offsetX, offsetY, 0.0)
                ..rotateZ(rotZ),
          child: Padding(
            padding: EdgeInsets.only(left: curveOffset),
            child: Opacity(
              opacity: math.pow(clampedVal, 1.5).toDouble().clamp(0.0, 1.0),
              child: childWidget,
            ),
          ),
        );
      },
      child: child,
    );
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
    final userName =
        _profileNotifier.fullName.isNotEmpty
            ? _profileNotifier.fullName
            : "Guest User";
    final phone =
        (_profileNotifier.phoneNumber?.isNotEmpty ?? false)
            ? _profileNotifier.phoneNumber!
            : "No Contact Info";
    final avatar = _profileNotifier.avatarUrl;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final textColor = isDark ? Colors.white : const Color(0xFF1D2429);
    final subTextColor = isDark ? Colors.white54 : const Color(0xFF6B7A87);
    const int totalItems = 6;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 48, 16, 40),
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width * 0.65,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOrbitalItem(
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor:
                            isDark ? Colors.white10 : Colors.black12,
                        child:
                            avatar != null && avatar.isNotEmpty
                                ? AppNetworkImage(
                                  imageUrl: avatar,
                                  width: 68,
                                  height: 68,
                                  circular: true,
                                )
                                : Icon(
                                  Icons.person,
                                  color: subTextColor,
                                  size: 34,
                                ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        phone,
                        style: TextStyle(
                          color: subTextColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                0,
                totalItems,
              ),
              const SizedBox(height: 48),
              _buildOrbitalItem(
                _MenuItem(
                  icon: Icons.medical_services_rounded,
                  title: "Doctors",
                  textColor: textColor,
                  onTap: () {
                    widget.onClose();
                    context.push(AppRoutes.myDoctors);
                  },
                ),
                1,
                totalItems,
              ),
              const SizedBox(height: 6),
              _buildOrbitalItem(
                _MenuItem(
                  icon: Icons.assignment_rounded,
                  title: "Records",
                  textColor: textColor,
                  onTap: () {
                    widget.onClose();
                    final routeUri = Uri(
                      path: AppRoutes.medicalRecords,
                      queryParameters: {
                        'nonce': DateTime.now().microsecondsSinceEpoch.toString(),
                      },
                    ).toString();
                    context.push(routeUri);
                  },
                ),
                2,
                totalItems,
              ),
              const SizedBox(height: 6),
              _buildOrbitalItem(
                _MenuItem(
                  icon: Icons.calendar_month_rounded,
                  title: "Schedule",
                  textColor: textColor,
                  onTap: () {
                    widget.onClose();
                    widget.onNavigateToTab(2);
                  },
                ),
                3,
                totalItems,
              ),
              const SizedBox(height: 6),
              _buildOrbitalItem(
                _MenuItem(
                  icon: Icons.settings_rounded,
                  title: "Settings",
                  textColor: textColor,
                  onTap: () {
                    widget.onClose();
                    context.push(AppRoutes.settings);
                  },
                ),
                4,
                totalItems,
              ),
              const Spacer(),
              _buildOrbitalItem(
                _MenuItem(
                  icon: Icons.logout_rounded,
                  title: "Log Out",
                  textColor: Colors.redAccent,
                  isLogout: true,
                  onTap: () => _showLogoutDialog(context),
                ),
                5,
                totalItems,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color textColor;
  final bool isLogout;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    required this.textColor,
    this.isLogout = false,
  });

  @override
  State<_MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<_MenuItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconBgColor =
        widget.isLogout
            ? Colors.redAccent.withValues(alpha: 0.1)
            : AppColors.primaryGreen.withValues(alpha: isDark ? 0.15 : 0.1);
    final iconColor =
        widget.isLogout ? Colors.redAccent : AppColors.primaryGreen;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        HapticFeedback.selectionClick();
        setState(() => _isHovered = true);
      },
      onTapUp: (_) {
        setState(() => _isHovered = false);
        Future.delayed(const Duration(milliseconds: 100), widget.onTap);
      },
      onTapCancel: () => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color:
              _isHovered
                  ? widget.textColor.withValues(alpha: 0.05)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(widget.icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Text(
              widget.title,
              style: TextStyle(
                color: widget.textColor.withValues(alpha: _isHovered ? 0.7 : 1),
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
