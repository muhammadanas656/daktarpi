import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../features/menu/presentation/widgets/custom_drawer.dart';
import '../../features/doctors/presentation/screens/doctors_screen.dart';
import '../../features/settings/presentation/settings_notifier.dart';

class MainWrapper extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainWrapper({super.key, required this.navigationShell});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper>
    with SingleTickerProviderStateMixin {
  static const Curve _openCurve = Curves.easeOutQuint;
  static const Curve _closeCurve = Curves.easeOutCirc;

  final Color primaryGreen = const Color(0xFF00C689);
  final Color drawerBgColor = const Color(0xFF626F8D);

  late AnimationController _drawerController;
  final double _maxSlide = 290.0;

  bool _isDraggingDrawer = false;

  @override
  void initState() {
    super.initState();
    _drawerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runIntroTutorial();
    });
  }

  @override
  void dispose() {
    _drawerController.dispose();
    super.dispose();
  }

  Future<void> _runIntroTutorial() async {
    // Check setting before running hint
    await SettingsNotifier.instance.loadSettings(); 
    if (!SettingsNotifier.instance.showDrawerHint) return;

    if (widget.navigationShell.currentIndex != 0) return;

    await Future.delayed(const Duration(milliseconds: 3500));
    if (!mounted) return;

    try {
      await _drawerController.animateTo(
        0.15,
        duration: const Duration(milliseconds: 1600),
        curve: _openCurve,
      );

      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;

      await _drawerController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 1200),
        curve: _closeCurve,
      );
    } catch (e) {
      debugPrint("Animation interrupted: $e");
    }
  }

  // --- NAVIGATION ---
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
      _drawerController.forward();
    } else {
      _drawerController.reverse();
    }
  }

  // --- GESTURES ---
  void _onDragStart(DragStartDetails details) {
    _isDraggingDrawer = false;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    // FIX: Only allow drawer drag on Home Screen (index 0)
    // User requested to remove global swipe
    if (widget.navigationShell.currentIndex != 0) return;

    double delta = details.primaryDelta! / _maxSlide;

    // Only allow dragging open (positive delta) or closing if already open
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

    // 1. Handle Drawer Snap Logic
    if (_isDraggingDrawer || _drawerController.value > 0.0) {
      // If moving fast, snap based on direction
      // REDUCED THRESHOLD: 400 -> 200 for easier sensitivity
      if (velocity.abs() > 200) { 
        if (velocity > 0) {
          _drawerController.forward();
        } else {
          _drawerController.reverse();
        }
      } else {
        // If moving slow, snap based on position (>50% open)
        if (_drawerController.value > 0.5) {
          _drawerController.forward();
        } else {
          _drawerController.reverse();
        }
      }
      _isDraggingDrawer = false;
      return;
    }

    // 2. Handle Tab Switching Swipe Logic
    // Only allow swipe switching if drawer is closed
    if (_drawerController.isDismissed && velocity.abs() > 300) {
      if (velocity < 0) {
        // Swipe Left -> Next Tab
        if (currentIndex < 3) {
          _goToBranch(currentIndex + 1);
        }
      } else {
        // Swipe Right -> Open Drawer (on any screen if at edge, or previous tab)
        // Improved logic: If user swipes right significantly, we prioritized drawer above.
        // But if drawer detected no drag (e.g. started in middle), we handle tabs.
        
        if (currentIndex > 0) { 
           _goToBranch(currentIndex - 1);
        } else {
           // On Home, swipe right opens drawer (handled by drag update usually, but fallback here)
           _drawerController.forward();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

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
        backgroundColor: drawerBgColor,
        body: GestureDetector(
          // Allow gestures to pass through to child widgets (like lists)
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          child: Stack(
            children: [
              // LAYER 1: BACK CARD (Doctors Screen visual)
              AnimatedBuilder(
                animation: _drawerController,
                builder: (context, child) {
                  double slide = 265 * _drawerController.value;
                  double scale = 1 - (_drawerController.value * 0.45);
                  double rotate = 0.0;
                  double fade = (_drawerController.value * 6).clamp(0.0, 1.0);

                  return Transform(
                    transform:
                        Matrix4.identity()
                          ..translate(slide)
                          ..scale(scale)
                          ..rotateZ(rotate),
                    alignment: Alignment.centerLeft,
                    child: Opacity(
                      opacity: fade,
                      child: AbsorbPointer(
                        absorbing: true,
                        child: Container(
                          width: size.width,
                          height: size.height,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(-15, 15),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: Stack(
                              children: [
                                const DoctorsScreen(),
                                Container(
                                  color: drawerBgColor.withValues(alpha: 
                                    (0.8 * _drawerController.value)
                                        .clamp(0.0, 1.0),
                                  ),
                                ),
                              ],
                            ),
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
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(cornerRadius),
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 40,
                              offset: const Offset(-30, 30),
                            ),
                          ],
                        ),
                        child: AbsorbPointer(
                          absorbing: isDrawerOpen,
                          child: child,
                        ),
                      ),
                    ),
                  );
                },
                child: Scaffold(
                  body: SizedBox.expand(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: widget.navigationShell,
                    ),
                  ),
                  bottomNavigationBar: NavigationBar(
                    selectedIndex: widget.navigationShell.currentIndex,
                    onDestinationSelected: _goToBranch,
                    backgroundColor: Colors.white,
                    indicatorColor: primaryGreen.withValues(alpha: 0.15),
                    elevation: 0,
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(
                          Icons.home_rounded,
                          color: Color(0xFF00C689),
                        ),
                        label: 'Home',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.medical_services_outlined),
                        selectedIcon: Icon(
                          Icons.medical_services_rounded,
                          color: Color(0xFF00C689),
                        ),
                        label: 'Doctors',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.assignment_outlined),
                        selectedIcon: Icon(
                          Icons.assignment_rounded,
                          color: Color(0xFF00C689),
                        ),
                        label: 'Appointment',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.account_circle_outlined),
                        selectedIcon: Icon(
                          Icons.account_circle_rounded,
                          color: Color(0xFF00C689),
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
                            color: Colors.red,
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
