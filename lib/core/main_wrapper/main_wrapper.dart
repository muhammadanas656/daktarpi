import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../features/menu/presentation/widgets/custom_drawer.dart';
import '../../features/doctors/presentation/screens/doctors_screen.dart';
import '../../features/appointments/presentation/appointment_notifier.dart';
import '../../features/profile/presentation/profile_notifier.dart';
import '../../features/settings/presentation/settings_notifier.dart';
import '../theme/app_motion.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';

class MainWrapper extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainWrapper({super.key, required this.navigationShell});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const Curve _openCurve = Curves.easeOutQuint;
  static const Curve _closeCurve = Curves.easeOutCirc;

  late AnimationController _drawerController;
  final double _maxSlide = 290.0;

  bool _isDraggingDrawer = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _drawerController = AnimationController(
      vsync: this,
      duration: AppMotion.defaultDuration,
    );

    AppointmentNotifier.instance.initializeRealtime();
    unawaited(AppointmentNotifier.instance.fetchAppointments());
    unawaited(ProfileNotifier.instance.loadProfile());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runIntroTutorial();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(AppointmentNotifier.instance.fetchAppointments());
      unawaited(ProfileNotifier.instance.loadProfile());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _drawerController.dispose();
    super.dispose();
  }

  Future<void> _runIntroTutorial() async {
    await SettingsNotifier.instance.loadSettings();
    if (!SettingsNotifier.instance.showDrawerHint) {
      return;
    }

    if (widget.navigationShell.currentIndex != 0) {
      return;
    }

    await Future.delayed(const Duration(milliseconds: 3500));
    if (!mounted) {
      return;
    }

    try {
      await _drawerController.animateTo(
        0.15,
        duration: const Duration(milliseconds: 1600),
        curve: _openCurve,
      );

      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) {
        return;
      }

      await _drawerController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 1200),
        curve: _closeCurve,
      );
    } catch (e) {
      debugPrint("Animation interrupted: $e");
    }
  }

  void _goToBranch(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
    if (_drawerController.value > 0) {
      _drawerController.reverse();
    }
  }

  void _toggleDrawer() {
    if (_drawerController.isDismissed) {
      FocusManager.instance.primaryFocus?.unfocus();
      _drawerController.forward();
    } else {
      _drawerController.reverse();
    }
  }

  void _onDragStart(DragStartDetails details) {
    _isDraggingDrawer = false;
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (widget.navigationShell.currentIndex != 0) {
      return;
    }

    double delta = details.primaryDelta! / _maxSlide;
    if (_drawerController.value > 0 || delta > 0) {
      _drawerController.value += delta;
    }
    if (_drawerController.value > 0.0) {
      _isDraggingDrawer = true;
    }
  }

  void _onDragEnd(DragEndDetails details) {
    double velocity = details.primaryVelocity ?? 0;
    int currentIndex = widget.navigationShell.currentIndex;

    if (_isDraggingDrawer || _drawerController.value > 0.0) {
      if (velocity.abs() > 200) {
        velocity > 0
            ? _drawerController.forward()
            : _drawerController.reverse();
      } else {
        _drawerController.value > 0.5
            ? _drawerController.forward()
            : _drawerController.reverse();
      }
      _isDraggingDrawer = false;
      return;
    }

    if (_drawerController.isDismissed && velocity.abs() > 300) {
      if (velocity < 0) {
        if (currentIndex < 3) {
          _goToBranch(currentIndex + 1);
        }
      } else {
        currentIndex > 0
            ? _goToBranch(currentIndex - 1)
            : _drawerController.forward();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dynamicDrawerBg =
        isDark ? const Color(0xFF162236) : const Color(0xFF626F8D);
    final size = MediaQuery.sizeOf(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        if (_drawerController.value > 0) {
          _drawerController.reverse();
          return;
        }

        final String location = GoRouterState.of(context).uri.path;
        final bool isRootTab =
            location == '/home' ||
            location == '/doctors' ||
            location == '/appointments' ||
            location == '/profile';

        if (isRootTab) {
          SystemNavigator.pop();
        } else {
          context.pop();
        }
      },
      child: Scaffold(
        backgroundColor: dynamicDrawerBg,
        resizeToAvoidBottomInset: false,
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          child: Stack(
            children: [
              // LAYER 1: BACK CARD
              AnimatedBuilder(
                animation: _drawerController,
                builder: (context, child) {
                  double slide = 265 * _drawerController.value;
                  double scale = 1 - (_drawerController.value * 0.45);

                  return Transform(
                    transform:
                        Matrix4.identity()
                          ..translate(slide)
                          ..scale(scale),
                    alignment: Alignment.centerLeft,
                    child: AbsorbPointer(
                      absorbing: true,
                      child: Container(
                        width: size.width,
                        height: size.height,
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: AppStyles.cardShadow(context),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: Stack(
                            children: [
                              Container(
                                color:
                                    Theme.of(context).scaffoldBackgroundColor,
                              ),
                              const RepaintBoundary(
                                child: IgnorePointer(
                                  child: DoctorsScreen(isBackgroundLayer: true),
                                ),
                              ),
                              Container(
                                color: dynamicDrawerBg.withValues(
                                  alpha: (0.8 * _drawerController.value).clamp(
                                    0.0,
                                    1.0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              // LAYER 2: MENU
              SafeArea(
                child: SizedBox(
                  width: 260,
                  child: CustomDrawer(
                    onClose: _toggleDrawer,
                    onNavigateToTab: _goToBranch,
                  ),
                ),
              ),

              // LAYER 3: FRONT CARD
              AnimatedBuilder(
                animation: _drawerController,
                builder: (context, child) {
                  double slide = _maxSlide * _drawerController.value;
                  double scale = 1 - (_drawerController.value * 0.3);
                  bool isDrawerOpen = _drawerController.value > 0.1;
                  double cornerRadius = (_drawerController.value * 400).clamp(
                    0.0,
                    40.0,
                  );

                  return Transform(
                    transform:
                        Matrix4.identity()
                          ..translate(slide)
                          ..scale(scale),
                    alignment: Alignment.centerLeft,
                    child: RepaintBoundary(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(cornerRadius),
                        child: Container(
                          decoration: BoxDecoration(
                            boxShadow: AppStyles.drawerShadow(context),
                          ),
                          child: AbsorbPointer(
                            absorbing: isDrawerOpen,
                            child: child,
                          ),
                        ),
                      ),
                    ),
                  );
                },
                child: Scaffold(
                  body: SizedBox.expand(
                    child: AnimatedSwitcher(
                      duration: AppMotion.defaultDuration,
                      child: widget.navigationShell,
                    ),
                  ),
                  bottomNavigationBar: NavigationBar(
                    selectedIndex: widget.navigationShell.currentIndex,
                    onDestinationSelected: _goToBranch,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    indicatorColor: AppColors.primaryGreen.withValues(
                      alpha: 0.15,
                    ),
                    elevation: 0,
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(
                          Icons.home_rounded,
                          color: AppColors.primaryGreen,
                        ),
                        label: 'Home',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.medical_services_outlined),
                        selectedIcon: Icon(
                          Icons.medical_services_rounded,
                          color: AppColors.primaryGreen,
                        ),
                        label: 'Doctors',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.assignment_outlined),
                        selectedIcon: Icon(
                          Icons.assignment_rounded,
                          color: AppColors.primaryGreen,
                        ),
                        label: 'Appointment',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.account_circle_outlined),
                        selectedIcon: Icon(
                          Icons.account_circle_rounded,
                          color: AppColors.primaryGreen,
                        ),
                        label: 'Profile',
                      ),
                    ],
                  ),
                ),
              ),

              // LAYER 4: CLOSE BUTTON
              AnimatedBuilder(
                animation: _drawerController,
                builder: (context, child) {
                  // PRO FIX: Added curly braces to satisfy dart linting rules
                  if (_drawerController.value < 0.2) {
                    return const SizedBox.shrink();
                  }

                  return Positioned(
                    top: 60,
                    right: 30,
                    child: Opacity(
                      opacity: _drawerController.value,
                      child: GestureDetector(
                        onTap: _toggleDrawer,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
