import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/utils/navigation_helper.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';
import '../../data/route_repository.dart';

class ClinicLocationMapSection extends StatefulWidget {
  final List<dynamic> clinics;
  final Map<String, dynamic>? selectedClinic;
  final ValueChanged<Map<String, dynamic>> onClinicSelected;
  final VoidCallback scrollToTop;

  const ClinicLocationMapSection({
    super.key,
    required this.clinics,
    required this.selectedClinic,
    required this.onClinicSelected,
    required this.scrollToTop,
  });

  @override
  State<ClinicLocationMapSection> createState() =>
      _ClinicLocationMapSectionState();
}

class _ClinicLocationMapSectionState extends State<ClinicLocationMapSection> {
  final RouteRepository _routeRepo = RouteRepository();

  // --- MAP & NAVIGATION STATE ---
  final MapController _mapController = MapController();
  bool _isMapReady = false;
  List<LatLng> _routePoints = [];
  double? _distanceToClinic;
  bool _isRouteLoading = false;
  LatLng? _userLocation;
  StreamSubscription<Position>? _positionStream;

  // New states for real-time navigation
  bool _isNavigating = false;

  // Determines if user moved the map manually so we stop auto-centering
  bool _isUserPanning = false;

  Map<int, String> instructions = {};

  bool _isMenuOpen = false;
  Timer? _autoCloseTimer;
  bool _isLocatorMenuOpen = false;
  Timer? _locatorAutoCloseTimer;
  
  bool _isDistanceBarExpanded = false;
  Timer? _distanceAutoCloseTimer; 

