import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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

  final VoidCallback onReceiptTap;
  final VoidCallback onCalendarTap;
  final VoidCallback onRescheduleTap;
  final VoidCallback onCancelTap;
  final VoidCallback? onLocationTap;

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
    required this.onReceiptTap,
    required this.onCalendarTap,
    required this.onRescheduleTap,
    required this.onCancelTap,
    this.onLocationTap,
  });

  @override
  State<AppointmentCard> createState() => _AppointmentCardState();
}

class _AppointmentCardState extends State<AppointmentCard> {
  bool _isDrawerOpen = false;
  bool _isDrawerPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24), 
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04), 
          width: 1,
        ),
        boxShadow: isDark ? [] : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04), 
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- ZONE A: IDENTITY & BADGE ---
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56, 
                  height: 56,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: isDark ? Colors.white24 : Colors.black12, width: 1),
                  ),
                  child: ClipOval(
                    child: widget.imageUrl.isNotEmpty
                        ? AppNetworkImage(imageUrl: widget.imageUrl, fit: BoxFit.cover)
                        : Icon(Icons.person, color: Colors.grey[400], size: 28),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: isDark ? Colors.white : const Color(0xFF1D1D1F),
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : AppColors.primaryGreen.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.specialty,
                          style: TextStyle(
                            color: AppColors.primaryGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                LiveCountdownBadge(
                  status: widget.status,
                  scheduleDate: widget.scheduleDate,
                  startTime: widget.startTime,
                  maxWaitTime: widget.maxWaitTime,
                ),
              ],
            ),
          ),

          // --- ZONE B: DOSSIER ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF5F5F7), 
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.03)),
              ),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.primaryGreen),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                widget.date,
                                style: GoogleFonts.poppins(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06), margin: const EdgeInsets.symmetric(horizontal: 12)),
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 16, color: AppColors.primaryGreen),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                widget.time,
                                style: GoogleFonts.poppins(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // --- ZONE C: VIEW PASS BUTTON ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: AppColors.primaryGreen.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onReceiptTap,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.primaryGreen.withValues(alpha: 0.85), AppColors.primaryGreen],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          "View Booking Pass",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // --- ZONE D: THE INTELLIGENT CUT-OUT TRAY ---
          const SizedBox(height: 16),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color:
                  _isDrawerPressed
                      ? (isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : AppColors.primaryGreen.withValues(alpha: 0.08))
                      : (_isDrawerOpen
                          ? (isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : AppColors.primaryGreen.withValues(alpha: 0.04))
                          : Colors.transparent),
              border: Border(top: BorderSide(color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.04))),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              children: [
                GestureDetector(
                  onTapDown: (_) {
                    HapticFeedback.selectionClick();
                    setState(() => _isDrawerPressed = true);
                  },
                  onTapUp: (_) {
                    setState(() {
                      _isDrawerPressed = false;
                      _isDrawerOpen = !_isDrawerOpen;
                    });
                  },
                  onTapCancel: () => setState(() => _isDrawerPressed = false),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Manage Appointment",
                          style: GoogleFonts.poppins(
                            color: _isDrawerOpen ? AppColors.primaryGreen : (isDark ? Colors.white54 : const Color(0xFF86868B)),
                            fontSize: 13,
                            fontWeight: _isDrawerOpen ? FontWeight.w600 : FontWeight.w500,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(width: 6),
                        AnimatedRotation(
                          turns: _isDrawerOpen ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: _isDrawerOpen ? AppColors.primaryGreen : (isDark ? Colors.white54 : const Color(0xFF86868B)),
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Horizontal Action Track
                ClipRect(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      height: _isDrawerOpen ? null : 0,
                      width: double.infinity,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              if (widget.onLocationTap != null) ...[
                                _PremiumActionPill(
                                  label: "Location",
                                  icon: Icons.map_rounded,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                  onTap: widget.onLocationTap!,
                                ),
                                const SizedBox(width: 12),
                              ],
                              _PremiumActionPill(
                                label: "Calendar",
                                icon: Icons.calendar_month_rounded,
                                color: isDark ? Colors.white70 : Colors.black87,
                                onTap: widget.onCalendarTap,
                              ),
                              const SizedBox(width: 12),
                              _PremiumActionPill(
                                label: "Reschedule",
                                icon: Icons.edit_calendar_rounded,
                                color: isDark ? Colors.white70 : Colors.black87,
                                onTap: widget.onRescheduleTap,
                              ),
                              const SizedBox(width: 12),
                              _PremiumActionPill(
                                label: "Cancel",
                                icon: Icons.close_rounded,
                                color: widget.canCancel ? AppColors.dangerRed : Colors.grey,
                                // THE FIX: Always pass the tap through! 
                                // The screen logic will decide whether to show the Dialog or the Snackbar.
                                onTap: widget.onCancelTap, 
                                isMuted: !widget.canCancel,
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
          ),
        ],
      ),
    );
  }
}

class _PremiumActionPill extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isMuted;

  const _PremiumActionPill({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isMuted = false,
  });

  @override
  State<_PremiumActionPill> createState() => _PremiumActionPillState();
}

class _PremiumActionPillState extends State<_PremiumActionPill> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseColor =
        widget.isMuted
            ? Colors.transparent
            : (isDark ? Colors.white12 : Colors.white);
    final pressedColor =
        widget.isMuted
            ? Colors.transparent
            : (isDark
                ? Colors.white24
                : Colors.black.withValues(alpha: 0.06));

    return GestureDetector(
      onTapDown: (_) {
        // ▼ DELETE THIS LINE ▼
        // if (widget.isMuted) return; 
        
        HapticFeedback.selectionClick();
        setState(() => _isPressed = true);
      },
      onTapUp: (_) {
        // ▼ DELETE THIS LINE ▼
        // if (widget.isMuted) return; 
        
        setState(() => _isPressed = false);
        widget.onTap(); // Fires the tap!
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _isPressed ? pressedColor : baseColor,
            border: Border.all(
              color:
                  widget.isMuted
                      ? Colors.black12
                      : (isDark ? Colors.white24 : Colors.transparent),
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow:
                (widget.isMuted || isDark || _isPressed)
                    ? []
                    : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 16,
                color: widget.isMuted ? Colors.grey : widget.color,
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: widget.isMuted ? Colors.grey : widget.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
