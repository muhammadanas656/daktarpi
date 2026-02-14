import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:intl/intl.dart';

class DoctorAppointmentCard extends StatelessWidget {
  final List<Map<String, dynamic>> clinics;
  final Map<String, dynamic>? selectedClinic;
  final DateTime selectedDate;
  final List<DateTime> datesToShow;
  final List<String> timeSlots;
  final List<String> bookedSlots;
  final String? selectedTimeSlot;
  final ValueChanged<Map<String, dynamic>?> onClinicChanged;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onCustomDateTap;
  final ValueChanged<String>? onTimeSlotSelected;
  final VoidCallback? onMoreClinicTap;

  const DoctorAppointmentCard({
    super.key,
    required this.clinics,
    required this.selectedClinic,
    required this.selectedDate,
    required this.datesToShow,
    required this.timeSlots,
    this.bookedSlots = const [],
    this.selectedTimeSlot,
    required this.onClinicChanged,
    required this.onDateSelected,
    required this.onCustomDateTap,
    this.onTimeSlotSelected,
    this.onMoreClinicTap,
  });

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final bool hasData = clinics.isNotEmpty && selectedClinic != null;
    final clinicName = hasData ? selectedClinic!['name'].toString() : 'No Clinic Available';
    final clinicAddress = hasData ? selectedClinic!['address'].toString() : '';
    final dynamic price = hasData ? selectedClinic!['visit_price'] : 0;
    final waitTime = hasData ? selectedClinic!['avg_wait_time'].toString() : 'N/A';
    final moreClinicCount = clinics.length > 1 ? clinics.length - 1 : 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EDF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: const BoxDecoration(
              color: Color(0xFFCEE3E5),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    "In-Clinic Appointment",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                Text(
                  "${'\u09F3'}${_formatPrice(price)}",
                  style: const TextStyle(
                    color: Color(0xFF2B7A74),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clinicName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        clinicAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF5F9CA8),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (moreClinicCount > 0)
                      GestureDetector(
                        onTap: () {
                          if (onMoreClinicTap != null) {
                            onMoreClinicTap!();
                            return;
                          }
                          if (clinics.isEmpty || selectedClinic == null) {
                            return;
                          }
                          final currentIndex = clinics.indexOf(selectedClinic!);
                          final nextIndex =
                              currentIndex == -1
                                  ? 0
                                  : (currentIndex + 1) % clinics.length;
                          onClinicChanged(clinics[nextIndex]);
                        },
                        child: Text(
                          "$moreClinicCount More clinic",
                          style: const TextStyle(
                            color: Color(0xFF4A8ED9),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  "$waitTime or less wait time",
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final date in datesToShow) _buildDateTab(date),
                    InkWell(
                      onTap: onCustomDateTap,
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.calendar_month_rounded,
                          size: 18,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Divider(height: 1, color: Color(0xFFDFE5EA)),
                const SizedBox(height: 12),
                if (timeSlots.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      "No slots available",
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: timeSlots.map((slot) {
                        final isBooked = bookedSlots.contains(slot);
                        final isSelected = slot == selectedTimeSlot;

                        Color chipColor = const Color(0xFFD7EEF1);
                        Color textColor = const Color(0xFF2B757E);
                        if (isBooked) {
                          chipColor = const Color(0xFFEEF1F4);
                          textColor = const Color(0xFF9CA7B3);
                        } else if (isSelected) {
                          chipColor = AppColors.primaryGreen;
                          textColor = Colors.white;
                        }

                        return GestureDetector(
                          onTap:
                              (!isBooked && onTimeSlotSelected != null)
                                  ? () => onTimeSlotSelected!(slot)
                                  : null,
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: chipColor,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              slot,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 10,
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

  Widget _buildDateTab(DateTime date) {
    final isSelected = _isSameDay(date, selectedDate);
    final now = DateTime.now();
    final isToday = _isSameDay(date, now);
    final isTomorrow = _isSameDay(date, now.add(const Duration(days: 1)));

    String label = DateFormat('EEE').format(date);
    if (isToday) {
      label = "Today";
    } else if (isTomorrow) {
      label = "Tomorrow";
    }

    final String secondLine =
        (isToday || isTomorrow) ? '' : DateFormat('d MMM').format(date);

    return Expanded(
      child: InkWell(
        onTap: () => onDateSelected(date),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.textDark : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 11.5,
                ),
              ),
              if (secondLine.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  secondLine,
                  style: TextStyle(
                    color: isSelected ? AppColors.textDark : Colors.grey[600],
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 7),
              Container(
                height: 2,
                width: 38,
                color: isSelected ? AppColors.textDark : Colors.transparent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPrice(dynamic price) {
    final parsed = num.tryParse(price?.toString() ?? '');
    if (parsed == null) {
      return price?.toString() ?? '0';
    }
    if (parsed == parsed.roundToDouble()) {
      return NumberFormat.decimalPattern().format(parsed.toInt());
    }
    return NumberFormat.decimalPattern().format(parsed);
  }
}