  @override
  void dispose() {
    _positionStream?.cancel();
    _autoCloseTimer?.cancel();
    _locatorAutoCloseTimer?.cancel();
    _distanceAutoCloseTimer?.cancel(); 
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ClinicLocationMapSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedClinic != oldWidget.selectedClinic &&
        widget.selectedClinic != null) {
      final clinicPoint = _selectedClinicPoint();
      if (clinicPoint == null) return;

      _moveMapSafely(clinicPoint, 15.0);
      if (_isNavigating && _userLocation != null) {
        setState(() => _isUserPanning = true);
        _fetchRoute(start: _userLocation!, end: clinicPoint);
      }
    }
  }

  // --- ANIMATION LOGIC ---

  void _toggleDirectionMenu() {
    if (_isMenuOpen) {
      _closeMenu();
    } else {
      _openMenu();
      if (_isLocatorMenuOpen) _closeLocatorMenu();
    }
  }

  void _openMenu() {
    setState(() => _isMenuOpen = true);
    _autoCloseTimer?.cancel();
    _autoCloseTimer = Timer(const Duration(seconds: 5), _closeMenu);
  }

  void _closeMenu() {
    if (!mounted) return;
    _autoCloseTimer?.cancel();
    setState(() => _isMenuOpen = false);
  }

  void _toggleLocatorMenu() {
    if (_isLocatorMenuOpen) {
      _closeLocatorMenu();
    } else {
      _openLocatorMenu();
      if (_isMenuOpen) _closeMenu();
    }
  }

  void _openLocatorMenu() {
    setState(() => _isLocatorMenuOpen = true);
    _locatorAutoCloseTimer?.cancel();
    _locatorAutoCloseTimer = Timer(const Duration(seconds: 5), _closeLocatorMenu);
  }

  void _closeLocatorMenu() {
    if (!mounted) return;
    _locatorAutoCloseTimer?.cancel();
    setState(() => _isLocatorMenuOpen = false);
  }

  void _startDistanceAutoCloseTimer() {
    _distanceAutoCloseTimer?.cancel();
    _distanceAutoCloseTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _isDistanceBarExpanded = false;
        });
      }
    });
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  LatLng? _selectedClinicPoint() {
    final clinic = widget.selectedClinic;
    if (clinic == null) return null;

    final lat = _toDouble(clinic['latitude']);
    final lng = _toDouble(clinic['longitude']);
    if (lat == null || lng == null) return null;

    return LatLng(lat, lng);
  }

  void _runMapAction(VoidCallback action) {
    if (!mounted || !_isMapReady) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isMapReady) return;
      try {
        action();
      } catch (e) {
        debugPrint('Skipping map action before layout is stable: $e');
      }
    });
  }

  void _moveMapSafely(LatLng point, double zoom) {
    _runMapAction(() => _mapController.move(point, zoom));
  }

  // --- LOCATION & MAP LOGIC ---

  Future<bool> _ensureLocationReady() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return false;
      final result = await context.push<bool>(AppRoutes.locationPermission);
      if (result != true) {
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) return false;
      }
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          CustomSnackbar.showError(context, "Location permission denied");
        }
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        CustomSnackbar.showError(
          context,
          "Location permissions are permanently denied",
        );
      }
      return false;
    }
    return true;
  }

  Future<void> _centerOnUser() async {
    _closeLocatorMenu();
    final isReady = await _ensureLocationReady();
    if (!isReady) return;

    if (_userLocation == null) {
      try {
        Position position = await Geolocator.getCurrentPosition();
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
        });
      } catch (e) {
        if (mounted) {
          CustomSnackbar.showError(context, "Could not fetch location");
        }
        return;
      }
    }
    if (_userLocation != null) {
      setState(() => _isUserPanning = false);
      _moveMapSafely(_userLocation!, 16.0);
    }
  }

  void _updateDistance() {
    final clinicPoint = _selectedClinicPoint();
    if (_userLocation == null || clinicPoint == null) return;

    double distance = 0.0;
    if (_isNavigating && _routePoints.isNotEmpty) {
      distance += Geolocator.distanceBetween(
        _userLocation!.latitude,
        _userLocation!.longitude,
        _routePoints.first.latitude,
        _routePoints.first.longitude,
      );
      for (int i = 0; i < _routePoints.length - 1; i++) {
        distance += Geolocator.distanceBetween(
          _routePoints[i].latitude,
          _routePoints[i].longitude,
          _routePoints[i + 1].latitude,
          _routePoints[i + 1].longitude,
        );
      }
    } else {
      distance = Geolocator.distanceBetween(
        _userLocation!.latitude,
        _userLocation!.longitude,
        clinicPoint.latitude,
        clinicPoint.longitude,
      );
    }
    setState(() {
      _distanceToClinic = distance;
    });
  }

  void _centerOnClinic() {
    _closeLocatorMenu();
    final clinicPoint = _selectedClinicPoint();
    if (clinicPoint == null) {
      CustomSnackbar.showError(context, "Clinic location is unavailable");
      return;
    }

    setState(() => _isUserPanning = true);
    _moveMapSafely(clinicPoint, 16.0);
  }

  Future<void> _launchExternalMaps() async {
    _closeMenu();

    final clinicPoint = _selectedClinicPoint();
    if (clinicPoint == null) {
      CustomSnackbar.showError(context, "Clinic location is unavailable");
      return;
    }

    final title = widget.selectedClinic!['name'] as String? ?? 'Clinic';

    await NavigationHelper.showMapOptions(
      context: context,
      latitude: clinicPoint.latitude,
      longitude: clinicPoint.longitude,
      title: title,
    );
  }

  Future<void> _launchInAppDirection() async {
    _closeMenu();
    final clinicPoint = _selectedClinicPoint();
    if (clinicPoint == null) {
      CustomSnackbar.showError(context, "Clinic location is unavailable");
      return;
    }

    if (_isNavigating) {
      _cancelNavigation();
      return;
    }

    final isReady = await _ensureLocationReady();
    if (!isReady) return;

    setState(() {
      _isRouteLoading = true;
      _isNavigating = true;
      _isUserPanning = false;
      _isDistanceBarExpanded = false; // PRO FIX: Keep collapsed while loading!
    });
    
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) {
        widget.scrollToTop();
      }
    });

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await _fetchRoute(
        start: LatLng(position.latitude, position.longitude),
        end: clinicPoint,
        fitBounds: false,
      );

      if (!_isUserPanning) {
        _moveMapSafely(LatLng(position.latitude, position.longitude), 17.0);
      }

      _positionStream?.cancel();
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen((Position position) {
        if (!mounted) return;
        final newLoc = LatLng(position.latitude, position.longitude);
        setState(() => _userLocation = newLoc);
        _updateDistance();
        if (!_isUserPanning) _moveMapSafely(newLoc, 17.0);
      });
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, "Could not start navigation");
        setState(() {
          _isRouteLoading = false;
          _isNavigating = false;
        });
      }
    }
  }

  Future<void> _fetchRoute({
    required LatLng start,
    required LatLng end,
    bool fitBounds = true,
  }) async {
    try {
      final points = await _routeRepo.fetchDrivingRoute(start: start, end: end);
      if (mounted) {
        setState(() {
          _routePoints = points;
          _userLocation = start;
          _isRouteLoading = false;
          _isDistanceBarExpanded = true; // PRO FIX: Expand ONLY when the route is ready!
        });
        _startDistanceAutoCloseTimer(); // PRO FIX: Start the auto-hide timer now!
        _updateDistance();
        if (fitBounds) {
          _fitMapBounds();
        }
      }
    } catch (error) {
      debugPrint("Route error: $error");
      if (mounted) {
        setState(() {
          _isRouteLoading = false;
          _isNavigating = false;
        });
        CustomSnackbar.showError(
          context,
          "Failed to load route data. Try again.",
        );
        _updateDistance();
        if (fitBounds) {
          _fitMapBounds();
        }
      }
    }
  }

  void _cancelNavigation() {
    _positionStream?.cancel();
    _positionStream = null;
    _distanceAutoCloseTimer?.cancel(); 

    widget.scrollToTop();

    setState(() {
      _isNavigating = false;
      _routePoints.clear();
      _isUserPanning = false;
      _isDistanceBarExpanded = false;
    });

    _updateDistance();

    final clinicPoint = _selectedClinicPoint();
    if (clinicPoint != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _moveMapSafely(clinicPoint, 15.0);
        }
      });
    }
  }

  void _fitMapBounds() {
    final clinicPoint = _selectedClinicPoint();
    if (_userLocation == null || clinicPoint == null) return;

    final bounds =
        _routePoints.isNotEmpty
            ? LatLngBounds.fromPoints(_routePoints)
            : LatLngBounds.fromPoints([_userLocation!, clinicPoint]);

    _runMapAction(
      () => _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
      ),
    );
  }

  Widget _buildLocationSelector() {
    if (widget.clinics.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children:
            widget.clinics.map((clinic) {
              final isSelected = widget.selectedClinic == clinic;
              final shortName = clinic['name'].toString().split(' ').first;

              return GestureDetector(
                onTap: () {
                  widget.onClinicSelected(clinic);
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  width: 136,
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkScaffold : const Color(0xFFF4F6F8),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppColors.primaryGreen : Colors.transparent,
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shortName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color:
                              isSelected
                                  ? context.colorTextDark
                                  : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        clinic['name'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF97A0AB),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildMap() {
    if (widget.selectedClinic == null) {
      return Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: Icon(Icons.map, color: Colors.grey, size: 40)),
      );
    }

    final clinicPoint = _selectedClinicPoint();
    final lat = clinicPoint?.latitude ?? 23.8103;
    final lng = clinicPoint?.longitude ?? 90.4125;

    return Stack(
      children: [
        // 1. THE MAP ITSELF
        AnimatedContainer(
          duration: AppMotion.defaultDuration,
          curve: Curves.easeInOut,
          height: _isNavigating ? 350 : 150,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? AppColors.darkBorder 
                  : Colors.grey.shade200,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(lat, lng),
                initialZoom: 15.0,
                onMapReady: () {
                  _isMapReady = true;
                },
                onPositionChanged: (pos, hasGesture) {
                  if (hasGesture && _isNavigating) {
                    setState(() => _isUserPanning = true);
                  }
                },
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.example.AeviaPulse',
                ),
                if (_routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        strokeWidth: 4.0,
                        color: Colors.blueAccent,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(lat, lng),
                      width: 36,
                      height: 36,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: AppStyles.cardShadow(context),
                          gradient: const RadialGradient(
                            center: Alignment.center,
                            radius: 0.8,
                            colors: [AppColors.primaryGreen, Colors.white],
                          ),
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                    if (_userLocation != null)
                      Marker(
                        point: _userLocation!,
                        width: 30,
                        height: 30,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blueAccent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: AppStyles.cardShadow(context),
                          ),
                          child: const Icon(
                            Icons.navigation,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // 2. LOADING OVERLAY
        if (_isRouteLoading)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: AppLoader()),
            ),
          ),

        // 3. TOP NAVIGATION BAR (Distance bar with Auto-Collapse)
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: AnimatedSwitcher(
            duration: AppMotion.defaultDuration,
            transitionBuilder:
                (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, -0.5),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
            child:
                _isNavigating || _isRouteLoading // PRO FIX: Keep the bar visible while loading!
                    ? Row(
                      key: const ValueKey('nav_bar_visible'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (_isNavigating && !_isRouteLoading) {
                              setState(
                                () =>
                                    _isDistanceBarExpanded =
                                        !_isDistanceBarExpanded,
                              );
                              if (_isDistanceBarExpanded) {
                                _startDistanceAutoCloseTimer();
                              } else {
                                _distanceAutoCloseTimer?.cancel();
                              }
                            }
                          },
                          child: AnimatedContainer(
                            duration: AppMotion.defaultDuration,
                            curve: Curves.easeInOut,
                            padding: EdgeInsets.symmetric(
                              horizontal: _isDistanceBarExpanded ? 20 : 16,
                              vertical: _isDistanceBarExpanded ? 16 : 8,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(
                                _isDistanceBarExpanded ? 16 : 20,
                              ),
                              boxShadow: AppStyles.cardShadow(context),
                            ),
                            child: AnimatedSize(
                              duration: AppMotion.defaultDuration,
                              curve: Curves.easeInOut,
                              alignment: Alignment.topCenter,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.route,
                                        color: AppColors.primaryGreen,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      AnimatedSwitcher(
                                        duration: AppMotion.fast,
                                        child:
                                            _isRouteLoading ||
                                                    _distanceToClinic == null
                                                ? const Row(
                                                  key: ValueKey('calculating'),
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    SizedBox(
                                                      width: 12,
                                                      height: 12,
                                                      child: AppLoader(
                                                            strokeWidth: 2,
                                                            color: AppColors.primaryGreen,
                                                          ),
                                                    ),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      "Calculating...",
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            AppColors
                                                                .primaryGreen,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                )
                                                : Row(
                                                  key: const ValueKey('distance'),
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      _distanceToClinic! > 1000
                                                          ? "${(_distanceToClinic! / 1000).toStringAsFixed(1)} km away"
                                                          : "${_distanceToClinic!.toStringAsFixed(0)} m away",
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            context
                                                                .colorTextDark,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Icon(
                                                      _isDistanceBarExpanded
                                                          ? Icons.expand_less
                                                          : Icons.expand_more,
                                                      color: Colors.grey,
                                                      size: 16,
                                                    ),
                                                  ],
                                                ),
                                      ),
                                    ],
                                  ),
                                  AnimatedSwitcher(
                                    duration: AppMotion.fast,
                                    transitionBuilder:
                                        (child, animation) => FadeTransition(
                                          opacity: animation,
                                          child: SizeTransition(
                                            sizeFactor: animation,
                                            child: child,
                                          ),
                                        ),
                                    child:
                                        (_isDistanceBarExpanded &&
                                                _isNavigating && 
                                                !_isRouteLoading)
                                            ? Column(
                                              key: const ValueKey('expanded_nav'),
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const SizedBox(height: 12),
                                                const Divider(
                                                  height: 1,
                                                  color: Colors.black12,
                                                ),
                                                const SizedBox(height: 12),
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const Text(
                                                      "Active Navigation",
                                                      style: TextStyle(
                                                        color:
                                                            AppColors
                                                                .primaryGreen,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 24),
                                                    InkWell(
                                                      onTap: _cancelNavigation,
                                                      child: Container(
                                                        padding: const EdgeInsets.all(
                                                          4,
                                                        ),
                                                        decoration:
                                                            BoxDecoration(
                                                              color: Colors.red
                                                                  .withValues(
                                                                    alpha: 0.1,
                                                                  ),
                                                              shape:
                                                                  BoxShape
                                                                      .circle,
                                                            ),
                                                        child: const Icon(
                                                          Icons.close,
                                                          color: Colors.red,
                                                          size: 18,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            )
                                            : const SizedBox.shrink(
                                              key: ValueKey('collapsed_nav'),
                                            ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                    : const SizedBox.shrink(key: ValueKey('nav_bar_hidden')),
          ),
        ),

        // 4. BOTTOM RIGHT ACTION BUTTONS
        Positioned(
          bottom: 12,
          right: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSize(
                    duration: AppMotion.defaultDuration,
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.centerRight,
                    child:
                        _isLocatorMenuOpen
                            ? Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: FloatingActionButton.small(
                                heroTag: null,
                                backgroundColor: Theme.of(context).colorScheme.surface,
                                onPressed: _centerOnClinic,
                                child: const Icon(
                                  Icons.medical_services_outlined,
                                  color: Colors.redAccent,
                                ),
                              ),
                            )
                            : const SizedBox.shrink(),
                  ),
                  if (_isNavigating) ...[
                    AnimatedSize(
                      duration: AppMotion.defaultDuration,
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.centerRight,
                      child:
                          _isLocatorMenuOpen
                              ? Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: FloatingActionButton.small(
                                  heroTag: null,
                                  backgroundColor: Theme.of(context).colorScheme.surface,
                                  onPressed: () {
                                    setState(() => _isUserPanning = true);
                                    _fitMapBounds();
                                  },
                                  child: const Icon(
                                    Icons.map_outlined,
                                    color: Colors.green,
                                  ),
                                ),
                              )
                              : const SizedBox.shrink(),
                    ),
                    AnimatedSize(
                      duration: AppMotion.defaultDuration,
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.centerRight,
                      child:
                          _isLocatorMenuOpen
                              ? Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: FloatingActionButton.small(
                                  heroTag: null,
                                  backgroundColor: Theme.of(context).colorScheme.surface,
                                  onPressed: _centerOnUser,
                                  child: const Icon(
                                    Icons.accessibility_new_rounded,
                                    color: Colors.blueAccent,
                                  ),
                                ),
                              )
                              : const SizedBox.shrink(),
                    ),
                  ],
                  FloatingActionButton.small(
                    heroTag: null,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    onPressed: _toggleLocatorMenu,
                    child: AnimatedRotation(
                      turns: _isLocatorMenuOpen ? 0.5 : 0.0,
                      duration: AppMotion.defaultDuration,
                      curve: Curves.easeInOut,
                      child: Icon(
                        _isLocatorMenuOpen ? Icons.close : Icons.gps_fixed,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSize(
                    duration: AppMotion.defaultDuration,
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.centerRight,
                    child:
                        _isMenuOpen
                            ? Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: FloatingActionButton.small(
                                heroTag: null,
                                backgroundColor: Theme.of(context).colorScheme.surface,
                                onPressed: _launchExternalMaps,
                                child: const Icon(Icons.public, color: Colors.blue),
                              ),
                            )
                            : const SizedBox.shrink(),
                  ),
                  AnimatedSize(
                    duration: AppMotion.defaultDuration,
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.centerRight,
                    child:
                        (_isMenuOpen && !_isNavigating)
                            ? Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: FloatingActionButton.small(
                                heroTag: null,
                                backgroundColor: Theme.of(context).colorScheme.surface,
                                onPressed: _launchInAppDirection,
                                child: const Icon(
                                  Icons.turn_sharp_right,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                            )
                            : const SizedBox.shrink(),
                  ),
                  FloatingActionButton.small(
                    heroTag: null,
                    backgroundColor: AppColors.primaryGreen,
                    onPressed: _toggleDirectionMenu,
                    child: AnimatedRotation(
                      turns: _isMenuOpen ? 0.5 : 0.0,
                      duration: AppMotion.defaultDuration,
                      curve: Curves.easeInOut,
                      child: Icon(
                        _isMenuOpen ? Icons.close : Icons.directions,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLocationSelector(),
        const SizedBox(height: 12),
        RepaintBoundary(child: _buildMap()),
      ],
    );
  }
}