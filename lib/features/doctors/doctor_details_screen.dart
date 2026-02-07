import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class DoctorDetailsScreen extends StatefulWidget {
  final String doctorId;

  const DoctorDetailsScreen({super.key, required this.doctorId});

  @override
  State<DoctorDetailsScreen> createState() => _DoctorDetailsScreenState();
}

class _DoctorDetailsScreenState extends State<DoctorDetailsScreen>
    with TickerProviderStateMixin {
  // --- DESIGN COLORS ---
  final Color primaryGreen = const Color(0xFF00C689);
  final Color cyanHeader = const Color(0xFFE0F7FA);
  final Color bgColor = const Color(0xFFFBFBFB);
  final Color textDark = const Color(0xFF1A1A1A);

  // --- DATA STATE ---
  bool _isLoading = true;
  Map<String, dynamic>? _doctor;
  List<Map<String, dynamic>> _clinics = [];
  List<Map<String, dynamic>> _schedules = [];
  Map<String, dynamic>? _selectedClinic;
  bool _isFavorite = false;

  // Booking Data
  List<String> _bookedSlots = [];
  bool _isLoadingSlots = false;

  // --- UI STATE ---
  int _selectedDateIndex = 0;
  int _selectedTimeSlotIndex = -1;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _locationSectionKey = GlobalKey();

  // --- ANIMATION STATE (Directions - Bottom) ---
  late AnimationController _menuController;
  late Animation<double> _expandAnimation;
  late Animation<double> _rotateAnimation;
  bool _isMenuOpen = false;
  Timer? _autoCloseTimer;

  // --- ANIMATION STATE (Locator - Top) ---
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
    _fetchInitialData();

    // 1. Bottom Menu Controller
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

    // 2. Locator Controller
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
    _menuController.dispose();
    _locatorMenuController.dispose();
    _scrollController.dispose();
    _autoCloseTimer?.cancel();
    _locatorAutoCloseTimer?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }

  // --- MENU LOGIC ---
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

  void _scrollToLocations() {
    final context = _locationSectionKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    }
  }

  // --- LOCATION PERMISSION HELPER (UPDATED) ---
  Future<bool> _ensureLocationReady() async {
    // 1. Check Service Status
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return false;

      // FIX: Use GoRouter path defined in app_router.dart
      final result = await context.push<bool>('/location_permission');

      // If user returned 'true' (enabled), proceed. Otherwise check again.
      if (result != true) {
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) return false;
      }
    }

    // 2. Check Permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnack("Location permission denied");
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _showSnack("Location permissions are permanently denied");
      return false;
    }
    return true;
  }

  // --- MAP CAMERA CONTROLS ---
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
        _showSnack("Could not fetch location");
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

  // --- 1. INITIAL DATA FETCH ---
  Future<void> _fetchInitialData() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;

    try {
      final results = await Future.wait<dynamic>([
        client
            .from('doctors')
            .select('*, specialties(name)')
            .eq('id', widget.doctorId)
            .single(),
        client
            .from('doctor_clinics')
            .select(
              'clinic_id, visit_price, avg_wait_time, clinics(id, name, address, latitude, longitude)',
            )
            .eq('doctor_id', widget.doctorId)
            .order('visit_price', ascending: true),
        client
            .from('doctor_schedules')
            .select('*')
            .eq('doctor_id', widget.doctorId),
      ]);

      final docResponse = results[0] as Map<String, dynamic>;
      final clinicsResponse = results[1] as List<dynamic>;
      final schedulesResponse = results[2] as List<dynamic>;

      bool isFav = false;
      if (userId != null) {
        final favRes =
            await client
                .from('favorite_doctors')
                .select()
                .eq('user_id', userId)
                .eq('doctor_id', widget.doctorId)
                .maybeSingle();
        if (favRes != null) isFav = true;
      }

      if (mounted) {
        setState(() {
          _doctor = docResponse;
          _isFavorite = isFav;
          _schedules = List<Map<String, dynamic>>.from(schedulesResponse);

          _clinics = List<Map<String, dynamic>>.from(
            clinicsResponse.map((e) {
              final clinicData = e['clinics'] as Map<String, dynamic>;
              return {
                ...clinicData,
                'junction_id': e['id'],
                'visit_price': e['visit_price'],
                'avg_wait_time': e['avg_wait_time'] ?? '20-30 mins',
              };
            }),
          );

          if (_clinics.isNotEmpty) {
            _selectedClinic = _clinics.first;
          }

          _isLoading = false;
        });
        _fetchBookedSlots();
      }
    } catch (e) {
      debugPrint("Error fetching initial data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 2. FETCH BOOKED SLOTS ---
  Future<void> _fetchBookedSlots() async {
    if (_selectedClinic == null) return;
    setState(() => _isLoadingSlots = true);
    try {
      final client = Supabase.instance.client;
      final date = _getNextDays()[_selectedDateIndex];
      final formattedDate = DateFormat('yyyy-MM-dd').format(date);

      final response = await client
          .from('appointments')
          .select('start_time, end_time')
          .eq('doctor_id', widget.doctorId)
          .eq('schedule_date', formattedDate)
          .neq('status', 'cancelled');

      if (mounted) {
        setState(() {
          _bookedSlots =
              List<Map<String, dynamic>>.from(response).map((record) {
                final start = record['start_time'].toString().substring(0, 5);
                final end = record['end_time'].toString().substring(0, 5);
                return "$start - $end";
              }).toList();

          if (_selectedTimeSlotIndex != -1) {
            final slots = _getSlotsForSelectedDate();
            if (_selectedTimeSlotIndex < slots.length) {
              if (_bookedSlots.contains(slots[_selectedTimeSlotIndex])) {
                _selectedTimeSlotIndex = -1;
              }
            }
          }
          _isLoadingSlots = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingSlots = false);
    }
  }

  // --- 3. BOOKING HANDLER ---
  Future<void> _handleBooking() async {
    if (_selectedClinic == null) {
      _showSnack("No clinic selected");
      return;
    }
    final slots = _getSlotsForSelectedDate();
    if (_selectedTimeSlotIndex == -1 ||
        _selectedTimeSlotIndex >= slots.length) {
      _showSnack("Please select a time slot");
      return;
    }
    final selectedSlot = slots[_selectedTimeSlotIndex];
    if (_bookedSlots.contains(selectedSlot)) {
      _showSnack("Sorry, this slot is already booked.");
      _fetchBookedSlots();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId == null) {
        _showSnack("Please login to book");
        setState(() => _isLoading = false);
        return;
      }

      final date = _getNextDays()[_selectedDateIndex];
      final formattedDate = DateFormat('yyyy-MM-dd').format(date);
      final times = selectedSlot.split(' - ');

      await client.from('appointments').insert({
        'user_id': userId,
        'doctor_id': widget.doctorId,
        'clinic_id': _selectedClinic!['id'],
        'schedule_date': formattedDate,
        'start_time': times[0],
        'end_time': times[1],
        'status': 'confirmed',
      });

      if (mounted) {
        _showSnack("Appointment Booked Successfully!", isSuccess: true);
        await _fetchBookedSlots();
        setState(() {
          _selectedTimeSlotIndex = -1;
          _isLoading = false;
        });
      }
    } catch (e) {
      _showSnack("Booking failed: ${e.toString().split('\n').first}");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isFavorite = !_isFavorite);

    try {
      if (!_isFavorite) {
        await client.from('favorite_doctors').delete().match({
          'user_id': userId,
          'doctor_id': widget.doctorId,
        });
      } else {
        await client.from('favorite_doctors').insert({
          'user_id': userId,
          'doctor_id': widget.doctorId,
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isFavorite = !_isFavorite);
    }
  }

  // --- 5. NAVIGATION LOGIC ---

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
      _showSnack("Could not launch maps");
    }
  }

  Future<void> _launchInAppDirection() async {
    _closeMenu();
    if (_selectedClinic == null) return;

    // Check Location Service via Router
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
        setState(() {
          _userLocation = newLoc;
        });

        if (!_isUserPanning) {
          _mapController.move(newLoc, 17.0);
        }
      });
    } catch (e) {
      debugPrint("Error starting navigation: $e");
      _showSnack("Could not start navigation");
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
      debugPrint("Route fetch error: $e");
    }
  }

  void _fitMapBounds() {
    if (_routePoints.isEmpty) return;
    final bounds = LatLngBounds.fromPoints(_routePoints);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
    );
  }

  List<DateTime> _getNextDays() {
    final now = DateTime.now();
    return List.generate(3, (index) => now.add(Duration(days: index)));
  }

  List<String> _getSlotsForSelectedDate() {
    if (_schedules.isEmpty || _selectedClinic == null) return [];

    final selectedDate = _getNextDays()[_selectedDateIndex];
    final dayName = DateFormat('EEEE').format(selectedDate);
    final isToday = _selectedDateIndex == 0;
    final now = DateTime.now();

    final scheduleEntry = _schedules.firstWhere(
      (s) =>
          s['clinic_id'] == _selectedClinic!['id'] &&
          s['day_of_week'].toString().toLowerCase() == dayName.toLowerCase(),
      orElse: () => {},
    );

    if (scheduleEntry.isEmpty) return [];

    try {
      final startStr = scheduleEntry['start_time'].toString();
      final endStr = scheduleEntry['end_time'].toString();
      final duration = scheduleEntry['slot_duration_minutes'] as int? ?? 30;

      TimeOfDay startTime = _parseTime(startStr);
      TimeOfDay endTime = _parseTime(endStr);

      int startMinutes = startTime.hour * 60 + startTime.minute;
      int endMinutes = endTime.hour * 60 + endTime.minute;

      List<String> slots = [];
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
          if (slotTime.isBefore(now)) {
            isPast = true;
          }
        }

        if (!isPast) {
          final sTime = _minutesToTime(startMinutes);
          final eTime = _minutesToTime(startMinutes + duration);
          slots.add("$sTime - $eTime");
        }
        startMinutes += duration;
      }
      return slots;
    } catch (e) {
      return [];
    }
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
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(child: CircularProgressIndicator(color: primaryGreen)),
      );
    }

    if (_doctor == null) {
      return const Scaffold(body: Center(child: Text("Doctor not found")));
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Positioned.fill(
            bottom: 80,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileCard(),
                  const SizedBox(height: 24),
                  _buildStatsRow(),
                  const SizedBox(height: 24),
                  _buildInClinicAppointmentCard(),
                  const SizedBox(height: 24),
                  const Text(
                    "Timing",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  _buildTimingList(),
                  const SizedBox(height: 24),
                  Text(
                    "Location",
                    key: _locationSectionKey,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildLocationSelector(),
                  const SizedBox(height: 16),
                  _buildMap(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              color: Colors.white,
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _handleBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Book Now",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: bgColor,
      elevation: 0,
      centerTitle: true,
      leading: Center(
        child: InkWell(
          onTap: () => context.pop(),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: Colors.black,
            ),
          ),
        ),
      ),
      title: const Text(
        "Doctor Details",
        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildProfileCard() {
    final specialty =
        _doctor!['specialties'] != null
            ? _doctor!['specialties']['name']
            : 'Specialist';
    final displayPrice =
        (_clinics.isNotEmpty && _selectedClinic != null)
            ? "৳ ${_selectedClinic!['visit_price']}"
            : "৳ ${_doctor!['hourly_rate'] ?? '0'}";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              _doctor!['profile_picture_url'] ?? 'https://i.pravatar.cc/300',
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder:
                  (_, __, ___) => Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[200],
                    child: const Icon(Icons.person),
                  ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _doctor!['full_name'],
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: _toggleFavorite,
                      child: Icon(
                        _isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: _isFavorite ? Colors.red : Colors.grey,
                        size: 24,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "Specialist $specialty",
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildStars(_doctor!['rating']?.toString() ?? '0'),
                    const Spacer(),
                    Text(
                      "$displayPrice/visit",
                      style: TextStyle(
                        color: primaryGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatItem(
            Icons.star,
            Colors.amber,
            "${_doctor!['rating']}",
            "Rating & Review",
          ),
        ),
        Container(width: 1, height: 40, color: Colors.grey[300]),
        Expanded(
          child: _buildStatItem(
            Icons.work,
            primaryGreen,
            "${_doctor!['experience_years']}",
            "Years of work",
          ),
        ),
        Container(width: 1, height: 40, color: Colors.grey[300]),
        Expanded(
          child: _buildStatItem(
            Icons.people,
            Colors.blue,
            "${_doctor!['patients_served']}",
            "No. of patients",
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(
    IconData icon,
    Color color,
    String value,
    String label,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: textDark,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          child: Text(
            label,
            style: TextStyle(color: Colors.grey[500], fontSize: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildInClinicAppointmentCard() {
    final bool hasData = _clinics.isNotEmpty && _selectedClinic != null;

    final clinicName =
        hasData ? _selectedClinic!['name'] : 'No Clinic Available';
    final clinicAddress = hasData ? _selectedClinic!['address'] : '';
    final price = hasData ? _selectedClinic!['visit_price'] : 0;
    final waitTime = hasData ? _selectedClinic!['avg_wait_time'] : 'N/A';

    final availableSlots = _getSlotsForSelectedDate();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cyanHeader,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "In-Clinic Appointment",
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                Text(
                  "৳ $price",
                  style: TextStyle(
                    color: primaryGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clinicName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        clinicAddress,
                        style: TextStyle(
                          color: primaryGreen.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (hasData && _clinics.length > 1)
                      GestureDetector(
                        onTap: _scrollToLocations,
                        child: Text(
                          "${_clinics.length - 1} More clinic",
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  "$waitTime or less wait time",
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                const SizedBox(height: 20),

                // Date Tabs
                Row(
                  children: List.generate(3, (index) {
                    final date = DateTime.now().add(Duration(days: index));
                    final isSelected = _selectedDateIndex == index;
                    String label =
                        index == 0
                            ? "Today"
                            : index == 1
                            ? "Tomorrow"
                            : DateFormat('d MMM').format(date);

                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDateIndex = index;
                            _selectedTimeSlotIndex = -1;
                          });
                          _fetchBookedSlots();
                        },
                        child: Column(
                          children: [
                            Text(
                              label,
                              style: TextStyle(
                                fontWeight:
                                    isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                color: isSelected ? textDark : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 3,
                              color:
                                  isSelected
                                      ? primaryGreen
                                      : Colors.transparent,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
                const Divider(height: 1, color: Colors.grey),
                const SizedBox(height: 20),

                // Time Slots
                if (_isLoadingSlots)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else if (availableSlots.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        "No slots available",
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children:
                          availableSlots.asMap().entries.map((entry) {
                            final index = entry.key;
                            final slotText = entry.value;
                            final isBooked = _bookedSlots.contains(slotText);
                            final isSelected = _selectedTimeSlotIndex == index;

                            return GestureDetector(
                              onTap:
                                  isBooked
                                      ? null
                                      : () => setState(
                                        () => _selectedTimeSlotIndex = index,
                                      ),
                              child: Container(
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isBooked
                                          ? Colors.grey[200]
                                          : isSelected
                                          ? primaryGreen.withValues(alpha: 0.15)
                                          : cyanHeader,
                                  borderRadius: BorderRadius.circular(20),
                                  border:
                                      isSelected && !isBooked
                                          ? Border.all(color: primaryGreen)
                                          : null,
                                ),
                                child: Text(
                                  slotText,
                                  style: TextStyle(
                                    color:
                                        isBooked
                                            ? Colors.grey[400]
                                            : isSelected
                                            ? primaryGreen
                                            : const Color(0xFF00695C),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimingList() {
    if (_schedules.isEmpty) {
      return const Text(
        "No schedule info",
        style: TextStyle(color: Colors.grey),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children:
            _schedules.map((s) {
              final day = s['day_of_week'] ?? 'Day';
              final start = s['start_time'].toString().substring(0, 5);
              final end = s['end_time'].toString().substring(0, 5);
              return Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(16),
                width: 140,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      day,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "$start - $end",
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }).toList(),
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
                  padding: const EdgeInsets.all(16),
                  width: 160,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? primaryGreen : Colors.grey.shade200,
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow:
                        isSelected
                            ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                              ),
                            ]
                            : [],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shortName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? textDark : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        clinic['name'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
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
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
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
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
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
                          gradient: RadialGradient(
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
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),

        // --- VERTICAL STACK FOR FABs ---
        Positioned(
          bottom: 12,
          right: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 1. LOCATOR MENU ROW
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
                        tooltip: "Clinic Location",
                        child: Icon(
                          Icons.medical_services_outlined,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ),

                  // Only show "User Location" button if navigating
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
                          tooltip: "My Location",
                          child: Icon(
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

              const SizedBox(height: 16), // Spacing between rows
              // 2. DIRECTIONS MENU ROW
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
                        tooltip: "Google Maps",
                        child: const Icon(
                          Icons.public,
                          color: Colors.blue,
                        ), // Globe icon
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
                        tooltip: "In-App Route",
                        child: Icon(
                          Icons.turn_sharp_right,
                          color: primaryGreen,
                        ), // Turn icon
                      ),
                    ),
                  ),
                  FloatingActionButton.small(
                    heroTag: "btn_main_toggle",
                    backgroundColor: primaryGreen, // Colored Main Button
                    onPressed: _toggleDirectionMenu,
                    child: RotationTransition(
                      turns: _rotateAnimation,
                      child: Icon(
                        _isMenuOpen
                            ? Icons.close
                            : Icons.directions, // Signpost
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

  Widget _buildStars(String rating) {
    double val = double.tryParse(rating) ?? 0.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (i < val.floor()) {
          return const Icon(Icons.star, color: Colors.amber, size: 14);
        } else if (i == val.floor() && (val - i) >= 0.5) {
          return const Icon(Icons.star_half, color: Colors.amber, size: 14);
        } else {
          return Icon(Icons.star_border, color: Colors.grey[300], size: 14);
        }
      }),
    );
  }
}
