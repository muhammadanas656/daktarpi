import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../presentation/widgets/complaint_dialog.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
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
    // PRO FIX: Instantly listen to the RAM Vault instead of fetching from DB
    _appointmentNotifier.addListener(_onNotifierChanged);
    NetworkNotifier.instance.addListener(_onNetworkChanged);

    // Ensure data is loaded if they navigated here first
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
        // Silently sync in background when internet returns
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
        return Icons.event_available;
      case 'rescheduled':
        return Icons.edit_calendar;
      case 'completed':
        return Icons.check_circle_outline;
      case 'canceled':
        return Icons.cancel_outlined;
      case 'missed':
        return Icons.report_problem_outlined;
      case 'waiting':
        return Icons.hourglass_bottom_rounded;
      default:
        return Icons.history;
    }
  }

  void _showReviewDialog(
    BuildContext context,
    Map<String, dynamic> appointment,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => ReviewDialog(
            appointment: appointment,
            onReviewSubmitted: () {
              // PRO FIX: Instantly mutate the local RAM state and redraw
              if (mounted) {
                setState(() {
                  appointment['has_review'] = true;
                });
              }
            },
          ),
    );
  }

  void _showComplaintDialog(
    BuildContext context,
    Map<String, dynamic> appointment,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => ComplaintDialog(
            appointment: appointment,
            onComplaintSubmitted: () {}, // Handled silently by the Vault now!
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // PRO FIX: Read directly from the central Vault
    final activities = _appointmentNotifier.activityLog;
    final isLoading = _appointmentNotifier.isLoading;

    return Scaffold(
      backgroundColor: context.colorBg,
      appBar: AppBar(
        title: Text(
          "Account Activity",
          style: TextStyle(
            color: context.colorTextDark,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: context.colorTextDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body:
          (isLoading && activities.isEmpty)
              ? const Center(
                child: AppLoader(color: AppColors.primaryGreen),
              )
              : activities.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount:
                    activities.length +
                    (NetworkNotifier.instance.isOffline ? 1 : 0),
                itemBuilder: (context, index) {
                  if (NetworkNotifier.instance.isOffline && index == 0) {
                    return _buildOfflineWarningBanner();
                  }

                  final actualIndex =
                      NetworkNotifier.instance.isOffline ? index - 1 : index;
                  final item = activities[actualIndex];

                  final action =
                      item['action_type']?.toString().toUpperCase() ??
                      'UNKNOWN';
                  final dateStr = item['archived_at'];
                  final doctorName = item['doctors']?['full_name'] ?? 'Doctor';

                  DateTime? date;
                  if (dateStr != null) {
                    date = DateTime.tryParse(dateStr)?.toLocal();
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: AppStyles.surfaceCard(
                      context,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _getActionColor(
                              action,
                            ).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getActionIcon(action),
                            color: _getActionColor(action),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                action,
                                style: TextStyle(
                                  color: _getActionColor(action),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Appointment with $doctorName",
                                style: TextStyle(
                                  color: context.colorTextDark,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (date != null)
                                Text(
                                  DateFormat(
                                    "MMM d, yyyy - h:mm a",
                                  ).format(date),
                                  style: TextStyle(
                                    color: context.colorTextLight,
                                    fontSize: 13,
                                  ),
                                ),

                              if (action == 'COMPLETED') ...[
                                const SizedBox(height: 16),
                                if (item['has_review'] == true)
                                  // PRO FIX: Added the "Review Submitted" unclickable state
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                      horizontal: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.grey.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline,
                                          color: Colors.grey,
                                          size: 16,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          "Review Submitted",
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  OutlinedButton.icon(
                                    onPressed:
                                        () => _showReviewDialog(context, item),
                                    icon: const Icon(
                                      Icons.star_rate_rounded,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      "Leave a Review",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.primaryGreen,
                                      side: const BorderSide(
                                        color: AppColors.primaryGreen,
                                        width: 1.5,
                                      ),
                                      minimumSize: const Size(
                                        double.infinity,
                                        40,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                              ],

                              if (action == 'MISSED') ...[
                                const SizedBox(height: 16),
                                if (item['has_complaint'] == true)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                      horizontal: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.grey.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline,
                                          color: Colors.grey,
                                          size: 16,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          "Complaint Submitted",
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  OutlinedButton.icon(
                                    onPressed:
                                        () =>
                                            _showComplaintDialog(context, item),
                                    icon: const Icon(
                                      Icons.report_problem_outlined,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      "File Complaint",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.deepOrange,
                                      side: const BorderSide(
                                        color: Colors.deepOrange,
                                        width: 1.5,
                                      ),
                                      minimumSize: const Size(
                                        double.infinity,
                                        40,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No Activity Yet",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.colorTextDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Your booking history will appear here.",
            style: TextStyle(color: context.colorTextLight),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineWarningBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "You are currently offline. Live wait times and appointment statuses will update automatically when you reconnect.",
              style: TextStyle(
                color: Colors.orange[800],
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
