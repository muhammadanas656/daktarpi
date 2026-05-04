import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../presentation/widgets/complaint_dialog.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../presentation/widgets/review_dialog.dart';
import '../../../../core/network/network_notifier.dart';
import '../../../../features/appointments/presentation/appointment_notifier.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/custom_app_bar.dart';

class AccountActivityScreen extends StatefulWidget {
  const AccountActivityScreen({super.key});

  @override
  State<AccountActivityScreen> createState() => _AccountActivityScreenState();
}

class _AccountActivityScreenState extends State<AccountActivityScreen> with SingleTickerProviderStateMixin {
  final _appointmentNotifier = AppointmentNotifier.instance;
  late final AnimationController _skeletonController;

  @override
  void initState() {
    super.initState();
    _skeletonController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    _appointmentNotifier.addListener(_onNotifierChanged);
    NetworkNotifier.instance.addListener(_onNetworkChanged);

    if (_appointmentNotifier.activityLog.isEmpty) {
      _appointmentNotifier.fetchAppointments(isBackground: true);
    }
  }

  @override
  void dispose() {
    _skeletonController.dispose();
    _appointmentNotifier.removeListener(_onNotifierChanged);
    NetworkNotifier.instance.removeListener(_onNetworkChanged);
    super.dispose();
  }

  void _onNotifierChanged() {
    if (mounted) setState(() {});
  }

  void _onNetworkChanged() {
    if (mounted) {
      setState(() {});
      if (!NetworkNotifier.instance.isOffline) {
        _appointmentNotifier.fetchAppointments(isBackground: true);
      }
    }
  }

  Color _getActionColor(String action) {
    switch (action.toLowerCase()) {
      case 'booked': return Colors.blue;
      case 'rescheduled': return Colors.orange;
      case 'completed': return AppColors.primaryGreen;
      case 'canceled': return Colors.red;
      case 'missed': return Colors.deepOrange;
      case 'waiting': return Colors.amber;
      default: return Colors.grey;
    }
  }

  IconData _getActionIcon(String action) {
    switch (action.toLowerCase()) {
      case 'booked': return Icons.event_available_rounded;
      case 'rescheduled': return Icons.edit_calendar_rounded;
      case 'completed': return Icons.check_circle_rounded;
      case 'canceled': return Icons.cancel_rounded;
      case 'missed': return Icons.report_problem_rounded;
      case 'waiting': return Icons.hourglass_bottom_rounded;
      default: return Icons.history_rounded;
    }
  }

