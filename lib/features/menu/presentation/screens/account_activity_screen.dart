import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../presentation/widgets/complaint_dialog.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../presentation/widgets/review_dialog.dart';
import '../../../../core/network/network_notifier.dart';
import '../../../../features/appointments/presentation/appointment_notifier.dart';
import '../../../../core/widgets/app_loader.dart';

class AccountActivityScreen extends StatefulWidget {
  const AccountActivityScreen({super.key});

  @override
  State<AccountActivityScreen> createState() => _AccountActivityScreenState();
}

class _AccountActivityScreenState extends State<AccountActivityScreen> {
  final _appointmentNotifier = AppointmentNotifier.instance;

  @override
  void initState() {
    super.initState();
    _appointmentNotifier.addListener(_onNotifierChanged);
    NetworkNotifier.instance.addListener(_onNetworkChanged);

    if (_appointmentNotifier.activityLog.isEmpty) {
      _appointmentNotifier.fetchAppointments(isBackground: true);
    }
  }

  @override
  void dispose() {
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
      case 'booked':
        return Colors.blue;
      case 'rescheduled':
        return Colors.orange;
      case 'completed':
        return AppColors.primaryGreen;
      case 'canceled':
        return Colors.red;
      case 'missed':
        return Colors.deepOrange;
      case 'waiting':
        return Colors.amber;
      default:
        return context.colorTextLight;
    }
  }

  IconData _getActionIcon(String action) {
    switch (action.toLowerCase()) {
      case 'booked':
        return Icons.event_available_rounded;
      case 'rescheduled':
        return Icons.edit_calendar_rounded;
      case 'completed':
        return Icons.check_circle_outline_rounded;
      case 'canceled':
        return Icons.cancel_outlined;
      case 'missed':
        return Icons.report_problem_outlined;
      case 'waiting':
        return Icons.hourglass_bottom_rounded;
      default:
        return Icons.history_rounded;
    }
  }

  void _showReviewDialog(BuildContext context, Map<String, dynamic> appointment) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ReviewDialog(
        appointment: appointment,
        onReviewSubmitted: () {
          if (mounted) {
            setState(() {
              appointment['has_review'] = true;
            });
          }
        },
      ),
    );
  }

  void _showComplaintDialog(BuildContext context, Map<String, dynamic> appointment) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ComplaintDialog(
        appointment: appointment,
        onComplaintSubmitted: () {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activities = _appointmentNotifier.activityLog;
    final isLoading = _appointmentNotifier.isLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        color: AppColors.primaryGreen,
        displacement: kToolbarHeight + 20, // Clears the frosted app bar beautifully
        onRefresh: () => _appointmentNotifier.fetchAppointments(isBackground: true),
        child: CustomScrollView(
          clipBehavior: Clip.none, // Prevents shadows from clipping
          slivers: [
            // --- 📌 1. The Frosted Glass App Bar ---
            SliverAppBar(
              pinned: true,
              elevation: 0,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.85),
              surfaceTintColor: Colors.transparent,
              flexibleSpace: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(color: Colors.transparent),
                ),
              ),
              leadingWidth: 64,
              leading: Center(
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.arrow_back_ios_new_rounded, color: context.colorTextDark, size: 18),
                  ),
                ),
              ),
              centerTitle: true,
              title: Text(
                "Account Activity",
                style: AppTextStyles.h3(context).copyWith(
                  fontSize: 18,
                  letterSpacing: 0.3,
                ),
              ),
            ),

            // --- 📌 2. The Offline Banner (Native Sliver) ---
            if (NetworkNotifier.instance.isOffline)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: _buildOfflineWarningBanner(),
                ),
              ),

            // --- 📌 3. Main Content ---
            if (isLoading && activities.isEmpty)
              const SliverFillRemaining(
                child: Center(child: AppLoader(color: AppColors.primaryGreen)),
              )
            else if (activities.isEmpty)
              SliverFillRemaining(
                child: _buildPremiumEmptyState(isDark),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = activities[index];
                      return _buildActivityCard(item, isDark);
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

  Widget _buildActivityCard(Map<String, dynamic> item, bool isDark) {
    final action = item['action_type']?.toString().toUpperCase() ?? 'UNKNOWN';
    final dateStr = item['archived_at'];
    final doctorName = item['doctors']?['full_name'] ?? 'Doctor';
    final actionColor = _getActionColor(action);

    DateTime? date;
    if (dateStr != null) {
      date = DateTime.tryParse(dateStr)?.toLocal();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Colored Icon Container
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: actionColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(_getActionIcon(action), color: actionColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action,
                    style: TextStyle(
                      color: actionColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Appointment with $doctorName",
                    style: TextStyle(
                      color: context.colorTextDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      height: 1.2,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (date != null)
                    Text(
                      DateFormat("MMM d, yyyy  •  h:mm a").format(date),
                      style: TextStyle(
                        color: context.colorTextLight,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                  // --- PRO FIX: Soft-Tint Interaction Buttons ---
                  if (action == 'COMPLETED') ...[
                    const SizedBox(height: 16),
                    if (item['has_review'] == true)
                      _buildStatusBadge("Review Submitted", Icons.check_circle_outline_rounded, Colors.grey)
                    else
                      _buildSoftTintButton(
                        "Leave a Review", 
                        Icons.star_rate_rounded, 
                        AppColors.primaryGreen, 
                        () => _showReviewDialog(context, item),
                      ),
                  ],

                  if (action == 'MISSED') ...[
                    const SizedBox(height: 16),
                    if (item['has_complaint'] == true)
                      _buildStatusBadge("Complaint Submitted", Icons.check_circle_outline_rounded, Colors.grey)
                    else
                      _buildSoftTintButton(
                        "File Complaint", 
                        Icons.report_problem_outlined, 
                        Colors.deepOrange, 
                        () => _showComplaintDialog(context, item),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper for the Submitted state
  Widget _buildStatusBadge(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Helper for the Actionable state
  Widget _buildSoftTintButton(String text, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: color.withValues(alpha: 0.2),
        highlightColor: color.withValues(alpha: 0.15),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: color,
                ),
              ),
            ],
          ),
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
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.history_rounded, size: 64, color: AppColors.primaryGreen.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 24),
          Text(
            "No Activity Yet",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.colorTextDark, letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          Text(
            "Your booking history will appear here.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: context.colorTextLight, height: 1.5),
          ),
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
              style: TextStyle(
                color: Colors.orange[800],
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}