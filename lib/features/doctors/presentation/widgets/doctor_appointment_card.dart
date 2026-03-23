import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import 'package:intl/intl.dart';
import '../../../profile/presentation/profile_notifier.dart';

class DoctorAppointmentCard extends StatefulWidget {
  final List<Map<String, dynamic>> clinics;
  final Map<String, dynamic>? selectedClinic;
  final DateTime selectedDate;
  final List<DateTime> datesToShow;
  final List<Map<String, dynamic>> timeSlots;
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
    this.selectedTimeSlot,
    required this.onClinicChanged,
    required this.onDateSelected,
    required this.onCustomDateTap,
    this.onTimeSlotSelected,
    this.onMoreClinicTap,
  });

  @override
  State<DoctorAppointmentCard> createState() => _DoctorAppointmentCardState();
}

class _DoctorAppointmentCardState extends State<DoctorAppointmentCard> {
  // PRO FIX: Internal state to handle the "Automatic Closure"
  Timer? _collapseTimer;
  String? _expandedSlotTime;

  @override
  void didUpdateWidget(DoctorAppointmentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // When the parent selects a new slot, expand it and start the timer!
    if (widget.selectedTimeSlot != oldWidget.selectedTimeSlot) {
      if (widget.selectedTimeSlot != null) {
        setState(() {
          _expandedSlotTime = widget.selectedTimeSlot;
        });
        _startCollapseTimer();
      } else {
        // If the slot was cleared (e.g., date changed), cancel everything
        _expandedSlotTime = null;
        _collapseTimer?.cancel();
      }
    }
  }

  void _startCollapseTimer() {
    _collapseTimer?.cancel();
    _collapseTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _expandedSlotTime = null; // Automatically close the text!
        });
      }
    });
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    super.dispose();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark; 
    final bool hasData = widget.clinics.isNotEmpty && widget.selectedClinic != null;
    final clinicName =
        hasData ? widget.selectedClinic!['name'].toString() : 'No Clinic Available';
    final clinicAddress = hasData ? widget.selectedClinic!['address'].toString() : '';
    final dynamic price = hasData ? widget.selectedClinic!['visit_price'] : 0;
    final waitTime =
        hasData ? widget.selectedClinic!['avg_wait_time'].toString() : 'N/A';
    final moreClinicCount = widget.clinics.length > 1 ? widget.clinics.length - 1 : 0;

    return Container(
      width: double.infinity,
      decoration: AppStyles.surfaceCard(context, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkScaffold : const Color(0xFFCEE3E5),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "In-Clinic Appointment",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: context.colorTextDark,
                    ),
                  ),
                ),
                Text(
                  "${ProfileNotifier.instance.currencySymbol} ${_formatPrice(price)}",
                  style: TextStyle(
                    color: Color(0xFF2B7A74),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clinicName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: context.colorTextDark,
                  ),
                ),
                SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        clinicAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF5F9CA8),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (moreClinicCount > 0)
                      GestureDetector(
                        onTap: () {
                          if (widget.onMoreClinicTap != null) {
                            widget.onMoreClinicTap!();
                            return;
                          }
                          if (widget.clinics.isEmpty || widget.selectedClinic == null) {
                            return;
                          }
                          final currentIndex = widget.clinics.indexOf(widget.selectedClinic!);
                          final nextIndex =
                              currentIndex == -1
                                  ? 0
                                  : (currentIndex + 1) % widget.clinics.length;
                          widget.onClinicChanged(widget.clinics[nextIndex]);
                        },
                        child: Text(
                          "$moreClinicCount More clinic",
                          style: TextStyle(
                            color: Color(0xFF4A8ED9),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  "$waitTime or less wait time",
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    for (final date in widget.datesToShow)
                      _buildDateTab(context, date),
                    InkWell(
                      onTap: widget.onCustomDateTap,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
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
                SizedBox(height: 6),
                Divider(height: 1, color: Color(0xFFDFE5EA)),
                SizedBox(height: 12),
                if (widget.timeSlots.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      "No slots available",
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children:
                          widget.timeSlots.map((slotData) {
                            
                            final String slotTime = slotData['time'];
                            final bool isFull = slotData['isFull'];
                            final int spotsLeft = slotData['spotsLeft'];
                            
                            final isSelected = slotTime == widget.selectedTimeSlot;
                            // PRO FIX: Checks if THIS specific pill is the currently expanded one
                            final isExpanded = isSelected && slotTime == _expandedSlotTime;

                            Color chipColor = isDark ? AppColors.darkScaffold : const Color(0xFFD7EEF1);
                            Color textColor = isDark ? AppColors.primaryGreen : const Color(0xFF2B757E);
                            
                            if (isFull) {
                              chipColor = isDark ? AppColors.darkBorder : const Color(0xFFEEF1F4);
                              textColor = isDark ? Colors.grey[600]! : const Color(0xFF9CA7B3);
                            } else if (isSelected) {
                              chipColor = AppColors.primaryGreen;
                              textColor = Colors.white;
                            }

                            return GestureDetector(
                              onTap: (!isFull && widget.onTimeSlotSelected != null)
                                      ? () {
                                          widget.onTimeSlotSelected!(slotTime);
                                          // If they tap the same slot again, force it to re-expand and reset the timer!
                                          if (isSelected) {
                                            setState(() {
                                              _expandedSlotTime = slotTime;
                                            });
                                            _startCollapseTimer();
                                          }
                                        }
                                      : null,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.fastOutSlowIn,
                                margin: EdgeInsets.only(right: 8),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: chipColor,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      slotTime,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    AnimatedSize(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.fastOutSlowIn,
                                      alignment: Alignment.topCenter,
                                      // PRO FIX: Now respects the Timer's isExpanded state!
                                      child: isExpanded && !isFull
                                          ? Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Text(
                                                "Only $spotsLeft spot${spotsLeft > 1 ? 's' : ''} left!",
                                                style: TextStyle(
                                                  color: Colors.white.withValues(alpha: 0.9),
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            )
                                          : const SizedBox.shrink(),
                                    ),
                                  ],
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

  Widget _buildDateTab(BuildContext context, DateTime date) {
    final isSelected = _isSameDay(date, widget.selectedDate);
    final now = DateTime.now();
    final isToday = _isSameDay(date, now);
    final isTomorrow = _isSameDay(date, now.add(Duration(days: 1)));

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
        onTap: () => widget.onDateSelected(date),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? context.colorTextDark : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 11.5,
                ),
              ),
              if (secondLine.isNotEmpty) ...[
                SizedBox(height: 2),
                Text(
                  secondLine,
                  style: TextStyle(
                    color:
                        isSelected ? context.colorTextDark : Colors.grey[600],
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              SizedBox(height: 7),
              Container(
                height: 2,
                width: 38,
                color: isSelected ? context.colorTextDark : Colors.transparent,
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