import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../favorites_notifier.dart';
import '../../../../presentation/widgets/primary_button.dart';

import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../doctors/data/doctor_repository.dart';
import '../../../appointments/data/appointment_repository.dart';

import '../widgets/doctor_details_header.dart';
import '../widgets/doctor_stats_row.dart';
import '../widgets/doctor_appointment_card.dart';
import '../widgets/doctor_timing_list.dart';
import '../widgets/clinic_location_map_section.dart';
import 'package:uuid/uuid.dart';
import '../../../appointments/presentation/models/booking_route_args.dart';

class DoctorDetailsScreen extends StatefulWidget {
  final String doctorId;

  const DoctorDetailsScreen({super.key, required this.doctorId});

  @override
  State<DoctorDetailsScreen> createState() => _DoctorDetailsScreenState();
}

class _DoctorDetailsScreenState extends State<DoctorDetailsScreen> {
  final Uuid _uuid = const Uuid();
  // --- DESIGN COLORS (aliased from AppColors) ---

  static const Color primaryGreen = AppColors.primaryGreen;

  static const Color bgColor = AppColors.bgColor;

  // --- DATA STATE ---

  final _doctorRepo = DoctorRepository();
  final _appointmentRepo = AppointmentRepository();
  final _favNotifier = FavoritesNotifier.instance;

  bool _isLoading = true;
  String? _errorMessage;

  Map<String, dynamic>? _doctor;

  final List<Map<String, dynamic>> _clinics = [];

  final List<Map<String, dynamic>> _schedules = [];

  // Tracks the user's selected clinic/location
  Map<String, dynamic>? _selectedClinic;

  // Booking Data

  DateTime _selectedDate = DateTime.now();

  final List<String> _bookedSlots = [];

  String? _selectedTimeSlot;

  // --- UI STATE ---

  final ScrollController _scrollController = ScrollController();

  final GlobalKey _locationSectionKey = GlobalKey();
  Timer? _viewTimer;
  bool _hasRecordedView = false;

  @override
  void initState() {
    super.initState();
    _favNotifier.addListener(_onFavoritesChanged);
    _fetchInitialData();
  }

  @override
  void dispose() {
    _viewTimer?.cancel();
    _favNotifier.removeListener(_onFavoritesChanged);
    _scrollController.dispose();

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final sectionContext = _locationSectionKey.currentContext;
      if (sectionContext == null) return;
      try {
        Scrollable.ensureVisible(
          sectionContext,
          duration: AppMotion.defaultDuration,
          curve: Curves.easeInOut,
          alignment: 0.05,
        );
      } catch (e) {
        debugPrint('Scroll to location skipped before layout is ready: $e');
      }
    });
  }

  // --- ANALYTICS LOGIC ---

  void _startViewTimer() {
    _viewTimer?.cancel();
    _viewTimer = Timer(const Duration(seconds: 3), () {
      unawaited(_recordView());
    });
  }

  Future<void> _recordView() async {
    if (_hasRecordedView) return;
    _hasRecordedView = true;
    await _doctorRepo.incrementDoctorViewCount(widget.doctorId);
  }

  // --- BOOKING LOGIC ---

  Future<void> _fetchInitialData() async {
    try {
      final doctor = await _doctorRepo.fetchDoctorDetails(widget.doctorId);
      List<Map<String, dynamic>> clinics = const [];
      List<Map<String, dynamic>> schedules = const [];
      String? partialError;

      try {
        final results = await Future.wait([
          _doctorRepo.fetchClinics(widget.doctorId),
          _doctorRepo.fetchSchedules(widget.doctorId),
        ]);
        clinics = List<Map<String, dynamic>>.from(results[0]);
        schedules = List<Map<String, dynamic>>.from(results[1]);
      } catch (e) {
        debugPrint("Error fetching clinics/schedules: $e");
        partialError =
            "Some location or schedule data couldn't be loaded right now.";
      }

      if (partialError == null && clinics.isEmpty) {
        partialError = "No clinic location data is available for this doctor.";
      }

      if (!mounted) return;

      setState(() {
        _doctor = doctor.toJson();
        _clinics.clear();
        _clinics.addAll(clinics);
        _schedules.clear();
        _schedules.addAll(schedules);
        _selectedClinic = _clinics.isNotEmpty ? _clinics.first : null;
        _errorMessage = partialError;
        _isLoading = false;
      });

      if (_selectedClinic != null) {
        _fetchBookedSlots();
      }
      _startViewTimer();
    } catch (e) {
      debugPrint("Error fetching data: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load doctor details.";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchBookedSlots() async {
    if (_selectedClinic == null) return;
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final slots = await _appointmentRepo.fetchBookedSlots(
        doctorId: widget.doctorId,
        clinicId: _selectedClinic!['id'].toString(),
        date: dateStr,
      );
      if (mounted) {
        setState(() {
          _bookedSlots.clear();
          _bookedSlots.addAll(slots);
        });
      }
    } catch (e) {
      debugPrint("Error fetching booked slots: $e");
    }
  }

  Future<void> _handleBooking() async {
    // Validation for clinic is still required, but time slot is now optional at this stage.
    if (_selectedClinic == null) {
      CustomSnackbar.showError(context, "No clinic selected");
      return;
    }

    // IMPORTANT: We pass the selected clinic, doctor, and date to the next screen.
    // The next screen will use this clinic ID to show relevant slots.
    context.push(
      AppRoutes.appointmentBooking,
      extra: AppointmentBookingArgs(
        doctor: Map<String, dynamic>.from(_doctor ?? const {}),
        clinic: Map<String, dynamic>.from(_selectedClinic ?? const {}),
        initialDate: _selectedDate,
        timeSlot: _selectedTimeSlot,
        idempotencyKey: _uuid.v4(),
      ),
    );
  }

  void _toggleFavorite() {
    final docIdInt = int.tryParse(widget.doctorId);
    if (docIdInt == null) return;
    _favNotifier.toggle(docIdInt);
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
              child: RefreshIndicator(
                onRefresh: _fetchInitialData,
                color: AppColors.primaryGreen,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),

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
                        patients:
                            _doctor!['patients_served']?.toString() ?? '100',
                        experience:
                            _doctor!['experience_years']?.toString() ?? '5',
                        rating: _doctor!['rating']?.toString() ?? '0.0',
                      ),

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.deepOrange,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],

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

                      ClinicLocationMapSection(
                        clinics: _clinics,
                        selectedClinic: _selectedClinic,
                        onClinicSelected: (clinic) {
                          setState(() {
                            _selectedClinic = clinic;
                            _selectedTimeSlot = null;
                          });
                          _fetchBookedSlots();
                        },
                        scrollToTop: _scrollToLocationSection,
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
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
}
