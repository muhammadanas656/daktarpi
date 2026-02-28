import 'package:flutter/material.dart';
import '../../../../core/constants/app_routes.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/services/appointment_notification_service.dart';
import '../../../settings/presentation/settings_notifier.dart';
import '../../../doctors/data/doctor_repository.dart';
import '../../data/appointment_repository.dart';
// Added ProfileRepository
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
  // --- DESIGN SYSTEM ---
  static const Color primaryGreen = AppColors.primaryGreen;
  static const Color textDark = AppColors.textDark;
  static const Color textGrey = AppColors.textGrey;
  static const Color textLight = AppColors.textLight;
  static const Color borderColor = AppColors.borderColor;

  final _doctorRepo = DoctorRepository();
  final _appointmentRepo = AppointmentRepository();
  // Initialized Profile Repo
  final _notificationService = AppointmentNotificationService.instance;

  final TextStyle _sectionHeaderStyle = AppTextStyles.h3;

  late DateTime _focusedDate;
  late DateTime _selectedDate;
  List<Map<String, dynamic>> _schedules = [];
  List<String> _bookedSlots = [];
  bool _isLoading = true;

  int _selectedTimeSlotIndex = -1;
  int _selectedReminderIndex = 1;
  final List<int> _reminderOptions = [0, 15, 30, 60, 1440]; // 0 = No reminder

  @override
  void initState() {
    super.initState();
    _focusedDate = widget.initialDate;
    _selectedDate = widget.initialDate;
    if (widget.appointmentId != null) {
      debugPrint("Mode: RESCHEDULE ID ${widget.appointmentId}");
    } else {
      debugPrint("Mode: NEW BOOKING");
    }
    _fetchSchedulesAndBookings();
  }

  Future<void> _fetchSchedulesAndBookings() async {
    setState(() => _isLoading = true);

    try {
      final scheduleRes = await _doctorRepo.fetchSchedulesByClinic(
        widget.doctor['id'].toString(),
        widget.clinic['id'].toString(),
      );

      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final bookedSlots = await _appointmentRepo.fetchBookedSlots(
        doctorId: widget.doctor['id'].toString(),
        clinicId: widget.clinic['id'].toString(),
        date: formattedDate,
        excludeAppointmentId: widget.appointmentId,
      );

      if (mounted) {
        setState(() {
          _schedules = scheduleRes;
          _bookedSlots = bookedSlots;
          _isLoading = false;
          _selectedTimeSlotIndex = -1;
        });

        // Auto-select slot if passed and available
        if (widget.timeSlot != null) {
          final slots = _generateSlots();
          final index = slots.indexOf(widget.timeSlot!);
          if (index != -1) {
            setState(() {
              _selectedTimeSlotIndex = index;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> _generateSlots() {
    if (_schedules.isEmpty) {
      return [];
    }
    final dayName = DateFormat('EEEE').format(_selectedDate);
    final daySchedules =
        _schedules
            .where(
              (s) =>
                  s['day_of_week'].toString().toLowerCase() ==
                  dayName.toLowerCase(),
            )
            .toList();
    List<String> allSlots = [];
    final now = DateTime.now();
    final isToday = DateUtils.isSameDay(_selectedDate, now);

    for (var schedule in daySchedules) {
      try {
        TimeOfDay start = _parseTime(schedule['start_time']);
        TimeOfDay end = _parseTime(schedule['end_time']);
        int duration = schedule['slot_duration_minutes'] ?? 30;

        int startMin = start.hour * 60 + start.minute;
        int endMin = end.hour * 60 + end.minute;

        while (startMin + duration <= endMin) {
          final sTime = _minToTime(startMin);
          final eTime = _minToTime(startMin + duration);
          final slotStr = "$sTime - $eTime";

          bool isBooked = _bookedSlots.contains(slotStr);
          bool isPast = false;
          if (isToday) {
            if ((startMin / 60) < now.hour ||
                ((startMin / 60) == now.hour && (startMin % 60) < now.minute)) {
              isPast = true;
            }
          }

          if (!isBooked && !isPast) {
            allSlots.add(slotStr);
          }
          startMin += duration;
        }
      } catch (_) {}
    }
    allSlots.sort();
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

    setState(() => _isLoading = true);
    final userId = _appointmentRepo.currentUserId;
    if (userId == null) {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomSnackbar.showError(context, "Please sign in again to continue.");
      }
      return;
    }

    final slotString = slots[_selectedTimeSlotIndex];
    final times = slotString.split(' - ');
    final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final appointmentDateTime = DateFormat(
      'yyyy-MM-dd HH:mm',
    ).parse('$formattedDate ${times[0]}');

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
      'reminder_minutes': _reminderOptions[_selectedReminderIndex],
      'idempotency_key': widget.idempotencyKey,
    };

    try {
      int persistedAppointmentId;
      if (widget.appointmentId != null) {
        await _appointmentRepo.updateAppointment(widget.appointmentId!, data);
        persistedAppointmentId = widget.appointmentId!;
      } else {
        persistedAppointmentId = await _appointmentRepo.createAppointment(data);
      }

      bool reminderFailed = false;
      try {
        final selectedMins = _reminderOptions[_selectedReminderIndex];

        // --- SCHEDULE NOTIFICATION LOGIC ---
        // Only schedule if global settings are ON and they didn't choose 0 (No Reminder)
        if (SettingsNotifier.instance.notificationsEnabled &&
            selectedMins > 0) {
          await _notificationService.scheduleReminder(
            appointmentId: persistedAppointmentId,
            appointmentLocalDateTime: appointmentDateTime,
            reminderMinutes: selectedMins,
            doctorName: widget.doctor['full_name']?.toString() ?? 'your doctor',
          );
        } else {
          // If global notifications are OFF or they chose 0, cancel any existing alarms for this ID
          await _notificationService.cancelReminder(persistedAppointmentId);
        }
      } catch (error) {
        debugPrint('Reminder scheduling failed for appointment: $error');
        reminderFailed = true;
      }

      if (mounted) {
        setState(() => _isLoading = false);
        if (reminderFailed) {
          CustomSnackbar.showInfo(
            context,
            "Appointment confirmed. Reminder could not be scheduled.",
          );
        }
        _showSuccessDialog(times[0]);
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, "Action failed: $e");
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessDialog(String startTime24h) {
    final timeObj = DateFormat("HH:mm").parse(startTime24h);
    final timeStr = DateFormat("hh:mm a").format(timeObj);
    final dateStr = DateFormat("MMMM d").format(_selectedDate);
    final doctorName = widget.doctor['full_name'] ?? "Doctor";
    final isReschedule = widget.appointmentId != null;

    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      color: primaryGreen.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.check_rounded,
                        color: primaryGreen,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isReschedule ? "Rescheduled!" : "Thank You!",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isReschedule
                        ? "Appointment Updated Successfully"
                        : "Your Appointment Successful",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: textLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "You have booked with $doctorName on $dateStr, at $timeStr",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: textGrey,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        // Redirect logic remains the same
                        context.go(
                          AppRoutes.appointments,
                          extra: const AppointmentsRouteArgs(refresh: true),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        "Done",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slots = _generateSlots();
    final isReschedule = widget.appointmentId != null;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppStyles.pageGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(isReschedule),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isReschedule) ...[
                        Row(
                          children: [
                            const Text(
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
                                  backgroundColor: primaryGreen.withValues(
                                    alpha: 0.1,
                                  ),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        primaryGreen,
                                      ),
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
                        const Center(
                          child: Text(
                            "No slots available.",
                            style: TextStyle(color: textGrey),
                          ),
                        )
                      else
                        _buildOptionChips(
                          slots,
                          _selectedTimeSlotIndex,
                          (i) => setState(() => _selectedTimeSlotIndex = i),
                          true,
                        ),
                      const SizedBox(height: 24),
                      Text("Reminder Me Before", style: _sectionHeaderStyle),
                      const SizedBox(height: 16),
                      _buildOptionChips(
                        _reminderOptions.map((e) => "$e").toList(),
                        _selectedReminderIndex,
                        (i) => setState(() => _selectedReminderIndex = i),
                        false,
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
      bottomSheet: _buildBottomButton(),
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
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderColor),
                boxShadow: AppStyles.cardShadow,
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                size: 18,
                color: textDark,
              ),
            ),
          ),
          Text(
            isReschedule ? "Reschedule" : "Appointment",
            style: AppTextStyles.h3.copyWith(fontSize: 20),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: primaryGreen,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                      onTap:
                          () => setState(
                            () =>
                                _focusedDate = DateTime(
                                  _focusedDate.year,
                                  _focusedDate.month - 1,
                                ),
                          ),
                      child: const Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    InkWell(
                      onTap:
                          () => setState(
                            () =>
                                _focusedDate = DateTime(
                                  _focusedDate.year,
                                  _focusedDate.month + 1,
                                ),
                          ),
                      child: const Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                      ),
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
              itemCount:
                  DateUtils.getDaysInMonth(
                    _focusedDate.year,
                    _focusedDate.month,
                  ) +
                  DateTime(_focusedDate.year, _focusedDate.month, 1).weekday -
                  1,
              itemBuilder: (context, index) {
                if (index <
                    DateTime(_focusedDate.year, _focusedDate.month, 1).weekday -
                        1) {
                  return const SizedBox();
                }

                final day =
                    index -
                    (DateTime(
                          _focusedDate.year,
                          _focusedDate.month,
                          1,
                        ).weekday -
                        1) +
                    1;

                final date = DateTime(
                  _focusedDate.year,
                  _focusedDate.month,
                  day,
                );

                final isSelected = DateUtils.isSameDay(date, _selectedDate);

                // --- NEW: Check if the date has passed ---
                final today = DateUtils.dateOnly(DateTime.now());
                final isPastDate = date.isBefore(today);

                return InkWell(
                  // --- NEW: Disable tapping for past dates ---
                  onTap:
                      isPastDate
                          ? null
                          : () {
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
                          // --- NEW: Grey out the text if it's a past date ---
                          color:
                              isPastDate
                                  ? Colors.grey[300]
                                  : (isSelected ? Colors.white : textDark),
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
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
    List<String> items,
    int selectedIndex,
    Function(int) onTap,
    bool isTime,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(items.length, (index) {
          final isSelected = selectedIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => onTap(index),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: isSelected ? primaryGreen : Colors.white,
                  shape: BoxShape.circle,
                  border: isSelected ? null : Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color:
                          isSelected
                              ? primaryGreen.withValues(alpha: 0.4)
                              : Colors.black.withValues(alpha: 0.03),
                      blurRadius: isSelected ? 8 : 5,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    isTime
                        ? _formatSlotDisplay(items[index])
                        : _formatReminderDisplay(items[index]),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? Colors.white : primaryGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
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
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: SafeArea(
        top: false,
        child: PrimaryButton(
          label:
              widget.appointmentId != null ? "Update Appointment" : "Confirm",
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

  String _formatReminderDisplay(String minutesRaw) {
    final minutes = int.tryParse(minutesRaw);
    if (minutes == null) return "$minutesRaw\nMin";
    if (minutes == 0) return "No\nAlarm";
    if (minutes == 60) return "1\nHour";
    if (minutes == 1440) return "24\nHours";
    return "$minutes\nMin";
  }
}
