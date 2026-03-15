import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/network/network_notifier.dart'; // PRO FIX: Network listener added
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/empty_state_widget.dart';
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
  final Map<String, dynamic>? doctorData; // PRO FIX: Accepts Hand-off data!

  const DoctorDetailsScreen({
    super.key,
    required this.doctorId,
    this.doctorData,
  });

  @override
  State<DoctorDetailsScreen> createState() => _DoctorDetailsScreenState();
}

class _DoctorDetailsScreenState extends State<DoctorDetailsScreen> {
  final Uuid _uuid = Uuid();
  Color get primaryGreen => AppColors.primaryGreen;
  Color get bgColor => context.colorBg;

  final _doctorRepo = DoctorRepository();
  final _appointmentRepo = AppointmentRepository();
  final _favNotifier = FavoritesNotifier.instance;

  // PRO FIX: Separated loading states for top and bottom half
  bool _isHeavyDataLoading = true;
  bool _isOfflineState = false;
  String? _errorMessage;

  Map<String, dynamic>? _doctor;
  final List<Map<String, dynamic>> _clinics = [];
  final List<Map<String, dynamic>> _schedules = [];
  Map<String, dynamic>? _selectedClinic;

  DateTime _selectedDate = DateTime.now();
  final List<String> _bookedSlots = [];
  String? _selectedTimeSlot;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _locationSectionKey = GlobalKey();
  Timer? _viewTimer;
  bool _hasRecordedView = false;

  @override
  void initState() {
    super.initState();
    // PRO FIX: Instantly load the hand-off data so the top half renders in 0ms!
    if (widget.doctorData != null) {
      _doctor = widget.doctorData;
    }

    _favNotifier.addListener(_onFavoritesChanged);
    NetworkNotifier.instance.addListener(_onNetworkChanged);
    _fetchInitialData();
  }

