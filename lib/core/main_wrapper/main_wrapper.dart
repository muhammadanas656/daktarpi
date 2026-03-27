import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../features/appointments/presentation/appointment_notifier.dart';
import '../../features/menu/presentation/widgets/custom_drawer.dart';
import '../../features/profile/presentation/profile_notifier.dart';
import '../theme/app_colors.dart';

class MainWrapper extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainWrapper({super.key, required this.navigationShell});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _drawerController;
  late AnimationController _springController;

  final ValueNotifier<double> _tabDragNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<double> _depthTensionNotifier = ValueNotifier<double>(
    0.0,
  );

  bool _hasFiredThresholdHaptic = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _drawerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    AppointmentNotifier.instance.initializeRealtime();
    unawaited(AppointmentNotifier.instance.fetchAppointments());
    unawaited(ProfileNotifier.instance.loadProfile());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        AppointmentNotifier.instance.fetchAppointments(isBackground: true),
      );
      unawaited(ProfileNotifier.instance.loadProfile());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _drawerController.dispose();
    _springController.dispose();
    _tabDragNotifier.dispose();
    _depthTensionNotifier.dispose();
    super.dispose();
  }

  void _closeDrawerWithHaptic() {
    _drawerController
        .animateTo(0.0, curve: Curves.easeOutQuint)
        .then((_) => HapticFeedback.selectionClick());
  }

  void _openDrawerWithHaptic() {
    _drawerController
        .animateTo(1.0, curve: Curves.easeOutQuint)
        .then((_) => HapticFeedback.selectionClick());
  }

  void _goToBranch(int index) {
    if (index == widget.navigationShell.currentIndex) {
      if (_drawerController.value > 0) {
        _closeDrawerWithHaptic();
      }
      return;
    }

    if (_springController.isAnimating) _springController.stop();
    _tabDragNotifier.value = 0.0;
    _depthTensionNotifier.value = 0.0;

    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );

    if (_drawerController.value > 0) {
      _closeDrawerWithHaptic();
    }
  }

  void _toggleDrawer() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_drawerController.isDismissed) {
      _drawerController
          .animateTo(1.0, curve: Curves.easeOutBack)
          .then((_) => HapticFeedback.mediumImpact());
    } else {
      _drawerController
          .animateTo(0.0, curve: Curves.easeOutQuint)
          .then((_) => HapticFeedback.selectionClick());
    }
  }

  void _onDragStart(DragStartDetails details) {
    if (_springController.isAnimating) _springController.stop();
    _depthTensionNotifier.value = _tabDragNotifier.value.abs();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    int currentIndex = widget.navigationShell.currentIndex;
    final screenWidth = MediaQuery.sizeOf(context).width;

    double drawerDelta = details.primaryDelta! / (screenWidth * 0.65);
    double tabDelta = details.primaryDelta! / screenWidth;

    if (_drawerController.value > 0.0 ||
        (currentIndex == 0 &&
            _tabDragNotifier.value == 0.0 &&
            details.primaryDelta! > 0)) {
      _drawerController.value = (_drawerController.value + drawerDelta).clamp(
        0.0,
        1.0,
      );
      return;
    }

    double newVal = (_tabDragNotifier.value + tabDelta).clamp(-1.0, 1.0);
    if (currentIndex == 0 && newVal > 0) newVal = 0.0;
    if (currentIndex == 3 && newVal < 0) newVal = 0.0;

    _tabDragNotifier.value = newVal;
    _depthTensionNotifier.value = newVal.abs();

    if (newVal.abs() >= 0.25 && !_hasFiredThresholdHaptic) {
      HapticFeedback.selectionClick();
      _hasFiredThresholdHaptic = true;
    } else if (newVal.abs() < 0.25) {
      _hasFiredThresholdHaptic = false;
    }
  }

  void _onDragEnd(DragEndDetails details) {
    double velocity = details.primaryVelocity ?? 0;
    int currentIndex = widget.navigationShell.currentIndex;

    if (_drawerController.value > 0.0) {
      if (velocity.abs() > 200) {
        velocity > 0
            ? _drawerController
                .animateTo(1.0, curve: Curves.easeOutBack)
                .then((_) => HapticFeedback.mediumImpact())
            : _drawerController
                .animateTo(0.0, curve: Curves.easeOutQuint)
                .then((_) => HapticFeedback.selectionClick());
      } else {
        _drawerController.value > 0.5
            ? _drawerController
                .animateTo(1.0, curve: Curves.easeOutBack)
                .then((_) => HapticFeedback.mediumImpact())
            : _drawerController
                .animateTo(0.0, curve: Curves.easeOutQuint)
                .then((_) => HapticFeedback.selectionClick());
      }
      return;
    }

    final dragVal = _tabDragNotifier.value;
    bool isFlickNext = velocity < -300 && dragVal < 0;
    bool isFlickPrev = velocity > 300 && dragVal > 0;
    bool isPastThreshold = dragVal.abs() >= 0.25;

    if (isFlickNext || (isPastThreshold && dragVal < 0)) {
      if (currentIndex < 3) {
        widget.navigationShell.goBranch(currentIndex + 1);
        _tabDragNotifier.value = 0.0;
        _animateDepthToZero();
      } else {
        _animateBothToZero();
      }
    } else if (isFlickPrev || (isPastThreshold && dragVal > 0)) {
      if (currentIndex > 0) {
        widget.navigationShell.goBranch(currentIndex - 1);
        _tabDragNotifier.value = 0.0;
        _animateDepthToZero();
      } else {
        _animateBothToZero();
      }
    } else {
      _animateBothToZero();
    }
  }

  void _animateDepthToZero() {
    _hasFiredThresholdHaptic = false;
    _springController.duration = const Duration(milliseconds: 320);
    final Animation<double> anim = Tween<double>(
      begin: _depthTensionNotifier.value,
      end: 0.0,
    ).animate(
      CurvedAnimation(parent: _springController, curve: Curves.easeOutQuint),
    );
    void listener() => _depthTensionNotifier.value = anim.value;
    anim.addListener(listener);
    _springController
        .forward(from: 0.0)
        .then((_) => anim.removeListener(listener));
  }

  void _animateBothToZero() {
    _hasFiredThresholdHaptic = false;
    _springController.duration = const Duration(milliseconds: 250);
    final Animation<double> anim = Tween<double>(
      begin: _tabDragNotifier.value,
      end: 0.0,
    ).animate(
      CurvedAnimation(parent: _springController, curve: Curves.easeOutCubic),
    );
    void listener() {
      _tabDragNotifier.value = anim.value;
      _depthTensionNotifier.value = anim.value.abs();
    }

    anim.addListener(listener);
    _springController
        .forward(from: 0.0)
        .then((_) => anim.removeListener(listener));
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canvasColor =
        isDark ? const Color(0xFF0D1217) : const Color(0xFFF4F7F9);

    return Scaffold(
      backgroundColor: canvasColor,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: _onDragStart,
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        child: Stack(
          children: [
            CustomDrawer(
              onClose: _toggleDrawer,
              onNavigateToTab: _goToBranch,
              drawerAnimation: _drawerController,
            ),
            AnimatedBuilder(
              animation: Listenable.merge([
                _tabDragNotifier,
                _depthTensionNotifier,
                _drawerController,
              ]),
              builder: (context, child) {
                final double tabTension = _depthTensionNotifier.value;
                final double drawerVal = _drawerController.value;

                final double scale =
                    1.0 - (tabTension * 0.05) - (drawerVal * 0.12);
                final double translateX = drawerVal * (screenWidth * 0.62);
                final double radius = (tabTension * 32.0) + (drawerVal * 48.0);
                final double rotateY = drawerVal * -0.06;

                return Transform(
                  alignment: Alignment.centerLeft,
                  transform:
                      Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..translate(translateX, 0.0, 0.0)
                        ..scale(scale)
                        ..rotateY(rotateY),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      border:
                          drawerVal > 0.05
                              ? Border.all(
                                color: Colors.white.withValues(
                                  alpha: drawerVal * 0.15,
                                ),
                                width: 1.0,
                              )
                              : null,
                      boxShadow:
                          drawerVal > 0.05 || tabTension > 0.05
                              ? [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: isDark ? 0.5 : 0.08,
                                  ),
                                  blurRadius: 50,
                                  spreadRadius: 0,
                                  offset: const Offset(-20, 0),
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: isDark ? 0.3 : 0.04,
                                  ),
                                  blurRadius: 15,
                                  spreadRadius: -5,
                                  offset: const Offset(-5, 0),
                                ),
                                BoxShadow(
                                  color: Colors.white.withValues(
                                    alpha: isDark ? 0.05 : 0.4,
                                  ),
                                  blurRadius: 2,
                                  spreadRadius: 0,
                                  offset: const Offset(-1, 0),
                                ),
                              ]
                              : const [],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        RepaintBoundary(
                          child: Container(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            child: widget.navigationShell,
                          ),
                        ),
                        if (drawerVal > 0)
                          GestureDetector(
                            onTap: _toggleDrawer,
                            child: Container(color: Colors.transparent),
                          ),
                        if (tabTension > 0 || drawerVal > 0)
                          IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withValues(
                                      alpha: drawerVal * 0.08,
                                    ),
                                    Colors.black.withValues(
                                      alpha: drawerVal * 0.22,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            Positioned(
              bottom: MediaQuery.paddingOf(context).bottom + 20,
              left: 20,
              right: 20,
              child: AnimatedBuilder(
                animation: _drawerController,
                builder: (context, child) {
                  return IgnorePointer(
                    ignoring: _drawerController.value > 0.0,
                    child: Transform.translate(
                      offset: Offset(0, _drawerController.value * 100),
                      child: Opacity(
                        opacity:
                            (1.0 - (_drawerController.value * 2))
                                .clamp(0.0, 1.0)
                                .toDouble(),
                        child: child,
                      ),
                    ),
                  );
                },
                child: RepaintBoundary(
                  child: _HolographicFluidDock(
                    selectedIndex: widget.navigationShell.currentIndex,
                    onTap: _goToBranch,
                    tabDragNotifier: _tabDragNotifier,
                    depthTensionNotifier: _depthTensionNotifier,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HolographicFluidDock extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final ValueNotifier<double> tabDragNotifier;
  final ValueNotifier<double> depthTensionNotifier;

  const _HolographicFluidDock({
    required this.selectedIndex,
    required this.onTap,
    required this.tabDragNotifier,
    required this.depthTensionNotifier,
  });

  @override
  State<_HolographicFluidDock> createState() => _HolographicFluidDockState();
}

class _HolographicFluidDockState extends State<_HolographicFluidDock>
    with TickerProviderStateMixin {
  late AnimationController _lightSweepController;
  late AnimationController _morphController;
  late Animation<double> _stretchAnimation;

  double _morphDirection = 1.0;

  @override
  void initState() {
    super.initState();
    _lightSweepController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _morphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _stretchAnimation = TweenSequence([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 50,
      ),
    ]).animate(_morphController);
  }

  @override
  void didUpdateWidget(covariant _HolographicFluidDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      _morphDirection =
          widget.selectedIndex > oldWidget.selectedIndex ? 1.0 : -1.0;
      _morphController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _lightSweepController.dispose();
    _morphController.dispose();
    super.dispose();
  }

  Color _getAmbientGlow(int index) {
    switch (index) {
      case 0:
        return AppColors.primaryGreen;
      case 1:
        return const Color(0xFF007BFF);
      case 2:
        return const Color(0xFFFF9F00);
      case 3:
        return const Color(0xFF8E44AD);
      default:
        return AppColors.primaryGreen;
    }
  }

  void _handleTabTap(int index) {
    if (widget.selectedIndex == index) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.selectionClick();
      widget.onTap(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.tabDragNotifier,
        widget.depthTensionNotifier,
      ]),
      builder: (context, child) {
        final double dragValue = widget.tabDragNotifier.value;
        final double tension = widget.depthTensionNotifier.value;

        int targetIndex = widget.selectedIndex;
        if (dragValue < 0 && targetIndex < 3) targetIndex++;
        if (dragValue > 0 && targetIndex > 0) targetIndex--;

        final Color startColor = _getAmbientGlow(widget.selectedIndex);
        final Color endColor = _getAmbientGlow(targetIndex);
        final Color ambientColor =
            Color.lerp(startColor, endColor, dragValue.abs()) ?? startColor;

        return AnimatedBuilder(
          animation: _morphController,
          builder: (context, child) {
            double stretch = 1.0 + (_stretchAnimation.value * 0.08);
            double squish = 1.0 - (_stretchAnimation.value * 0.04);
            double translation =
                _morphDirection * (_stretchAnimation.value * 15);

            if (tension > 0) {
              stretch += tension * 0.06;
              squish -= tension * 0.03;
              translation += (dragValue > 0 ? -1 : 1) * (dragValue.abs() * 12);
            }

            return Transform(
              transform:
                  Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..translate(translation, 0.0)
                    ..scale(stretch, squish),
              alignment: Alignment.center,
              child: child,
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 76,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(38),
              boxShadow: [
                BoxShadow(
                  color: ambientColor.withValues(alpha: isDark ? 0.15 : 0.25),
                  blurRadius: 40,
                  spreadRadius: 6,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(36.5),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? Colors.black.withValues(alpha: 0.65)
                            : Colors.white.withValues(alpha: 0.8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _FluidTab(
                        icon: Icons.home_rounded,
                        label: "Home",
                        expansionRatio:
                            widget.selectedIndex == 0
                                ? (1.0 - dragValue.abs())
                                : (targetIndex == 0 ? dragValue.abs() : 0.0),
                        activeColor: AppColors.primaryGreen,
                        onTap: () => _handleTabTap(0),
                      ),
                      _FluidTab(
                        icon: Icons.medical_services_rounded,
                        label: "Doctors",
                        expansionRatio:
                            widget.selectedIndex == 1
                                ? (1.0 - dragValue.abs())
                                : (targetIndex == 1 ? dragValue.abs() : 0.0),
                        activeColor: const Color(0xFF007BFF),
                        onTap: () => _handleTabTap(1),
                      ),
                      _FluidTab(
                        icon: Icons.assignment_rounded,
                        label: "Schedule",
                        expansionRatio:
                            widget.selectedIndex == 2
                                ? (1.0 - dragValue.abs())
                                : (targetIndex == 2 ? dragValue.abs() : 0.0),
                        activeColor: const Color(0xFFFF9F00),
                        onTap: () => _handleTabTap(2),
                      ),
                      _FluidTab(
                        icon: Icons.account_circle_rounded,
                        label: "Profile",
                        expansionRatio:
                            widget.selectedIndex == 3
                                ? (1.0 - dragValue.abs())
                                : (targetIndex == 3 ? dragValue.abs() : 0.0),
                        activeColor: const Color(0xFF8E44AD),
                        onTap: () => _handleTabTap(3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FluidTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final double expansionRatio;
  final Color activeColor;
  final VoidCallback onTap;

  const _FluidTab({
    required this.icon,
    required this.label,
    required this.expansionRatio,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBgColor = activeColor.withValues(alpha: isDark ? 0.2 : 0.15);
    final inactiveIconColor = isDark ? Colors.white54 : Colors.black45;

    final Color bgColor =
        Color.lerp(Colors.transparent, activeBgColor, expansionRatio)!;
    final Color iconColor =
        Color.lerp(inactiveIconColor, activeColor, expansionRatio)!;
    final double hPadding = 12.0 + (8.0 * expansionRatio);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 26),
            if (expansionRatio > 0.05)
              ClipRect(
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: expansionRatio,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: activeColor.withValues(alpha: expansionRatio),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
