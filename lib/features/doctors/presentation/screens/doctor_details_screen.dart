import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/network/network_notifier.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../favorites_notifier.dart';
import '../../../../presentation/widgets/primary_button.dart';
import '../../../../presentation/widgets/app_bottom_tray.dart';

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

class DoctorDetailsScreen extends StatefulWidget {
  final String doctorId;
  final Map<String, dynamic>? doctorData; 
  final bool scrollToMap;

  const DoctorDetailsScreen({
    super.key,
    required this.doctorId,
    this.doctorData,
    this.scrollToMap = false,
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

  bool _isHeavyDataLoading = true;
  bool _isOfflineState = false;
  String? _errorMessage;

  Map<String, dynamic>? _doctor;
  final List<Map<String, dynamic>> _clinics = [];
  final List<Map<String, dynamic>> _schedules = [];
  Map<String, dynamic>? _selectedClinic;
  List<Map<String, dynamic>> _reviews = [];

  DateTime _selectedDate = DateTime.now();
  
  // PRO FIX: Upgraded to track precise booking counts instead of a flat list!
  Map<String, int> _slotBookingCounts = {};
  String? _selectedTimeSlot;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _locationSectionKey = GlobalKey();
  Timer? _viewTimer;
  bool _hasRecordedView = false;

  @override
  void initState() {
    super.initState();
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
        _isOfflineState = NetworkNotifier.instance.isOffline;
      });

      if (!NetworkNotifier.instance.isOffline) {
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
      final doctor = await _doctorRepo.fetchDoctorDetails(widget.doctorId);
      if (mounted) {
        setState(() {
          _doctor = doctor.toJson();
        });
      }

      final results = await Future.wait([
        _doctorRepo.fetchClinics(widget.doctorId),
        _doctorRepo.fetchSchedules(widget.doctorId),
        _doctorRepo.fetchDoctorReviews(widget.doctorId),
      ]);

      final clinics = List<Map<String, dynamic>>.from(results[0]);
      final schedules = List<Map<String, dynamic>>.from(results[1]);
      final reviews = List<Map<String, dynamic>>.from(results[2]);

      if (!mounted) return;

      setState(() {
        _clinics.clear();
        _clinics.addAll(clinics);
        _schedules.clear();
        _schedules.addAll(schedules);
        _reviews = reviews;
        _selectedClinic = _clinics.isNotEmpty ? _clinics.first : null;
        _errorMessage =
            clinics.isEmpty
                ? "No clinic location data is available for this doctor."
                : null;
        _isHeavyDataLoading = false;
      });

      if (_selectedClinic != null) {
        _fetchBookedSlots();
      }
      _startViewTimer();
      if (widget.scrollToMap) {
        _scrollToLocationSection();
      }
    } catch (e) {
      debugPrint("Error fetching data: $e");
      if (mounted) {
        setState(() {
          _isHeavyDataLoading = false;
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
      // PRO FIX: Now using the advanced capacity fetcher!
      final counts = await _appointmentRepo.fetchSlotBookingCounts(
        doctorId: widget.doctorId,
        clinicId: _selectedClinic!['id'].toString(),
        date: dateStr,
      );
      if (mounted) {
        setState(() {
          _slotBookingCounts = counts;
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
      extra: <String, dynamic>{
        'doctor': _doctor ?? <String, dynamic>{},
        'clinic': _selectedClinic ?? <String, dynamic>{},
        'initialDate': _selectedDate,
        'timeSlot': _selectedTimeSlot,
        'idempotencyKey': _uuid.v4(),
      },
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

  // PRO FIX: Now generates Map objects with Capacity Logic!
  List<Map<String, dynamic>> _getSlotsForSelectedDate() {
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

    List<Map<String, dynamic>> allSlots = [];
    for (var scheduleEntry in daySchedules) {
      try {
        final startStr = scheduleEntry['start_time'].toString();
        final endStr = scheduleEntry['end_time'].toString();
        final duration = scheduleEntry['slot_duration_minutes'] as int? ?? 30;
        final maxCapacity = scheduleEntry['max_patients'] as int? ?? 1;

        TimeOfDay startTime = _parseTime(startStr);
        TimeOfDay endTime = _parseTime(endStr);

        int startMinutes = startTime.hour * 60 + startTime.minute;
        int endMinutes = endTime.hour * 60 + endTime.minute;

        while (startMinutes + duration <= endMinutes) {
          bool isPast = false;
          if (isToday) {
            final slotHour = startMinutes ~/ 60;
            final slotMinute = startMinutes % 60;
            final slotTime = DateTime(now.year, now.month, now.day, slotHour, slotMinute);
            if (slotTime.isBefore(now)) isPast = true;
          }

          if (!isPast) {
            final sTime = _minutesToTime(startMinutes);
            final eTime = _minutesToTime(startMinutes + duration);
            final slotStr = "$sTime - $eTime";

            int currentBookings = _slotBookingCounts[slotStr] ?? 0;
            int spotsLeft = maxCapacity - currentBookings;
            bool isFull = spotsLeft <= 0;

            allSlots.add({
              'time': slotStr,
              'spotsLeft': spotsLeft > 0 ? spotsLeft : 0,
              'isFull': isFull,
            });
          }
          startMinutes += duration;
        }
      } catch (e) {
        debugPrint("Error parsing schedule row: $e");
      }
    }
    
    allSlots.sort((a, b) => a['time'].compareTo(b['time']));
    
    // Deduplicate in case of overlapping schedule rows
    final uniqueSlots = <String, Map<String, dynamic>>{};
    for (var slot in allSlots) {
       uniqueSlots[slot['time']] = slot;
    }
    return uniqueSlots.values.toList();
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

  bool get _hasVisibleReviews {
    if (_doctor == null) return false;
    final reviewsCount =
        int.tryParse(_doctor!['reviews_count']?.toString() ?? '0') ?? 0;
    return reviewsCount > 0 && _reviews.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    if (_doctor == null && _isHeavyDataLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: _buildAppBar(),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: bgColor,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(gradient: AppStyles.pageGradient(context)),
            child: Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetchInitialData,
                    color: AppColors.primaryGreen,
                    edgeOffset: MediaQuery.paddingOf(context).top + kToolbarHeight,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        24,
                        MediaQuery.paddingOf(context).top + kToolbarHeight + 20,
                        24,
                        120 + MediaQuery.viewInsetsOf(context).bottom, // Dynamic bottom clearance
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
                            // THE FIX: Added this line back so the button works!
                            onBookNowTap: _handleBooking, 
                          ),
                          const SizedBox(height: 14),

                          DoctorStatsRow(
                            patients:
                                _doctor!['unique_patients_count']?.toString() ?? '0',
                            experience:
                                _doctor!['experience_years']?.toString() ?? '0',
                            rating: _doctor!['rating']?.toString() ?? '0.0',
                          ),

                          const SizedBox(height: 24),

                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            switchInCurve: Curves.easeOutQuart,
                            switchOutCurve: Curves.easeInQuart,
                            child: _isOfflineState ? 
                              Container(
                                key: const ValueKey('offline'),
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
                              ) 
                              : _isHeavyDataLoading ? 
                              const SizedBox(
                                key: ValueKey('loading'),
                                height: 480,
                                child: Center(
                                  child: CircularProgressIndicator(color: AppColors.primaryGreen),
                                ),
                              )
                              : Column(
                                key: const ValueKey('content'),
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
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
                                      final tomorrow = now.add(
                                        const Duration(days: 1),
                                      );
                                      DateTime thirdDate = now.add(
                                        const Duration(days: 2),
                                      );
                                      final isCustomDate =
                                          !_isSameDay(_selectedDate, today) &&
                                          !_isSameDay(_selectedDate, tomorrow);
                                      if (isCustomDate) {
                                        thirdDate = _selectedDate;
                                      }
                                      final datesToShow = [today, tomorrow, thirdDate];

                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          DoctorAppointmentCard(
                                            clinics: _clinics,
                                            selectedClinic: _selectedClinic,
                                            selectedDate: _selectedDate,
                                            datesToShow: datesToShow,
                                            timeSlots: _getSlotsForSelectedDate(),
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
                                            onMoreClinicTap:
                                                _scrollToLocationSection,
                                          ),
                                          const SizedBox(height: 24),
                                          Text(
                                            "Timing",
                                            style: AppTextStyles.h3(context),
                                          ),
                                          const SizedBox(height: 10),
                                          DoctorTimingList(
                                            schedules: _schedules,
                                          ),
                                          const SizedBox(height: 24),
                                          Text(
                                            "Location",
                                            key: _locationSectionKey,
                                            style: AppTextStyles.h3(context),
                                          ),
                                          const SizedBox(height: 10),
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
                                            scrollToTop:
                                                _scrollToLocationSection,
                                          ),
                                          const SizedBox(height: 32),
                                          if (_hasVisibleReviews) ...[
                                            Text(
                                              "Patient Reviews",
                                              style: AppTextStyles.h3(context),
                                            ),
                                            const SizedBox(height: 12),
                                            _buildReviewSection(),
                                          ],
                                          const SizedBox(height: 24),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (!_isHeavyDataLoading && !_isOfflineState)
                  AppBottomTray(
                    child: PrimaryButton(
                      label: "Book Appointment",
                      onTap: _handleBooking,
                      height: 54,
                      borderRadius: 16,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewSection() {
    final reviewsCount =
        int.tryParse(_doctor!['reviews_count']?.toString() ?? '0') ?? 0;
    if (reviewsCount == 0 || _reviews.isEmpty) return const SizedBox.shrink();

    final aggregatedReviews = _getAggregatedReviews();
    final previewReviews = aggregatedReviews.take(2).toList();

    return Column(
      children: [
        ...previewReviews.map((aggData) {
          final fullName =
              aggData['profiles']?['full_name']?.toString() ?? "Anonymous";
          final initials = _getInitials(fullName);
          final avgRating = (aggData['avg_rating'] as num?)?.toDouble() ?? 5.0;
          final visitCount = aggData['visit_count'] as int? ?? 1;
          final date = _formatReviewDate(aggData['created_at']);
          final comment =
              aggData['latest_comment'] as String? ??
              "Verified consultation completed.";
          final history = List<Map<String, dynamic>>.from(
            aggData['history'] ?? const [],
          );

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildAggregatedReviewCard(
              initials: initials,
              avgRating: avgRating,
              date: date,
              comment: comment,
              visitCount: visitCount,
              history: history,
              onTap:
                  visitCount > 1
                      ? () => _showPatientJourneySheet(
                        initials,
                        avgRating,
                        visitCount,
                        history,
                      )
                      : null,
            ),
          );
        }),
        if (aggregatedReviews.length > 2)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: AppColors.primaryGreen.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.05),
              ),
              onPressed: _showFullReviewsSheet,
              child: Text(
                "Read all ${aggregatedReviews.length} Patient Stories",
                style: const TextStyle(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAggregatedReviewCard({
    required String initials,
    required double avgRating,
    required String date,
    required String comment,
    required int visitCount,
    required List<Map<String, dynamic>> history,
    required VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: AppStyles.surfaceCard(
          context,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryGreen.withValues(alpha: isDark ? 0.2 : 0.12),
                  ),
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            avgRating.toStringAsFixed(1),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: context.colorTextDark,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (visitCount > 1)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.infoBlue.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "$visitCount Visits",
                                style: const TextStyle(
                                  color: AppColors.infoBlue,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        date,
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (visitCount > 1)
                  Icon(
                    Icons.history_rounded,
                    size: 18,
                    color: isDark ? Colors.white30 : Colors.black26,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              comment,
              style: AppTextStyles.bodySmall(
                context,
              ).copyWith(color: context.colorTextDark, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  void _showPatientJourneySheet(
    String initials,
    double avgRating,
    int visitCount,
    List<Map<String, dynamic>> history,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            minChildSize: 0.4,
            builder:
                (context, scrollController) => ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      color: Theme.of(
                        context,
                      ).scaffoldBackgroundColor.withValues(alpha: 0.95),
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          Container(
                            width: 40,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          const SizedBox(height: 24),
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: AppColors.primaryGreen.withValues(
                              alpha: 0.15,
                            ),
                            child: Text(
                              initials,
                              style: const TextStyle(
                                color: AppColors.primaryGreen,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Patient Journey",
                            style: AppTextStyles.h2(
                              context,
                            ).copyWith(letterSpacing: -0.5),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "$visitCount total consultations - ${avgRating.toStringAsFixed(1)} Avg Rating",
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.grey,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Divider(height: 1, color: Colors.black12),
                          Expanded(
                            child: ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.all(24),
                              itemCount: history.length,
                              itemBuilder: (context, index) {
                                final entry = history[index];
                                final reviewDate = _formatReviewDate(
                                  entry['created_at'],
                                );
                                final reviewRating =
                                    (entry['rating'] as num?)?.toInt() ?? 5;
                                final reviewComment =
                                    entry['comment']?.toString().trim().isNotEmpty ==
                                            true
                                        ? entry['comment'].toString().trim()
                                        : "Verified consultation.";

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Column(
                                      children: [
                                        Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color:
                                                index == 0
                                                    ? AppColors.primaryGreen
                                                    : Colors.grey,
                                          ),
                                        ),
                                        if (index != history.length - 1)
                                          Container(
                                            width: 2,
                                            height: 60,
                                            color: Colors.grey.withValues(
                                              alpha: 0.2,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 24,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    reviewDate,
                                                    style: TextStyle(
                                                      color:
                                                          isDark
                                                              ? Colors.white
                                                              : Colors.black87,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ),
                                                Row(
                                                  children: List.generate(5, (
                                                    i,
                                                  ) {
                                                    return Icon(
                                                      i < reviewRating
                                                          ? Icons.star_rounded
                                                          : Icons
                                                              .star_border_rounded,
                                                      size: 12,
                                                      color: Colors.amber,
                                                    );
                                                  }),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              reviewComment,
                                              style: TextStyle(
                                                color:
                                                    isDark
                                                        ? Colors.white70
                                                        : Colors.black54,
                                                fontSize: 12,
                                                height: 1.4,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ),
    );
  }

  List<Map<String, dynamic>> _getAggregatedReviews() {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (final review in _reviews) {
      final userId = review['user_id']?.toString() ?? _uuid.v4();
      grouped.putIfAbsent(userId, () => []).add(review);
    }

    final List<Map<String, dynamic>> aggregated = [];

    for (final entry in grouped.entries) {
      final userReviews = entry.value;

      userReviews.sort((a, b) {
        final dateA =
            DateTime.tryParse(a['created_at'].toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final dateB =
            DateTime.tryParse(b['created_at'].toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });

      final latestReview = userReviews.first;
      double totalRating = 0;

      for (final review in userReviews) {
        totalRating += (review['rating'] as num?)?.toDouble() ?? 5.0;
      }

      final avgRating = totalRating / userReviews.length;

      aggregated.add({
        'user_id': entry.key,
        'profiles': latestReview['profiles'],
        'latest_comment':
            latestReview['comment']?.toString().trim().isNotEmpty == true
                ? latestReview['comment'].toString().trim()
                : null,
        'created_at': latestReview['created_at'],
        'avg_rating': avgRating,
        'visit_count': userReviews.length,
        'history': userReviews,
      });
    }

    aggregated.sort((a, b) {
      final dateA =
          DateTime.tryParse(a['created_at'].toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final dateB =
          DateTime.tryParse(b['created_at'].toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return dateB.compareTo(dateA);
    });

    return aggregated;
  }

  String _getInitials(String fullName) {
    if (fullName.trim().isEmpty) return "A.";
    final names = fullName.trim().split(RegExp(r'\s+'));
    if (names.length >= 2) {
      return "${names.first[0].toUpperCase()}. ${names.last[0].toUpperCase()}.";
    }
    return "${names.first[0].toUpperCase()}.";
  }

  String _formatReviewDate(dynamic rawDate) {
    try {
      if (rawDate == null) return "";
      return DateFormat(
        'MMM dd, yyyy',
      ).format(DateTime.parse(rawDate.toString()));
    } catch (e) {
      return "";
    }
  }

  void _showFullReviewsSheet() {
    if (_doctor == null || _reviews.isEmpty) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final aggregatedReviews = _getAggregatedReviews();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.85,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            builder:
                (context, scrollController) => ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      color: Theme.of(
                        context,
                      ).scaffoldBackgroundColor.withValues(alpha: 0.85),
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          Container(
                            width: 40,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            "Patient Stories",
                            style: AppTextStyles.h2(
                              context,
                            ).copyWith(letterSpacing: -0.5),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: Colors.amber,
                                size: 28,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "${_doctor!['rating']?.toString() ?? '0.0'}",
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            "Based on ${_doctor!['reviews_count']} verified appointments",
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Divider(height: 1, color: Colors.black12),
                          Expanded(
                            child: ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.all(24),
                              itemCount: aggregatedReviews.length,
                              itemBuilder: (context, index) {
                                final aggData = aggregatedReviews[index];
                                final fullName =
                                    aggData['profiles']?['full_name']?.toString() ??
                                    "Anonymous";
                                final initials = _getInitials(fullName);
                                final avgRating =
                                    (aggData['avg_rating'] as num?)?.toDouble() ??
                                    5.0;
                                final visitCount =
                                    aggData['visit_count'] as int? ?? 1;
                                final date = _formatReviewDate(
                                  aggData['created_at'],
                                );
                                final comment =
                                    aggData['latest_comment'] as String? ??
                                    "Verified consultation completed.";
                                final history = List<Map<String, dynamic>>.from(
                                  aggData['history'] ?? const [],
                                );

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _buildAggregatedReviewCard(
                                    initials: initials,
                                    avgRating: avgRating,
                                    date: date,
                                    comment: comment,
                                    visitCount: visitCount,
                                    history: history,
                                    onTap:
                                        visitCount > 1
                                            ? () {
                                              Navigator.pop(context);
                                              _showPatientJourneySheet(
                                                initials,
                                                avgRating,
                                                visitCount,
                                                history,
                                              );
                                            }
                                            : null,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return const CustomAppBar(
      title: "Doctor Details",
      actions: [SizedBox(width: 72)],
    );
  }
}
