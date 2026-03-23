import 'package:flutter/material.dart';
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

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppStyles.pageGradient(context)),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(isReschedule),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isReschedule) ...[
                        Row(
                          children: [
                            Text(
                              "Step 2/2",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: textDark,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: 1.0,
                                  backgroundColor: primaryGreen.withValues(alpha: 0.1),
                                  valueColor: AlwaysStoppedAnimation<Color>(primaryGreen),
                                  minHeight: 6,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
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
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomButton(),
    );
  }

  Widget _buildAppBar(bool isReschedule) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () => context.pop(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 44,
              height: 44,
              decoration: AppStyles.surfaceCard(context, borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.arrow_back_ios_new, size: 18, color: textDark),
            ),
          ),
          Text(
            isReschedule ? "Reschedule" : "Appointment",
            style: AppTextStyles.h3(context).copyWith(fontSize: 20),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      decoration: AppStyles.surfaceCard(context, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryGreen,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                    const SizedBox(width: 16),
                    InkWell(
                      onTap: () => setState(() => _focusedDate = DateTime(_focusedDate.year, _focusedDate.month + 1)),
                      child: const Icon(Icons.chevron_right, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: DateUtils.getDaysInMonth(_focusedDate.year, _focusedDate.month) +
                  DateTime(_focusedDate.year, _focusedDate.month, 1).weekday - 1,
              itemBuilder: (context, index) {
                if (index < DateTime(_focusedDate.year, _focusedDate.month, 1).weekday - 1) {
                  return const SizedBox();
                }

                final day = index - (DateTime(_focusedDate.year, _focusedDate.month, 1).weekday - 1) + 1;
                final date = DateTime(_focusedDate.year, _focusedDate.month, day);
                final isSelected = DateUtils.isSameDay(date, _selectedDate);
                final today = DateUtils.dateOnly(DateTime.now());
                final isPastDate = date.isBefore(today);

                return InkWell(
                  onTap: isPastDate ? null : () {
                    setState(() => _selectedDate = date);
                    _fetchSchedulesAndBookings();
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? primaryGreen : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        "$day",
                        style: TextStyle(
                          color: isPastDate ? Colors.grey[300] : (isSelected ? Colors.white : textDark),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
    );
  }

  Widget _buildOptionChips(
    List<Map<String, dynamic>> slots,
    int selectedIndex,
    Function(int) onTap,
  ) {
    return SingleChildScrollView(
      clipBehavior: Clip.none, 
      padding: const EdgeInsets.only(bottom: 15), 
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(slots.length, (index) {
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
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 90, 
                  height: 80,
                  decoration: BoxDecoration(
                    color: isSelected ? primaryGreen : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: isSelected ? null : Border.all(color: borderColor),
                    boxShadow: isSelected
                        ? AppStyles.primaryShadow(context, primaryGreen)
                        : (isFull ? null : AppStyles.cardShadow(context)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _formatSlotDisplay(slotData['time']),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected ? Colors.white : (isFull ? textGrey : primaryGreen),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isFull ? "Full" : "$spotsLeft spot${spotsLeft > 1 ? 's' : ''}",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected || isFull ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected 
                              ? Colors.white.withValues(alpha: 0.9) 
                              : (isFull ? AppColors.dangerRed : textLight),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkBorder : const Color(0xFFF0F0F0))),
      ),
      child: SafeArea(
        top: false,
        child: PrimaryButton(
          label: widget.appointmentId != null ? "Update Appointment" : "Confirm",
          onTap: _handleConfirm,
          isLoading: _isLoading,
          height: 54,
          borderRadius: 16,
        ),
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