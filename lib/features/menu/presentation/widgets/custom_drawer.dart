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
  final ValueNotifier<Offset> pointerNotifier;

  const CustomDrawer({
    super.key,
    required this.onClose,
    required this.onNavigateToTab,
    required this.drawerAnimation,
    required this.pointerNotifier,
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

  Widget _buildStaggeredItem(Widget child, int index) {
    return AnimatedBuilder(
      animation: widget.drawerAnimation,
      builder: (context, childWidget) {
        final start = (index * 0.06).clamp(0.0, 1.0);
        final end = (start + 0.4).clamp(0.0, 1.0);

        final curve = CurvedAnimation(
          parent: widget.drawerAnimation,
          curve: Interval(start, end, curve: Curves.easeOutBack),
        );

        return Transform.scale(
          scale: 0.8 + (0.2 * curve.value),
          child: Transform.translate(
            offset: Offset(-40 * (1 - curve.value), 0),
            child: Opacity(
              opacity: curve.value.clamp(0.0, 1.0),
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
            : "";
    final avatar = _profileNotifier.avatarUrl;

    return Stack(
      children: [
        AnimatedBuilder(
          animation: Listenable.merge([
            widget.pointerNotifier,
            widget.drawerAnimation,
          ]),
          builder: (context, child) {
            final pointer = widget.pointerNotifier.value;
            return Positioned(
              left: pointer.dx - 250,
              top: pointer.dy - 250,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: widget.drawerAnimation.value > 0.1 ? 1.0 : 0.0,
                child: Container(
                  width: 500,
                  height: 500,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primaryGreen.withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 1.0],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(left: 30, top: 40, bottom: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStaggeredItem(
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryGreen.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.white10,
                          child:
                              avatar != null && avatar.isNotEmpty
                                  ? AppNetworkImage(
                                    imageUrl: avatar,
                                    width: 72,
                                    height: 72,
                                    circular: true,
                                  )
                                  : const Icon(
                                    Icons.person,
                                    color: Colors.white54,
                                    size: 36,
                                  ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            if (phone.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  phone,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  0,
                ),
                const Spacer(),
                _buildStaggeredItem(
                  _TactileHUDItem(
                    icon: Icons.person_outline_rounded,
                    title: "Doctors",
                    onTap: () {
                      widget.onClose();
                      context.push(AppRoutes.myDoctors);
                    },
                  ),
                  1,
                ),
                const SizedBox(height: 28),
                _buildStaggeredItem(
                  _TactileHUDItem(
                    icon: Icons.assignment_outlined,
                    title: "Records",
                    onTap: () {
                      widget.onClose();
                      context.push(AppRoutes.medicalRecords);
                    },
                  ),
                  2,
                ),
                const SizedBox(height: 28),
                _buildStaggeredItem(
                  _TactileHUDItem(
                    icon: Icons.calendar_today_rounded,
                    title: "Schedule",
                    onTap: () {
                      widget.onClose();
                      widget.onNavigateToTab(2);
                    },
                  ),
                  3,
                ),
                const SizedBox(height: 28),
                _buildStaggeredItem(
                  _TactileHUDItem(
                    icon: Icons.settings_outlined,
                    title: "Settings",
                    onTap: () {
                      widget.onClose();
                      context.push(AppRoutes.settings);
                    },
                  ),
                  4,
                ),
                const Spacer(),
                _buildStaggeredItem(
                  _TactileHUDItem(
                    icon: Icons.logout_rounded,
                    title: "Log Out",
                    color: Colors.redAccent,
                    onTap: () => _showLogoutDialog(context),
                  ),
                  5,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TactileHUDItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;

  const _TactileHUDItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
  });

  @override
  State<_TactileHUDItem> createState() => _TactileHUDItemState();
}

class _TactileHUDItemState extends State<_TactileHUDItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.color ?? Colors.white;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        HapticFeedback.heavyImpact();
        setState(() => _isPressed = true);
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        Future.delayed(const Duration(milliseconds: 100), widget.onTap);
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: _isPressed ? 0.5 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Row(
            children: [
              Icon(
                widget.icon,
                color: baseColor.withValues(alpha: 0.3),
                size: 30,
              ),
              const SizedBox(width: 20),
              Text(
                widget.title,
                style: TextStyle(
                  color: baseColor,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