  void _showReviewDialog(BuildContext context, Map<String, dynamic> appointment) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ReviewDialog(
        appointment: appointment,
        onReviewSubmitted: () {
          if (mounted) setState(() => appointment['has_review'] = true);
        },
      ),
    );
  }

  void _showComplaintDialog(BuildContext context, Map<String, dynamic> appointment) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ComplaintDialog(appointment: appointment, onComplaintSubmitted: () {}),
    );
  }

  // 📌 PRO FIX: Skeleton Loader adapted for the Timeline layout!
  Widget _buildSkeletonLoader(bool isDark) {
    final baseColor = isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05);
    
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 20, 24, 40),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return AnimatedBuilder(
              animation: _skeletonController,
              builder: (context, child) {
                return Opacity(
                  opacity: 0.5 + (_skeletonController.value * 0.5),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 48,
                          child: Stack(
                            alignment: Alignment.topCenter,
                            children: [
                              Container(width: 2, color: baseColor),
                              Positioned(top: 12, child: Container(width: 24, height: 24, decoration: BoxDecoration(color: baseColor, shape: BoxShape.circle))),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: Container(
                              height: 120,
                              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white12 : Colors.transparent)),
                              padding: const EdgeInsets.all(16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          childCount: 4,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activities = _appointmentNotifier.activityLog;
    final isLoading = _appointmentNotifier.isLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const CustomAppBar(title: "Past Records"),
      body: RefreshIndicator(
        color: AppColors.primaryGreen,
        displacement: kToolbarHeight + 20,
        onRefresh: () => _appointmentNotifier.fetchAppointments(isBackground: true),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          clipBehavior: Clip.none,
          slivers: [
            SliverPadding(
              padding: EdgeInsets.only(
                top: MediaQuery.paddingOf(context).top + kToolbarHeight,
              ),
            ),

            if (NetworkNotifier.instance.isOffline)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: _buildOfflineWarningBanner(),
                ),
              ),

            // --- 📌 PRO FIX: Seamless Loading States ---
            if (isLoading && activities.isEmpty)
              _buildSkeletonLoader(isDark)
            else if (activities.isEmpty)
              SliverFillRemaining(child: _buildPremiumEmptyState(isDark))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 24, 40),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = activities[index];
                      // 📌 PRO FIX: Cascading Waterfall Animation
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: Duration(milliseconds: 400 + (index * 50).clamp(0, 500)), 
                        curve: Curves.easeOutQuart,
                        builder: (context, value, child) {
                          return Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: Opacity(opacity: value, child: child),
                          );
                        },
                        child: _buildTimelineCard(item, isDark, index, activities.length),
                      );
                    },
                    childCount: activities.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 📌 PRO FIX: The Liquid Timeline Architecture
  Widget _buildTimelineCard(Map<String, dynamic> item, bool isDark, int index, int totalCount) {
    final action = item['action_type']?.toString().toUpperCase() ?? 'UNKNOWN';
    final dateStr = item['archived_at'];
    final doctorName = item['doctors']?['full_name'] ?? 'Doctor';
    final actionColor = _getActionColor(action);
    
    DateTime? date;
    if (dateStr != null) date = DateTime.tryParse(dateStr)?.toLocal();

    final isFirst = index == 0;
    final isLast = index == totalCount - 1;

    // IntrinsicHeight safely allows the timeline line to match the exact dynamic height of the card
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- 1. THE TIMELINE AXIS ---
          SizedBox(
            width: 54,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // The continuous line
                Positioned(
                  top: isFirst ? 24 : 0,
                  bottom: isLast ? null : 0,
                  height: isLast ? 24 : null,
                  width: 2,
                  child: Container(
                    color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
                // The Glowing Node
                Positioned(
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: actionColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 4), // Cutout effect
                      boxShadow: [
                        BoxShadow(color: actionColor.withValues(alpha: 0.25), blurRadius: 12, spreadRadius: 1) // Ambient glow
                      ],
                    ),
                    child: Icon(_getActionIcon(action), color: actionColor, size: 16),
                  ),
                ),
              ],
            ),
          ),

          // --- 2. THE CARD ---
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.transparent),
                  boxShadow: isDark ? [] : [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 8))
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action,
                      style: TextStyle(color: actionColor, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Appointment with $doctorName",
                      style: TextStyle(color: context.colorTextDark, fontWeight: FontWeight.w800, fontSize: 16, height: 1.2, letterSpacing: -0.2),
                    ),
                    const SizedBox(height: 8),
                    if (date != null)
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 14, color: context.colorTextLight),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat("MMM d, yyyy  •  h:mm a").format(date),
                            style: TextStyle(color: context.colorTextLight, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),

                    // --- 3. PREMIUM ACTION PILLS ---
                    if (action == 'COMPLETED') ...[
                      const SizedBox(height: 20),
                      if (item['has_review'] == true)
                        _buildStatusBadge("Review Submitted", Icons.verified_rounded, Colors.grey)
                      else
                        _buildSoftTintButton("Leave a Review", Icons.star_rounded, Colors.amber[700]!, () => _showReviewDialog(context, item)),
                    ],

                    if (action == 'MISSED') ...[
                      const SizedBox(height: 20),
                      if (item['has_complaint'] == true)
                        _buildStatusBadge("Complaint Submitted", Icons.verified_rounded, Colors.grey)
                      else
                        _buildSoftTintButton("File Complaint", Icons.report_problem_rounded, Colors.deepOrange, () => _showComplaintDialog(context, item)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // 📌 PRO FIX: Premium Squishy Buttons for Actions
  Widget _buildSoftTintButton(String text, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(text, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: AppColors.primaryGreen.withValues(alpha: 0.05), shape: BoxShape.circle),
            child: Icon(Icons.history_rounded, size: 64, color: AppColors.primaryGreen.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 24),
          Text("No Activity Yet", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.colorTextDark, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          Text("Your booking history will appear here.", textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: context.colorTextLight, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildOfflineWarningBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.orange, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "You are currently offline. Live wait times and statuses will update when you reconnect.",
              style: TextStyle(color: Colors.orange[800], fontSize: 13, fontWeight: FontWeight.w600, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
