import 'dart:async';

import 'dart:convert';

import 'dart:ui';

import 'package:flutter/material.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../favorites_notifier.dart';
import '../../../../presentation/widgets/primary_button.dart';

import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../../doctors/data/doctor_repository.dart';
import '../../../appointments/data/appointment_repository.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import 'package:url_launcher/url_launcher.dart';

import 'package:geolocator/geolocator.dart';

import '../widgets/doctor_details_header.dart';
import '../widgets/doctor_stats_row.dart';
import '../widgets/doctor_appointment_card.dart';
import '../widgets/doctor_timing_list.dart';

class DoctorDetailsScreen extends StatefulWidget {
  final String doctorId;

  const DoctorDetailsScreen({super.key, required this.doctorId});

  @override
  State<DoctorDetailsScreen> createState() => _DoctorDetailsScreenState();
}

class _DoctorDetailsScreenState extends State<DoctorDetailsScreen>
    with TickerProviderStateMixin {
  // --- DESIGN COLORS (aliased from AppColors) ---

  static const Color primaryGreen = AppColors.primaryGreen;

  static const Color bgColor = AppColors.bgColor;

  static const Color textDark = AppColors.textDark;

  // --- DATA STATE ---

  final _doctorRepo = DoctorRepository();
  final _appointmentRepo = AppointmentRepository();
  final _favNotifier = FavoritesNotifier.instance;

  bool _isLoading = true;
  String? _errorMessage;

  Map<String, dynamic>? _doctor;

  List<Map<String, dynamic>> _clinics = [];

  List<Map<String, dynamic>> _schedules = [];

  // Tracks the user's selected clinic/location
  Map<String, dynamic>? _selectedClinic;

  // Booking Data

  DateTime _selectedDate = DateTime.now();

  List<String> _bookedSlots = [];

  String? _selectedTimeSlot;

  // --- UI STATE ---

  final ScrollController _scrollController = ScrollController();

  final GlobalKey _locationSectionKey = GlobalKey();

  // --- ANIMATION CONTROLLERS ---

  late AnimationController _menuController;

  late Animation<double> _expandAnimation;

  late Animation<double> _rotateAnimation;

  bool _isMenuOpen = false;

  Timer? _autoCloseTimer;

  late AnimationController _locatorMenuController;

  late Animation<double> _locatorExpandAnimation;

  late Animation<double> _locatorRotateAnimation;

  bool _isLocatorMenuOpen = false;

  Timer? _locatorAutoCloseTimer;

  // --- NAVIGATION STATE ---

  LatLng? _userLocation;

  List<LatLng> _routePoints = [];

  bool _isRouteLoading = false;

  bool _isNavigating = false;

  bool _isUserPanning = false;

  final MapController _mapController = MapController();

  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _favNotifier.addListener(_onFavoritesChanged);

    _fetchInitialData();

    // 1. Directions Menu Animation

    _menuController = AnimationController(
      vsync: this,

      duration: const Duration(milliseconds: 300),
    );

    _expandAnimation = CurvedAnimation(
      parent: _menuController,

      curve: Curves.easeOutBack,
    );

    _rotateAnimation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _menuController, curve: Curves.easeInOut),
    );

    // 2. Locator Menu Animation

    _locatorMenuController = AnimationController(
      vsync: this,

      duration: const Duration(milliseconds: 300),
    );

    _locatorExpandAnimation = CurvedAnimation(
      parent: _locatorMenuController,

      curve: Curves.easeOutBack,
    );

    _locatorRotateAnimation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _locatorMenuController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _favNotifier.removeListener(_onFavoritesChanged);
    _menuController.dispose();

    _locatorMenuController.dispose();

    _scrollController.dispose();

    _autoCloseTimer?.cancel();

    _locatorAutoCloseTimer?.cancel();

    _positionStream?.cancel();

    super.dispose();
  }

  void _onFavoritesChanged() {
    if (mounted) setState(() {});
  }

  // --- HELPERS ---

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _scrollToLocationSection() {
    final context = _locationSectionKey.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
      alignment: 0.05,
    );
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

    _menuController.forward();

    _autoCloseTimer?.cancel();

    _autoCloseTimer = Timer(const Duration(seconds: 5), _closeMenu);
  }

  void _closeMenu() {
    if (!mounted) return;

    _autoCloseTimer?.cancel();

    _menuController.reverse().then((_) {
      if (mounted) setState(() => _isMenuOpen = false);
    });
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

    _locatorMenuController.forward();

    _locatorAutoCloseTimer?.cancel();

    _locatorAutoCloseTimer = Timer(
      const Duration(seconds: 5),

      _closeLocatorMenu,
    );
  }

  void _closeLocatorMenu() {
    if (!mounted) return;

    _locatorAutoCloseTimer?.cancel();

    _locatorMenuController.reverse().then((_) {
      if (mounted) setState(() => _isLocatorMenuOpen = false);
    });
  }

  // --- DATA FETCHING ---

  Future<void> _fetchInitialData() async {
    final userId = _doctorRepo.currentUserId;

    try {
      // 1. Fetch Doctor Details FIRST (Vital)
      final doctor = await _doctorRepo.fetchDoctorDetails(widget.doctorId);

      if (mounted) {
        setState(() {
          _doctor = doctor.toJson();
          _isLoading = false; // Show UI as soon as doctor is loaded
        });
      }

      // 2. Fetch Secondary Data (Clinics, Schedules, Favorites)
      // We do this concurrently but separately so UI is already visible
      final results = await Future.wait<dynamic>([
        _doctorRepo.fetchClinics(widget.doctorId),
        _doctorRepo.fetchSchedules(widget.doctorId),
        if (userId != null) _doctorRepo.isFavorite(widget.doctorId, userId),
      ]);

      final clinicsResponse = results[0] as List<Map<String, dynamic>>;
      final schedulesResponse = results[1] as List<Map<String, dynamic>>;
      final isFav = userId != null ? results[2] as bool : false;

      if (mounted) {
        setState(() {
          _clinics = clinicsResponse;
          _schedules = schedulesResponse;

          if (_clinics.isNotEmpty) {
            _selectedClinic = _clinics.first;
          }

          // Sync notifier
          final docIdInt = int.tryParse(widget.doctorId);
          if (docIdInt != null && isFav != _favNotifier.isFavorite(docIdInt)) {
            _favNotifier.syncSingle(docIdInt, isFav);
          }
        });

        _fetchBookedSlots();
      }
    } catch (e) {
      debugPrint("Error fetching data: $e");
      // Only set loading to false if we haven't successfully loaded the doctor yet
      if (mounted && _doctor == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _fetchBookedSlots() async {
    if (_selectedClinic == null) return;

    try {
      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);

      final slots = await _appointmentRepo.fetchBookedSlots(
        doctorId: widget.doctorId,
        clinicId: _selectedClinic!['id'].toString(),
        date: formattedDate,
      );

      if (mounted) {
        setState(() {
          _bookedSlots = slots;
        });
      }
    } catch (e) {
      if (mounted) setState(() {});
    }
  }

  // --- LOCATION & MAP LOGIC ---

  Future<bool> _ensureLocationReady() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      if (!mounted) return false;

      final result = await context.push<bool>('/location_permission');

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

      _mapController.move(_userLocation!, 17.0);
    }
  }

  void _centerOnClinic() {
    _closeLocatorMenu();

    if (_selectedClinic != null) {
      setState(() => _isUserPanning = true);

      final lat = _selectedClinic!['latitude'] as double? ?? 0.0;

      final lng = _selectedClinic!['longitude'] as double? ?? 0.0;

      _mapController.move(LatLng(lat, lng), 16.0);
    }
  }

  Future<void> _launchExternalMaps() async {
    _closeMenu();

    if (_selectedClinic == null) return;

    final lat = _selectedClinic!['latitude'] as double? ?? 0.0;

    final lng = _selectedClinic!['longitude'] as double? ?? 0.0;

    final Uri googleMapsUrl = Uri.parse("google.navigation:q=$lat,$lng&mode=d");

    final Uri appleMapsUrl = Uri.parse(
      "https://maps.apple.com/?daddr=$lat,$lng",
    );

    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl);
      } else if (await canLaunchUrl(appleMapsUrl)) {
        await launchUrl(appleMapsUrl);
      } else {
        final Uri webUrl = Uri.parse(
          "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng",
        );

        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, "Could not launch maps");
      }
    }
  }

  Future<void> _launchInAppDirection() async {
    _closeMenu();

    if (_selectedClinic == null) return;

    final isReady = await _ensureLocationReady();

    if (!isReady) return;

    setState(() {
      _isRouteLoading = true;

      _isNavigating = true;

      _isUserPanning = false;
    });

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final clinicLat = _selectedClinic!['latitude'] as double;

      final clinicLng = _selectedClinic!['longitude'] as double;

      await _fetchRoute(
        start: LatLng(position.latitude, position.longitude),

        end: LatLng(clinicLat, clinicLng),
      );

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

        if (!_isUserPanning) _mapController.move(newLoc, 17.0);
      });
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, "Could not start navigation");
      }

      setState(() {
        _isRouteLoading = false;

        _isNavigating = false;
      });
    }
  }

  Future<void> _fetchRoute({required LatLng start, required LatLng end}) async {
    try {
      final url = Uri.parse(
        'http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final coordinates =
            data['routes'][0]['geometry']['coordinates'] as List;

        final List<LatLng> points =
            coordinates.map((coord) {
              return LatLng(coord[1].toDouble(), coord[0].toDouble());
            }).toList();

        if (mounted) {
          setState(() {
            _routePoints = points;

            _userLocation = start;

            _isRouteLoading = false;
          });

          _fitMapBounds();
        }
      }
    } catch (e) {
      debugPrint("Route error: $e");
    }
  }

  void _fitMapBounds() {
    if (_routePoints.isEmpty) return;

    final bounds = LatLngBounds.fromPoints(_routePoints);

    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
    );
  }

  // --- BOOKING LOGIC ---

  Future<void> _handleBooking() async {
    // Validation for clinic is still required, but time slot is now optional at this stage.
    if (_selectedClinic == null) {
      CustomSnackbar.showError(context, "No clinic selected");
      return;
    }

    // IMPORTANT: We pass the selected clinic, doctor, and date to the next screen.
    // The next screen will use this clinic ID to show relevant slots.
    context.push(
      '/appointment_booking',
      extra: {
        'doctor': _doctor,
        'clinic': _selectedClinic, // <--- This saves the user's choice
        'initialDate': _selectedDate,
        'timeSlot': _selectedTimeSlot, // <--- Pass the selected time slot
      },
    );
  }

  Future<void> _toggleFavorite() async {
    final docIdInt = int.tryParse(widget.doctorId);
    if (docIdInt == null) return;
    await _favNotifier.toggle(docIdInt);
  }

  // _showSnack removed in favor of CustomSnackbar

  // --- CALENDAR UI LOGIC ---

  Future<void> _openDatePicker() async {
    final now = DateTime.now();

    final pickedDate = await showDialog<DateTime>(
      context: context,

      barrierColor: Colors.black.withValues(alpha: 0.3),

      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),

          child: Dialog(
            backgroundColor: Colors.white,

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),

            child: Padding(
              padding: const EdgeInsets.all(16.0),

              child: Column(
                mainAxisSize: MainAxisSize.min,

                children: [
                  Text("Select Date", style: AppTextStyles.h3),

                  const SizedBox(height: 10),

                  SizedBox(
                    height: 350,

                    width: 300,

                    child: CalendarDatePicker(
                      initialDate: _selectedDate,

                      firstDate: now,

                      lastDate: now.add(const Duration(days: 365)),

                      onDateChanged: (date) {
                        Navigator.of(context).pop(date);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (pickedDate != null && !_isSameDay(pickedDate, _selectedDate)) {
      setState(() {
        _selectedDate = pickedDate;
      });

      _fetchBookedSlots();
    }
  }

  // --- SLOT GENERATOR (Visual Representation Only) ---

  List<String> _getSlotsForSelectedDate() {
    if (_schedules.isEmpty || _selectedClinic == null) return [];

    final dayName = DateFormat('EEEE').format(_selectedDate);

    final now = DateTime.now();

    final isToday = _isSameDay(_selectedDate, now);

    // Filter schedules for the *selected clinic*

    final daySchedules =
        _schedules
            .where(
              (s) =>
                  s['clinic_id'] == _selectedClinic!['id'] &&
                  s['day_of_week'].toString().toLowerCase() ==
                      dayName.toLowerCase(),
            )
            .toList();

    List<String> allSlots = [];

    for (var scheduleEntry in daySchedules) {
      try {
        final startStr = scheduleEntry['start_time'].toString();

        final endStr = scheduleEntry['end_time'].toString();

        final duration = scheduleEntry['slot_duration_minutes'] as int? ?? 30;

        TimeOfDay startTime = _parseTime(startStr);

        TimeOfDay endTime = _parseTime(endStr);

        int startMinutes = startTime.hour * 60 + startTime.minute;

        int endMinutes = endTime.hour * 60 + endTime.minute;

        while (startMinutes + duration <= endMinutes) {
          bool isPast = false;

          if (isToday) {
            final slotHour = startMinutes ~/ 60;

            final slotMinute = startMinutes % 60;

            final slotTime = DateTime(
              now.year,

              now.month,

              now.day,

              slotHour,

              slotMinute,
            );

            if (slotTime.isBefore(now)) isPast = true;
          }

          if (!isPast) {
            final sTime = _minutesToTime(startMinutes);

            final eTime = _minutesToTime(startMinutes + duration);

            allSlots.add("$sTime - $eTime");
          }

          startMinutes += duration;
        }
      } catch (e) {
        debugPrint("Error parsing schedule row: $e");
      }
    }

    allSlots.sort((a, b) => a.compareTo(b));

    return allSlots.toSet().toList();
  }

  TimeOfDay _parseTime(String timeStr) {
    final parts = timeStr.split(':');

    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _minutesToTime(int totalMinutes) {
    final h = (totalMinutes ~/ 60).toString().padLeft(2, '0');

    final m = (totalMinutes % 60).toString().padLeft(2, '0');

    return "$h:$m";
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: bgColor,

        body: Center(child: CircularProgressIndicator(color: primaryGreen)),
      );
    }

    if (_doctor == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  "Doctor Not Found",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h2,
                ),
                const SizedBox(height: 8),
                const Text(
                  "We couldn't find the doctor you're looking for.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.pop(),
                  child: const Text("Go Back"),
                ),
                const SizedBox(height: 16),
                Text(
                  "ID: ${widget.doctorId}",
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,

      appBar: _buildAppBar(),

      body: Container(
        decoration: const BoxDecoration(gradient: AppStyles.pageGradient),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,

                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    DoctorDetailsHeader(
                      doctor: _doctor!,
                      onFavoriteTap: _toggleFavorite,
                      isFavorite: _favNotifier.isFavorite(
                        int.tryParse(widget.doctorId) ?? 0,
                      ),
                      visitPrice:
                          (_clinics.isNotEmpty && _selectedClinic != null)
                              ? "${_selectedClinic!['visit_price']}"
                              : "${_doctor!['hourly_rate'] ?? '0'}",
                      onBookNowTap: _handleBooking,
                    ),

                    const SizedBox(height: 14),

                    DoctorStatsRow(
                      patients: _doctor!['patients_served']?.toString() ?? '100',
                      experience:
                          _doctor!['experience_years']?.toString() ?? '5',
                      rating: _doctor!['rating']?.toString() ?? '0.0',
                    ),

                    const SizedBox(height: 14),

                    Builder(
                      builder: (context) {
                        final now = DateTime.now();
                        final today = now;
                        final tomorrow = now.add(const Duration(days: 1));
                        DateTime thirdDate = now.add(const Duration(days: 2));
                        bool isCustomDate =
                            !_isSameDay(_selectedDate, today) &&
                            !_isSameDay(_selectedDate, tomorrow);
                        if (isCustomDate) {
                          thirdDate = _selectedDate;
                        }
                        final datesToShow = [today, tomorrow, thirdDate];

                        return DoctorAppointmentCard(
                          clinics: _clinics,
                          selectedClinic: _selectedClinic,
                          selectedDate: _selectedDate,
                          datesToShow: datesToShow,
                          timeSlots: _getSlotsForSelectedDate(),
                          bookedSlots: _bookedSlots.toList(),
                          selectedTimeSlot:
                              _selectedTimeSlot, // Pass selected slot
                          onClinicChanged: (clinic) {
                            if (clinic != null) {
                              setState(() {
                                _selectedClinic = clinic;
                                _selectedTimeSlot =
                                    null; // Reset slot on clinic change
                              });
                              _fetchBookedSlots();
                            }
                          },
                          onDateSelected: (date) {
                            setState(() {
                              _selectedDate = date;
                              _selectedTimeSlot =
                                  null; // Reset slot on date change
                            });
                            _fetchBookedSlots();
                          },
                          onCustomDateTap: _openDatePicker,
                          onTimeSlotSelected: (slot) {
                            setState(() {
                              _selectedTimeSlot = slot;
                            });
                          },
                          onMoreClinicTap: _scrollToLocationSection,
                        );
                      },
                    ),

                    const SizedBox(height: 18),

                    Text("Timing", style: AppTextStyles.h3),

                    const SizedBox(height: 10),

                    DoctorTimingList(schedules: _schedules),

                    const SizedBox(height: 18),

                    Text(
                      "Location",

                      key: _locationSectionKey,

                      style: AppTextStyles.h3,
                    ),

                    const SizedBox(height: 10),

                    _buildLocationSelector(),

                    const SizedBox(height: 12),

                    RepaintBoundary(child: _buildMap()),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // --- BOTTOM BUTTON ---
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: PrimaryButton(
                    label: "Book Now",
                    onTap: _handleBooking,
                    height: 48,
                    borderRadius: 8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,

      elevation: 0,

      scrolledUnderElevation: 0,

      centerTitle: true,

      leadingWidth: 64,

      titleSpacing: 0,

      leading: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 0, 6),
        child: InkWell(
          onTap: () => context.pop(),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderColor),
              boxShadow: AppStyles.cardShadow,
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: AppColors.textDark,
            ),
          ),
        ),
      ),

      title: Text(
        "Doctor Details",
        style: AppTextStyles.h3.copyWith(fontSize: 20),
      ),
      actions: [const SizedBox(width: 64)],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(8),
        child: Container(),
      ),
    );
  }

  Widget _buildLocationSelector() {
    if (_clinics.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,

      child: Row(
        children:
            _clinics.map((clinic) {
              final isSelected = _selectedClinic == clinic;

              final shortName = clinic['name'].toString().split(' ').first;

              return GestureDetector(
                onTap: () {
                  setState(() => _selectedClinic = clinic);

                  _fetchBookedSlots();

                  final lat = clinic['latitude'] as double? ?? 0.0;

                  final lng = clinic['longitude'] as double? ?? 0.0;

                  _mapController.move(LatLng(lat, lng), 15.0);

                  if (_isNavigating && _userLocation != null) {
                    _fetchRoute(start: _userLocation!, end: LatLng(lat, lng));
                  }
                },

                child: Container(
                  margin: const EdgeInsets.only(right: 12),

                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),

                  width: 136,

                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F6F8),

                    borderRadius: BorderRadius.circular(10),

                    border: Border.all(
                      color: isSelected ? primaryGreen : Colors.transparent,

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

                          color: isSelected ? textDark : Colors.grey[600],
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
    if (_selectedClinic == null) {
      return Container(
        height: 150,

        width: double.infinity,

        decoration: BoxDecoration(
          color: Colors.grey[200],

          borderRadius: BorderRadius.circular(12),
        ),

        child: const Center(
          child: Icon(Icons.map, color: Colors.grey, size: 40),
        ),
      );
    }

    final lat = _selectedClinic!['latitude'] as double? ?? 23.8103;

    final lng = _selectedClinic!['longitude'] as double? ?? 90.4125;

    return Stack(
      children: [
        Container(
          height: 150,

          width: double.infinity,

          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),

            border: Border.all(color: Colors.grey.shade200),
          ),

          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),

            child: FlutterMap(
              mapController: _mapController,

              options: MapOptions(
                initialCenter: LatLng(lat, lng),

                initialZoom: 15.0,

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

                  userAgentPackageName: 'com.example.daktarpi',
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

                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),

                              blurRadius: 6,

                              offset: const Offset(0, 3),
                            ),
                          ],

                          gradient: const RadialGradient(
                            center: Alignment.center,

                            radius: 0.8,

                            colors: [primaryGreen, Colors.white],
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

                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),

                                blurRadius: 5,
                              ),
                            ],
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

        if (_isRouteLoading)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.1),

                borderRadius: BorderRadius.circular(12),
              ),

              child: const Center(child: CircularProgressIndicator()),
            ),
          ),

        // --- FLOATING ACTION BUTTONS ---
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
                  SizeTransition(
                    sizeFactor: _locatorExpandAnimation,

                    axis: Axis.horizontal,

                    axisAlignment: 1.0,

                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),

                      child: FloatingActionButton.small(
                        heroTag: "btn_center_clinic",

                        backgroundColor: Colors.white,

                        onPressed: _centerOnClinic,

                        child: const Icon(
                          Icons.medical_services_outlined,

                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ),

                  if (_isNavigating)
                    SizeTransition(
                      sizeFactor: _locatorExpandAnimation,

                      axis: Axis.horizontal,

                      axisAlignment: 1.0,

                      child: Padding(
                        padding: const EdgeInsets.only(right: 8.0),

                        child: FloatingActionButton.small(
                          heroTag: "btn_center_user",

                          backgroundColor: Colors.white,

                          onPressed: _centerOnUser,

                          child: const Icon(
                            Icons.accessibility_new_rounded,

                            color: Colors.blueAccent,
                          ),
                        ),
                      ),
                    ),

                  FloatingActionButton.small(
                    heroTag: "btn_locator_toggle",

                    backgroundColor: Colors.white,

                    onPressed: _toggleLocatorMenu,

                    child: RotationTransition(
                      turns: _locatorRotateAnimation,

                      child: Icon(
                        _isLocatorMenuOpen ? Icons.close : Icons.gps_fixed,

                        color: primaryGreen,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Row(
                mainAxisSize: MainAxisSize.min,

                children: [
                  SizeTransition(
                    sizeFactor: _expandAnimation,

                    axis: Axis.horizontal,

                    axisAlignment: 1.0,

                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),

                      child: FloatingActionButton.small(
                        heroTag: "btn_external_map",

                        backgroundColor: Colors.white,

                        onPressed: _launchExternalMaps,

                        child: const Icon(Icons.public, color: Colors.blue),
                      ),
                    ),
                  ),

                  SizeTransition(
                    sizeFactor: _expandAnimation,

                    axis: Axis.horizontal,

                    axisAlignment: 1.0,

                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),

                      child: FloatingActionButton.small(
                        heroTag: "btn_inapp_map",

                        backgroundColor: Colors.white,

                        onPressed: _launchInAppDirection,

                        child: const Icon(
                          Icons.turn_sharp_right,

                          color: primaryGreen,
                        ),
                      ),
                    ),
                  ),

                  FloatingActionButton.small(
                    heroTag: "btn_main_toggle",

                    backgroundColor: primaryGreen,

                    onPressed: _toggleDirectionMenu,

                    child: RotationTransition(
                      turns: _rotateAnimation,

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
}