  @override
  void dispose() {
    _viewTimer?.cancel();
    _favNotifier.removeListener(_onFavoritesChanged);
    NetworkNotifier.instance.removeListener(_onNetworkChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onNetworkChanged() {
    if (mounted) {
      setState(() {
        // Instantly update the UI flag to hide the offline card when internet returns
        _isOfflineState = NetworkNotifier.instance.isOffline;
      });

      if (!NetworkNotifier.instance.isOffline) {
        // The millisecond internet returns, automatically fetch the clinics & schedules
        // The UI will show the loading spinner in the bottom half and then render the data smoothly!
        _isHeavyDataLoading = true;
        _fetchInitialData();
      }
    }
  }

  void _onFavoritesChanged() {
    if (mounted) setState(() {});
  }

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

  Future<void> _fetchInitialData() async {
    try {
      // 1. Fetch full details silently in background to update any missing stats
      final doctor = await _doctorRepo.fetchDoctorDetails(widget.doctorId);
      if (mounted) {
        setState(() {
          _doctor = doctor.toJson();
        });
      }

      // 2. Fetch the heavy data (clinics & schedules)
      final results = await Future.wait([
        _doctorRepo.fetchClinics(widget.doctorId),
        _doctorRepo.fetchSchedules(widget.doctorId),
      ]);

      final clinics = List<Map<String, dynamic>>.from(results[0]);
      final schedules = List<Map<String, dynamic>>.from(results[1]);

      if (!mounted) return;

      setState(() {
        _clinics.clear();
        _clinics.addAll(clinics);
        _schedules.clear();
        _schedules.addAll(schedules);
        _selectedClinic = _clinics.isNotEmpty ? _clinics.first : null;

        if (clinics.isEmpty) {
          _errorMessage =
              "No clinic location data is available for this doctor.";
        }
        _isHeavyDataLoading = false;
      });

      if (_selectedClinic != null) {
        _fetchBookedSlots();
      }
      _startViewTimer();
    } catch (e) {
      debugPrint("Error fetching data: $e");
      if (mounted) {
        setState(() {
          _isHeavyDataLoading = false;
          // PRO FIX: Handle offline state gracefully!
          if (NetworkNotifier.instance.isOffline) {
            _isOfflineState = true;
          } else {
            _errorMessage = "Failed to load location and schedule details.";
          }
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
    if (_selectedClinic == null) {
      CustomSnackbar.showError(context, "No clinic selected");
      return;
    }

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
    if (_doctor == null) return;
    _favNotifier.toggle(_doctor!);
  }

  Future<void> _openDatePicker() async {
    final now = DateTime.now();

    final pickedDate = await showDialog<DateTime>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Dialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Select Date", style: AppTextStyles.h3(context)),
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

  List<String> _getSlotsForSelectedDate() {
    if (_schedules.isEmpty || _selectedClinic == null) return [];
    final dayName = DateFormat('EEEE').format(_selectedDate);
    final now = DateTime.now();
    final isToday = _isSameDay(_selectedDate, now);

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
    // If we have ZERO data (no hand-off and no network fetch yet), show full loading.
    if (_doctor == null && _isHeavyDataLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const AppLoader(),
      );
    }

    if (_doctor == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: EmptyStateWidget(
          icon: Icons.error_outline,
          title: "Doctor Not Found",
          subtitle: "We couldn't find the doctor you're looking for.",
          actionButton: ElevatedButton(
            onPressed: () => context.pop(),
            child: const Text("Go Back"),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildAppBar(),
      body: Container(
        decoration: BoxDecoration(gradient: AppStyles.pageGradient(context)),
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
                      // --- TOP HALF: Instantly loads! ---
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
                            _doctor!['patients_served']?.toString() ?? '100+',
                        experience:
                            _doctor!['experience_years']?.toString() ?? '5',
                        rating: _doctor!['rating']?.toString() ?? '0.0',
                      ),
                      const SizedBox(height: 24),

                      // --- BOTTOM HALF: Graceful Loading & Offline States ---
                      if (_isHeavyDataLoading) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: AppLoader(),
                        ),
                      ] else if (_isOfflineState) ...[
                        // PRO FIX: Beautiful Offline Fallback Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.primaryGreen.withValues(
                                alpha: 0.2,
                              ),
                            ),
                            boxShadow: AppStyles.cardShadow(context),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.wifi_off_rounded,
                                size: 42,
                                color: context.colorTextLight,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "You are offline",
                                style: AppTextStyles.h3(context),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Connect to the internet to view ${_doctor!['full_name']}'s schedules, clinics, and reviews.",
                                textAlign: TextAlign.center,
                                style: AppTextStyles.bodySmall(
                                  context,
                                ).copyWith(
                                  color: context.colorTextLight,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // Success! Render the heavy data
                        if (_errorMessage != null) ...[
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
                          const SizedBox(height: 14),
                        ],

                        Builder(
                          builder: (context) {
                            final now = DateTime.now();
                            final today = now;
                            final tomorrow = now.add(const Duration(days: 1));
                            DateTime thirdDate = now.add(
                              const Duration(days: 2),
                            );
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
                              selectedTimeSlot: _selectedTimeSlot,
                              onClinicChanged: (clinic) {
                                if (clinic != null) {
                                  setState(() {
                                    _selectedClinic = clinic;
                                    _selectedTimeSlot = null;
                                  });
                                  _fetchBookedSlots();
                                }
                              },
                              onDateSelected: (date) {
                                setState(() {
                                  _selectedDate = date;
                                  _selectedTimeSlot = null;
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
                        Text("Timing", style: AppTextStyles.h3(context)),
                        const SizedBox(height: 10),
                        DoctorTimingList(schedules: _schedules),
                        const SizedBox(height: 18),
                        Text(
                          "Location",
                          key: _locationSectionKey,
                          style: AppTextStyles.h3(context),
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
                    ],
                  ),
                ),
              ),
            ),

            // --- BOTTOM BUTTON ---
            // Hide booking button if offline or still loading clinics
            if (!_isHeavyDataLoading && !_isOfflineState)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: AppStyles.cardShadow(context),
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
            decoration: AppStyles.surfaceCard(
              context,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: context.colorTextDark,
            ),
          ),
        ),
      ),
      title: Text(
        "Doctor Details",
        style: AppTextStyles.h3(context).copyWith(fontSize: 20),
      ),
      actions: const [SizedBox(width: 64)],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(8),
        child: Container(),
      ),
    );
  }
}
