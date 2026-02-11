import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AppointmentConfirmationScreen extends StatefulWidget {
  final Map<String, dynamic> doctor;
  final Map<String, dynamic> clinic;
  final Map<String, dynamic> patientDetails;
  final DateTime initialDate;
  final int? appointmentId;

  const AppointmentConfirmationScreen({
    super.key,
    required this.doctor,
    required this.clinic,
    required this.patientDetails,
    required this.initialDate,
    this.appointmentId,
  });

  @override
  State<AppointmentConfirmationScreen> createState() =>
      _AppointmentConfirmationScreenState();
}

class _AppointmentConfirmationScreenState
    extends State<AppointmentConfirmationScreen> {
  // --- DESIGN SYSTEM ---
  static const Color primaryGreen = Color(0xFF00C689);
  static const Color textDark = Color(0xFF1A1A1A);
  static const Color textGrey = Color(0xFF9E9E9E);
  static const Color textLight = Color(0xFF626F8D);
  static const Color lightGreenBg = Color(0xFFE0F7FA); // Now used
  static const Color borderColor = Color(0xFFE0E0E0);

  final TextStyle _sectionHeaderStyle = const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: textDark,
  );

  late DateTime _focusedDate;
  late DateTime _selectedDate;
  List<Map<String, dynamic>> _schedules = [];
  List<String> _bookedSlots = [];
  bool _isLoading = true;

  int _selectedTimeSlotIndex = -1;
  int _selectedReminderIndex = 2;
  final List<int> _reminderOptions = [10, 15, 25, 30, 35, 40];

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
    final client = Supabase.instance.client;

    try {
      final scheduleRes = await client
          .from('doctor_schedules')
          .select()
          .eq('doctor_id', widget.doctor['id'])
          .eq('clinic_id', widget.clinic['id']);

      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final bookingRes = await client
          .from('appointments')
          .select('id, start_time, end_time')
          .eq('doctor_id', widget.doctor['id'])
          .eq('clinic_id', widget.clinic['id'])
          .eq('schedule_date', formattedDate)
          .neq('status', 'cancelled');

      if (mounted) {
        setState(() {
          _schedules = List<Map<String, dynamic>>.from(scheduleRes);

          final filteredBookings = List<Map<String, dynamic>>.from(
            bookingRes,
          ).where((b) {
            // Unblock current slot if rescheduling
            if (widget.appointmentId != null &&
                b['id'] == widget.appointmentId) {
              return false;
            }
            return true;
          });

          _bookedSlots =
              filteredBookings.map((e) {
                final start = _normalizeTime(e['start_time']);
                final end = _normalizeTime(e['end_time']);
                return "$start - $end";
              }).toList();

          _isLoading = false;
          _selectedTimeSlotIndex = -1;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
    if (_selectedTimeSlotIndex == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a time slot")),
      );
      return;
    }

    setState(() => _isLoading = true);
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      return;
    }

    final slotString = slots[_selectedTimeSlotIndex];
    final times = slotString.split(' - ');
    final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);

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
    };

    try {
      if (widget.appointmentId != null) {
        debugPrint("Updating ID: ${widget.appointmentId}");
        await client
            .from('appointments')
            .update(data)
            .eq('id', widget.appointmentId!);
      } else {
        debugPrint("Inserting New");
        await client.from('appointments').insert(data);
      }

      if (mounted) {
        setState(() => _isLoading = false);
        _showSuccessDialog(times[0]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Action failed: $e")));
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessDialog(String startTime24h) {
    final timeObj = DateFormat("HH:mm").parse(startTime24h);
    final timeStr = DateFormat("hh:mm a").format(timeObj);
    final isReschedule = widget.appointmentId != null;

    showDialog(
      context: context,
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
                  const SizedBox(height: 10),
                  Text(
                    "Time: $timeStr",
                    style: const TextStyle(fontSize: 16, color: textLight),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        context.pop();
                        context.pop(true);
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              lightGreenBg, // USED HERE
              Colors.white,
              Color(0xFFE8F5E9),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
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
                                child: const LinearProgressIndicator(
                                  value: 1.0,
                                  backgroundColor: lightGreenBg, // USED HERE
                                  valueColor: AlwaysStoppedAnimation<Color>(
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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
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
            style: _sectionHeaderStyle.copyWith(fontSize: 20),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                return InkWell(
                  onTap: () {
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
                          color: isSelected ? Colors.white : textDark,
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
            child: Material(
              color: isSelected ? primaryGreen : Colors.white,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: () => onTap(index),
                customBorder: const CircleBorder(),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: isSelected ? null : Border.all(color: borderColor),
                  ),
                  child: Center(
                    child: Text(
                      isTime
                          ? _formatSlotDisplay(items[index])
                          : "${items[index]}\nMinit",
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
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _handleConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryGreen,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child:
              _isLoading
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                  : Text(
                    widget.appointmentId != null ? "Update" : "Confirm",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
  String _normalizeTime(dynamic t) {
    if (t == null) {
      return "00:00";
    }
    final p = t.toString().split(':');
    return "${p[0].padLeft(2, '0')}:${p[1].padLeft(2, '0')}";
  }

  String _formatSlotDisplay(String s) {
    try {
      final st = s.split(' - ')[0];
      return DateFormat("hh:mm\na").format(DateFormat("HH:mm").parse(st));
    } catch (_) {
      return s;
    }
  }
}
