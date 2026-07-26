import 'package:flutter/material.dart';
import '../../../../core/widgets/volumetric_scaffold.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // PRO FIX: Added for Real-Time
import '../../../../core/constants/app_routes.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../doctors/data/doctor_repository.dart';
import '../../data/appointment_repository.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';
import '../../../../presentation/widgets/primary_button.dart';
import 'package:intl/intl.dart';
import '../models/booking_route_args.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/router/app_router.dart';
import '../../../../presentation/widgets/app_bottom_tray.dart';

class AppointmentConfirmationScreen extends StatefulWidget {
  final Map<String, dynamic> doctor;
  final Map<String, dynamic> clinic;
  final Map<String, dynamic> patientDetails;
  final DateTime initialDate;
  final int? appointmentId;
  final String? timeSlot;
  final String idempotencyKey;

  const AppointmentConfirmationScreen({
    super.key,
    required this.doctor,
    required this.clinic,
    required this.patientDetails,
    required this.initialDate,
    this.appointmentId,
    this.timeSlot,
    required this.idempotencyKey,
  });

  @override
  State<AppointmentConfirmationScreen> createState() =>
      _AppointmentConfirmationScreenState();
}

class _AppointmentConfirmationScreenState
    extends State<AppointmentConfirmationScreen> {
  Color get primaryGreen => AppColors.primaryGreen;
  Color get textDark => context.colorTextDark;
  Color get textLight => context.colorTextLight; // <--- ADD THIS LINE!
  Color get textGrey => context.colorTextGrey;
  Color get borderColor => context.colorBorder;

  final _doctorRepo = DoctorRepository();
  final _appointmentRepo = AppointmentRepository();

  TextStyle get _sectionHeaderStyle => AppTextStyles.h3(context);

  late DateTime _focusedDate;
  late DateTime _selectedDate;
  List<Map<String, dynamic>> _schedules = [];
  
  Map<String, int> _slotBookingCounts = {};
  bool _isLoading = true;

  int _selectedTimeSlotIndex = -1;

  // PRO FIX: The WebSocket channel for live updates
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _focusedDate = widget.initialDate;
    _selectedDate = widget.initialDate;

    _fetchSchedulesAndBookings();
    _setupRealtimeSubscription(); // PRO FIX: Boot up the live listener!
  }

  @override
  void dispose() {
    // PRO FIX: Instantly kill the WebSocket when they leave to save money
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  // --- PRO FIX: The highly-filtered, cheap Real-Time Listener ---
  void _setupRealtimeSubscription() {
    final doctorId = widget.doctor['id'].toString();

    _realtimeChannel = Supabase.instance.client
        .channel('public:appointments:doctor_$doctorId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all, // Listen to inserts, updates, and deletes
          schema: 'public',
          table: 'appointments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'doctor_id',
            value: doctorId,
          ),
          callback: (payload) {
            // If anyone books or cancels an appointment for this doctor, refresh the live UI!
            debugPrint('🔄 Real-Time: Doctor schedule changed! Refreshing UI...');
            if (mounted) {
              _fetchSchedulesAndBookings();
            }
          },
        )
        .subscribe();
  }

  Future<void> _fetchSchedulesAndBookings() async {
    // We only show the big loader if the array is completely empty to prevent 
    // the UI from flashing aggressively during background real-time updates.
    if (_schedules.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      final scheduleRes = await _doctorRepo.fetchSchedulesByClinic(
        widget.doctor['id'].toString(),
        widget.clinic['id'].toString(),
      );

      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
      
      final slotCounts = await _appointmentRepo.fetchSlotBookingCounts(
        doctorId: widget.doctor['id'].toString(),
        clinicId: widget.clinic['id'].toString(),
        date: formattedDate,
        excludeAppointmentId: widget.appointmentId,
      );

      if (mounted) {
        setState(() {
          _schedules = scheduleRes;
          _slotBookingCounts = slotCounts;
          _isLoading = false;
          
          // If the currently selected slot was just booked by someone else in real-time,
          // we need to unselect it so they don't get an error trying to confirm!
          final slots = _generateSlots();
          if (_selectedTimeSlotIndex != -1 && _selectedTimeSlotIndex < slots.length) {
             if (slots[_selectedTimeSlotIndex]['isFull'] == true) {
                 _selectedTimeSlotIndex = -1; // Unselect the now-stolen slot
             }
          }

          // Initial auto-select logic
          if (widget.timeSlot != null && _selectedTimeSlotIndex == -1) {
            final index = slots.indexWhere((s) => s['time'] == widget.timeSlot);
            if (index != -1 && !slots[index]['isFull']) {
              _selectedTimeSlotIndex = index;
            }
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _generateSlots() {
    if (_schedules.isEmpty) {
      return [];
    }
    
    final dayName = DateFormat('EEEE').format(_selectedDate);
    final daySchedules = _schedules
        .where((s) => s['day_of_week'].toString().toLowerCase() == dayName.toLowerCase())
        .toList();
        
    List<Map<String, dynamic>> allSlots = [];
    final now = DateTime.now();
    final isToday = DateUtils.isSameDay(_selectedDate, now);

    for (var schedule in daySchedules) {
      try {
        TimeOfDay start = _parseTime(schedule['start_time']);
        TimeOfDay end = _parseTime(schedule['end_time']);
        int duration = schedule['slot_duration_minutes'] ?? 30;
        
        int maxCapacity = schedule['max_patients'] ?? 1;

        int startMin = start.hour * 60 + start.minute;
        int endMin = end.hour * 60 + end.minute;

        while (startMin + duration <= endMin) {
          final sTime = _minToTime(startMin);
          final eTime = _minToTime(startMin + duration);
          final slotStr = "$sTime - $eTime";

          int currentBookings = _slotBookingCounts[slotStr] ?? 0;
          int spotsLeft = maxCapacity - currentBookings;
          bool isFull = spotsLeft <= 0;

          bool isPast = false;
          if (isToday) {
            final startHour = startMin ~/ 60;
            final startMinute = startMin % 60;
            if (startHour < now.hour || (startHour == now.hour && startMinute < now.minute)) {
              isPast = true;
            }
          }

          if (!isPast) {
            allSlots.add({
              'time': slotStr,
              'spotsLeft': spotsLeft > 0 ? spotsLeft : 0,
              'isFull': isFull,
            });
          }
          startMin += duration;
        }
      } catch (_) {}
    }
    
    allSlots.sort((a, b) => a['time'].compareTo(b['time']));
    return allSlots;
  }

  Future<void> _handleConfirm() async {
    final slots = _generateSlots();
    final today = DateUtils.dateOnly(DateTime.now());
    
    if (_selectedDate.isBefore(today)) {
      CustomSnackbar.showError(context, "You cannot book a past date.");
      return;
    }
    if (_selectedTimeSlotIndex == -1) {
      CustomSnackbar.showError(context, "Please select a time slot");
      return;
    }

    final selectedSlot = slots[_selectedTimeSlotIndex];
    if (selectedSlot['isFull']) {
      CustomSnackbar.showError(context, "This slot is fully booked.");
      return;
    }

    final userId = _appointmentRepo.currentUserId;
    if (userId == null) {
      CustomSnackbar.showError(context, "Please sign in again to continue.");
      return;
    }

    final times = selectedSlot['time'].split(' - ');
    final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final appointmentDateTime = DateFormat('yyyy-MM-dd HH:mm').parse('$formattedDate ${times[0]}');

    final rawAttachedRecords = widget.patientDetails['attachedRecords'] as List<dynamic>? ?? [];
    final attachedRecordIds = rawAttachedRecords.map((r) => r['id']).toList();

    final data = {
      'user_id': userId,
      'doctor_id': widget.doctor['id'],
      'clinic_id': widget.clinic['id'],
      'schedule_date': formattedDate,
      'start_time': times[0],
      'end_time': times[1],
      'status': 'confirmed',
      'patient_name': widget.patientDetails['name'],
      'patient_phone': widget.patientDetails['phone'],
      'patient_email': widget.patientDetails['email'],
      'patient_gender': widget.patientDetails['gender'],
      'patient_dob': widget.patientDetails['dob'],
      'patient_image_url': widget.patientDetails['imagePath'], 
      'idempotency_key': widget.idempotencyKey,
      'attached_record_ids': attachedRecordIds,
    };

    final timeObj = DateFormat("HH:mm").parse(times[0]);
    final timeStr = DateFormat("hh:mm a").format(timeObj);
    final dateStr = DateFormat("MMMM d").format(_selectedDate);

    context.push(
      AppRoutes.dummyPayment,
      extra: DummyPaymentRouteArgs(
        appointmentData: data,
        appointmentDateTime: appointmentDateTime,
        doctorName: widget.doctor['full_name']?.toString() ?? 'Doctor',
        displayDate: dateStr,
        displayTime: timeStr,
        clinic: widget.clinic,
        appointmentId: widget.appointmentId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slots = _generateSlots();
    final isReschedule = widget.appointmentId != null;

    return VolumetricScaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: CustomAppBar(
        title: isReschedule ? "Reschedule" : "Appointment",
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          MediaQuery.paddingOf(context).top + kToolbarHeight + 20,
          24,
          140 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isReschedule) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center, // PRO FIX: Synced alignment
                          children: [
                            Text(
                              "Step 2/2",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700, // PRO FIX: Synced from w600 to w700
                                color: textDark,
                              ),
                            ),
                            const SizedBox(width: 16), // PRO FIX: Synced from 12px to 16px
                            Expanded(
                              child: Container(
                                height: 6, 
                                decoration: BoxDecoration(
                                  color: primaryGreen.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Builder(
                                  builder: (context) {
                                    // PRO FIX: Slave to the page transition!
                                    final route = ModalRoute.of(context);
                                    final animation = route?.animation ?? const AlwaysStoppedAnimation(1.0);
                                    
                                    return AnimatedBuilder(
                                      animation: animation,
                                      builder: (context, child) {
                                        final curve = Curves.fastOutSlowIn.transform(animation.value);
                                        double factor = 0.5 + (0.5 * curve);
                                        if (factor > 1.0) factor = 1.0;
                                        if (factor < 0.0) factor = 0.0;
                                        return FractionallySizedBox(
                                          alignment: Alignment.centerLeft,
                                          widthFactor: factor, 
                                          child: child,
                                        );
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: primaryGreen,
                                          borderRadius: BorderRadius.circular(4),
                                          boxShadow: [
                                            BoxShadow(
                                              color: primaryGreen.withValues(alpha: 0.3),
                                              blurRadius: 4, 
                                              offset: const Offset(0, 2),
                                            )
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                      ],
                      _buildCalendar(),
                      const SizedBox(height: 24),
                      Text("Available Time", style: _sectionHeaderStyle),
                      const SizedBox(height: 16),
                      if (slots.isEmpty && !_isLoading)
                        Center(
                          child: Text(
                            "No slots available.",
                            style: TextStyle(color: textGrey),
                          ),
                        )
                      else
                        _buildOptionChips(
                          slots,
                          _selectedTimeSlotIndex,
                          (i) {
                            if (!slots[i]['isFull']) {
                              setState(() => _selectedTimeSlotIndex = i);
                            }
                          },
                        ),
                      const SizedBox(height: 40),
                    ],
        ),
      ),
      bottomNavigationBar: AppBottomTray(
        child: PrimaryButton(
          label: widget.appointmentId != null ? "Update Appointment" : "Confirm",
          onTap: _handleConfirm,
          isLoading: _isLoading,
          borderRadius: 16,
          height: 54,
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // 1. Clean, precise Calendar Math (Monday = 1, Sunday = 7)
    final firstDayOffset = DateTime(_focusedDate.year, _focusedDate.month, 1).weekday - 1;
    final daysInMonth = DateUtils.getDaysInMonth(_focusedDate.year, _focusedDate.month);
    final totalCells = firstDayOffset + daysInMonth;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(
          color: isDark
              ? AppColors.darkBorder
              : Colors.black.withValues(alpha: 0.08),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30.5),
        child: Column(
        mainAxisSize: MainAxisSize.min, // THE FIX: Prevents the container from ballooning vertically
        children: [
          // --- MONTH & YEAR HEADER ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: primaryGreen,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(_focusedDate),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Row(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _focusedDate = DateTime(_focusedDate.year, _focusedDate.month - 1)),
                      child: const Icon(Icons.chevron_left, color: Colors.white),
                    ),
                    const SizedBox(width: 24),
                    InkWell(
                      onTap: () => setState(() => _focusedDate = DateTime(_focusedDate.year, _focusedDate.month + 1)),
                      child: const Icon(Icons.chevron_right, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // --- THE FIX: PREMIUM WEEKDAY HEADERS (Removes the illusion of a gap) ---
          Padding(
            padding: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"].map((day) {
                return Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: TextStyle(
                        color: textGrey,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // --- PERFECTLY ALIGNED DATE GRID ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20), // THE FIX: Zero top padding to pull the grid flush
            child: GridView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.0, // Ensures perfect circular hitboxes
              ),
              itemCount: totalCells,
              itemBuilder: (context, index) {
                
                // Render the empty gaps before the 1st of the month
                if (index < firstDayOffset) {
                  return const SizedBox.shrink(); // Safer than an empty SizedBox
                }

                // Render the actual days
                final day = index - firstDayOffset + 1;
                final date = DateTime(_focusedDate.year, _focusedDate.month, day);
                final isSelected = DateUtils.isSameDay(date, _selectedDate);
                final today = DateUtils.dateOnly(DateTime.now());
                final isPastDate = date.isBefore(today);

                // THE FIX: True Context-Aware Dimming
                // Instead of a static grey, we use a hyper-dimmed version of the surface text
                final dimColor = isDark 
                    ? Colors.white.withValues(alpha: 0.15) 
                    : Colors.black.withValues(alpha: 0.15);
                
                final textColor = isPastDate 
                    ? dimColor 
                    : (isSelected ? Colors.white : textDark);

                return InkWell(
                  onTap: isPastDate ? null : () {
                    setState(() => _selectedDate = date);
                    _fetchSchedulesAndBookings();
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer( 
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryGreen : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        "$day",
                        style: TextStyle(
                          color: textColor,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildOptionChips(
    List<Map<String, dynamic>> slots,
    int selectedIndex,
    Function(int) onTap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 96,
      
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          // Removed the deep internal padding so the chips utilize the full width
          padding: const EdgeInsets.only(bottom: 16), 
          itemCount: slots.length,
          itemBuilder: (context, index) {
            final slotData = slots[index];
            final isSelected = selectedIndex == index;
            final isFull = slotData['isFull'] == true;
            final spotsLeft = slotData['spotsLeft'] as int;

            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Opacity(
                opacity: isFull ? 0.5 : 1.0,
                child: GestureDetector(
                  onTap: isFull ? null : () => onTap(index),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.fastOutSlowIn,
                    width: 90,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? primaryGreen
                          : (isDark
                              ? Colors.white10
                              : const Color(0xFFF5F6F8)),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: primaryGreen.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ]
                          : [],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _formatSlotDisplay(slotData['time']),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppTextStyles.body(context).fontFamily,
                            color: isSelected
                                ? Colors.white
                                : (isFull ? textGrey : primaryGreen),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isFull
                              ? "Full"
                              : "$spotsLeft spot${spotsLeft > 1 ? 's' : ''}",
                          style: TextStyle(
                            fontFamily: AppTextStyles.body(context).fontFamily,
                            fontSize: 10,
                            fontWeight:
                                isSelected || isFull
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.9)
                                : (isFull
                                    ? AppColors.dangerRed
                                    : textLight),
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
      
    );
  }



  TimeOfDay _parseTime(String s) {
    final p = s.split(':');
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }

  String _minToTime(int min) =>
      "${(min ~/ 60).toString().padLeft(2, '0')}:${(min % 60).toString().padLeft(2, '0')}";

  String _formatSlotDisplay(String s) {
    try {
      final st = s.split(' - ')[0];
      return DateFormat("hh:mm\na").format(DateFormat("HH:mm").parse(st));
    } catch (_) {
      return s;
    }
  }
}
