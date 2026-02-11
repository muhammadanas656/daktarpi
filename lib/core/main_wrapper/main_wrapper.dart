import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../features/menu/custom_drawer.dart';

// --- DOCTORS SCREEN PLACEHOLDER (Visual for Back Card) ---
class DoctorsScreen extends StatelessWidget {
  const DoctorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          "Find Your Doctor",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medical_services, size: 80, color: Colors.grey[200]),
            const SizedBox(height: 16),
            Text(
              "Doctors List",
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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

  // Track if we are currently manipulating the drawer
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
    // Only run intro if on Home tab
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
    // Always close drawer when navigating
    if (_drawerController.value > 0) {
      _drawerController.reverse();
    }
  }

  void _toggleDrawer() {
    // Only allow toggling if on Home Screen
    if (widget.navigationShell.currentIndex != 0) return;

    if (_drawerController.isDismissed) {
      _drawerController.forward();
    } else {
      _drawerController.reverse();
    }
  }

  // --- ⚡ SMART ROUTING GESTURES ⚡ ---

  void _onDragStart(DragStartDetails details) {
    _isDraggingDrawer = false;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    // 1. If we are NOT on Home Tab, we NEVER move the drawer visually.
    if (widget.navigationShell.currentIndex != 0) return;

    double delta = details.primaryDelta! / _maxSlide;

    // 2. Only allow opening (positive delta) if closed, or any movement if already open
    if (_drawerController.value > 0 || delta > 0) {
      _drawerController.value += delta;
    }

    // 3. Flag that we are interacting with the drawer
    if (_drawerController.value > 0.0) {
      _isDraggingDrawer = true;
    }
  }

  void _onDragEnd(DragEndDetails details) {
    double velocity = details.primaryVelocity ?? 0;
    int currentIndex = widget.navigationShell.currentIndex;

    // --- CASE A: DRAWER IS ACTIVE (Home Tab Only) ---
    if (_isDraggingDrawer || _drawerController.value > 0.0) {
      // If user swiped fast or dragged past 50%
      if (velocity.abs() > 400) {
        if (velocity > 0)
          _drawerController.forward(); // Open
        else
          _drawerController.reverse(); // Close
      } else {
        if (_drawerController.value > 0.5)
          _drawerController.forward();
        else
          _drawerController.reverse();
      }
      _isDraggingDrawer = false;
      return;
    }

    // --- CASE B: TAB SWITCHING (Drawer is Closed) ---
    // Require a deliberate swipe (> 300 velocity)
    if (velocity.abs() > 300) {
      if (velocity < 0) {
        // <<< SWIPE LEFT (Next Tab)
        if (currentIndex < 3) {
          _goToBranch(currentIndex + 1);
        }
      } else {
        // >>> SWIPE RIGHT (Previous Tab OR Open Drawer)

        // If we are on Home (Index 0), Swipe Right opens Drawer
        if (currentIndex == 0) {
          _drawerController.forward();
        }
        // If we are on any other tab, Swipe Right goes to Previous Tab
        else {
          _goToBranch(currentIndex - 1);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
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
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          behavior: HitTestBehavior.translucent,
          child: Stack(
            children: [
              // LAYER 1: BACK CARD (Decoration)
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
                          width: MediaQuery.of(context).size.width,
                          height: MediaQuery.of(context).size.height,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(-15, 15),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(30),
                                child: const DoctorsScreen(),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: drawerBgColor.withOpacity(
                                    (0.8 * _drawerController.value).clamp(
                                      0.0,
                                      1.0,
                                    ),
                                  ),
                                  borderRadius: BorderRadius.circular(30),
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

              // LAYER 3: FRONT CARD (Main App)
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
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 40,
                              offset: const Offset(-30, 30),
                            ),
                          ],
                        ),
                        // Only absorb pointers if drawer is actively open
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
                    indicatorColor: primaryGreen.withOpacity(0.15),
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
                                color: Colors.black.withOpacity(0.3),
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
