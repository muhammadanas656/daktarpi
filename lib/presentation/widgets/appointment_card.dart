import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../features/appointments/presentation/widgets/live_countdown_badge.dart';
import 'app_network_image.dart';

class AppointmentCard extends StatefulWidget {
  final String bookingId;
  final String name;
  final String specialty;
  final String date;
  final String time;
  final String imageUrl;
  final String status;
  final String scheduleDate;
  final String startTime;
  final int maxWaitTime;
  final bool canCancel;
  final bool canComplete; // 📌 PRO FIX: Added missing logic barrier
  
  final VoidCallback onReceiptTap;
  final VoidCallback onCalendarTap;
  final VoidCallback onRescheduleTap;
  final VoidCallback onCancelTap;
  final VoidCallback onCompleteTap;

  const AppointmentCard({
    super.key,
    required this.bookingId,
    required this.name,
    required this.specialty,
    required this.date,
    required this.time,
    required this.imageUrl,
    required this.status,
    required this.scheduleDate,
    required this.startTime,
    this.maxWaitTime = 30,
    required this.canCancel,
    required this.canComplete, // 📌 PRO FIX
    required this.onReceiptTap,
    required this.onCalendarTap,
    required this.onRescheduleTap,
    required this.onCancelTap,
    required this.onCompleteTap,
  });

  @override
  State<AppointmentCard> createState() => _AppointmentCardState();
}

class _AppointmentCardState extends State<AppointmentCard> {
  bool _isDrawerOpen = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppColors.darkBorder : Colors.transparent),
        boxShadow: isDark ? [] : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 30,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- TOP: DOCTOR & STATUS ---
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.2), width: 2),
                  ),
                  child: ClipOval(
                    child: widget.imageUrl.isNotEmpty
                        ? AppNetworkImage(imageUrl: widget.imageUrl, fit: BoxFit.cover)
                        : Icon(Icons.person, color: Colors.grey[400], size: 30),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.name, style: AppTextStyles.h3(context).copyWith(fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(widget.specialty, style: TextStyle(color: context.colorTextLight, fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 12),
                      LiveCountdownBadge(
                        status: widget.status,
                        scheduleDate: widget.scheduleDate,
                        startTime: widget.startTime,
                        maxWaitTime: widget.maxWaitTime,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- MIDDLE: TIME DOSSIER ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(child: _buildTimeItem(context, Icons.calendar_today_rounded, widget.date)),
                  Container(width: 1, height: 24, color: context.colorBorder),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTimeItem(context, Icons.access_time_rounded, widget.time)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- BOTTOM: PRIMARY ACTION ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: InkWell(
              onTap: widget.onReceiptTap,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    const Text("View Booking Pass", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                  ],
                ),
              ),
            ),
          ),

          // --- DRAWER TOGGLE ---
          // 📌 PRO FIX: The InkWell now wraps the entire bottom area and has padding, making the tap target huge!
          InkWell(
            onTap: () => setState(() => _isDrawerOpen = !_isDrawerOpen),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Manage Appointment", style: TextStyle(color: context.colorTextLight, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _isDrawerOpen ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(Icons.keyboard_arrow_down_rounded, color: context.colorTextLight, size: 18),
                  )
                ],
              ),
            ),
          ),

          // --- ACCORDION DRAWER ---
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: _isDrawerOpen ? null : 0,
                width: double.infinity,
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: context.colorBorder)),
                      color: isDark ? Colors.black12 : Colors.grey[50],
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12, runSpacing: 12,
                          children: [
                            _buildActionPill(context, "Add to Calendar", Icons.calendar_month_rounded, Colors.orange, widget.onCalendarTap),
                            _buildActionPill(context, "Reschedule", Icons.edit_calendar_rounded, Colors.blue, widget.onRescheduleTap),
                            
                            // 📌 PRO FIX: "Mark Complete" ONLY shows if the time-check logic allows it!
                            if (widget.canComplete)
                               _buildActionPill(context, "Mark Complete", Icons.check_circle_rounded, Colors.teal, widget.onCompleteTap),
                               
                            _buildActionPill(
                              context, "Cancel", Icons.close_rounded, 
                              widget.canCancel ? AppColors.dangerRed : Colors.grey, 
                              widget.canCancel ? widget.onCancelTap : () {}, 
                              isMuted: !widget.canCancel,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeItem(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: context.colorTextLight),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: context.colorTextDark, fontWeight: FontWeight.w700, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildActionPill(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap, {bool isMuted = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMuted ? Colors.transparent : color.withValues(alpha: isDark ? 0.15 : 0.1),
          border: Border.all(color: isMuted ? context.colorBorder : color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isMuted ? Colors.grey : color),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isMuted ? Colors.grey : color)),
          ],
        ),
      ),
    );
  }
}