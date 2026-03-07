import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_styles.dart';

class DoctorTimingList extends StatelessWidget {
  final List<dynamic> schedules;

  const DoctorTimingList({super.key, required this.schedules});

  @override
  Widget build(BuildContext context) {
    if (schedules.isEmpty) {
      return Text("No schedule info", style: TextStyle(color: Colors.grey));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children:
            schedules.map((s) {
              final day = s['day_of_week']?.toString() ?? 'Day';
              final start = _toAmPm(s['start_time']?.toString() ?? '09:00:00');
              final end = _toAmPm(s['end_time']?.toString() ?? '17:00:00');

              return Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                width: 118,
                // PRO FIX: Dynamic surface pills
                decoration: AppStyles.surfaceCard(context, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      day,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      "$start - $end",
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF8D97A4),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
      ),
    );
  }

  String _toAmPm(String raw) {
    try {
      final input = DateFormat('HH:mm:ss').parse(raw);
      return DateFormat('hh:mm a').format(input);
    } catch (_) {
      try {
        final input = DateFormat('HH:mm').parse(raw);
        return DateFormat('hh:mm a').format(input);
      } catch (_) {
        return raw;
      }
    }
  }
}
