import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/menu/custom_drawer.dart';

// --- DOCTORS SCREEN PLACEHOLDER ---
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
  final Color primaryGreen = const Color(0xFF00C689);
  final Color drawerBgColor = const Color(0xFF626F8D); // Dark Blue-Grey

  late AnimationController _drawerController;
  final double _maxSlide = 290.0; // Max distance for the front card

  // Gesture State
  bool _isDraggingDrawer = false;

  @override
  void initState() {
    super.initState();
    _drawerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _drawerController.dispose();
    super.dispose();
  }

  // --- NAVIGATION LOGIC ---
  void _goToBranch(int index) {
    // 1. Navigate to the selected tab (Works for ALL tabs, including Profile)
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );

    // 2. If the drawer happens to be open, close it smoothly
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

  // --- GESTURE LOGIC ---
  void _onHorizontalDragStart(DragStartDetails details) {
    bool isDrawerOpen = _drawerController.value > 0;
    if (isDrawerOpen || details.globalPosition.dx < 60) {
      _isDraggingDrawer = true;
    } else {
      _isDraggingDrawer = false;
    }
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (_isDraggingDrawer) {
      double delta = details.primaryDelta! / _maxSlide;
      _drawerController.value += delta;
    } else if (widget.navigationShell.currentIndex == 0 &&
        details.primaryDelta! > 0 &&
        _drawerController.value == 0) {
      _isDraggingDrawer = true;
      double delta = details.primaryDelta! / _maxSlide;
      _drawerController.value += delta;
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_isDraggingDrawer) {
      if (_drawerController.value > 0.5 ||
          (details.primaryVelocity ?? 0) > 300) {
        _drawerController.forward();
      } else {
        _drawerController.reverse();
      }
      _isDraggingDrawer = false;
      return;
    }

    double velocity = details.primaryVelocity ?? 0;
    int currentIndex = widget.navigationShell.currentIndex;

    if (velocity < -500 && currentIndex < 3) {
      // Ensure we don't go past the last tab
      _goToBranch(currentIndex + 1);
    } else if (velocity > 500 && currentIndex > 0) {
      _goToBranch(currentIndex - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: drawerBgColor,
      body: Stack(
        children: [
          // -----------------------------------------------------------
          // LAYER 1: THE "BACK" CARD (Doctors Page Placeholder)
          // -----------------------------------------------------------
          AnimatedBuilder(
            animation: _drawerController,
            builder: (context, child) {
              double slide = 265 * _drawerController.value;
              double scale = 1 - (_drawerController.value * 0.45);
              double rotate = 0.0;

              return Transform(
                transform:
                    Matrix4.identity()
                      ..translate(slide)
                      ..scale(scale)
                      ..rotateZ(rotate),
                alignment: Alignment.centerLeft,
                child: Opacity(
                  opacity: _drawerController.value,
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
                            color: Colors.black.withValues(alpha: 0.1),
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
                              color: drawerBgColor.withValues(
                                alpha: 0.8 * _drawerController.value,
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

          // -----------------------------------------------------------
          // LAYER 2: THE MENU
          // -----------------------------------------------------------
          SafeArea(
            child: SizedBox(
              width: 260,
              child: CustomDrawer(
                onClose: _toggleDrawer,
                onNavigateToTab: _goToBranch,
              ),
            ),
          ),

          // -----------------------------------------------------------
          // LAYER 3: MAIN APP CONTENT (Front Card)
          // -----------------------------------------------------------
          GestureDetector(
            onHorizontalDragStart: _onHorizontalDragStart,
            onHorizontalDragUpdate: _onHorizontalDragUpdate,
            onHorizontalDragEnd: _onHorizontalDragEnd,
            behavior: HitTestBehavior.translucent,
            child: AnimatedBuilder(
              animation: _drawerController,
              builder: (context, child) {
                double slide = _maxSlide * _drawerController.value;
                double scale = 1 - (_drawerController.value * 0.3);
                bool isDrawerOpen = _drawerController.value > 0.1;

                return Transform(
                  transform:
                      Matrix4.identity()
                        ..translate(slide)
                        ..scale(scale),
                  alignment: Alignment.centerLeft,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      _drawerController.value * 40,
                    ),
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
          ),

          // -----------------------------------------------------------
          // LAYER 4: FLOATING CLOSE BUTTON
          // -----------------------------------------------------------
          AnimatedBuilder(
            animation: _drawerController,
            builder: (context, child) {
              if (_drawerController.value < 0.2) return const SizedBox.shrink();
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
    );
  }
}
