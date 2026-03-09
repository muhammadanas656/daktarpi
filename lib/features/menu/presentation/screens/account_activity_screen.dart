import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../presentation/widgets/complaint_dialog.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../appointments/data/appointment_repository.dart';
import '../../presentation/widgets/review_dialog.dart';
import '../../../../core/network/network_notifier.dart';

class AccountActivityScreen extends StatefulWidget {
  const AccountActivityScreen({super.key});

  @override
  State<AccountActivityScreen> createState() => _AccountActivityScreenState();
}

class _AccountActivityScreenState extends State<AccountActivityScreen> {
  final _repository = AppointmentRepository();
  List<Map<String, dynamic>> _activities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchActivity();
    
    // PRO FIX: Actively listen for internet connection changes
    NetworkNotifier.instance.addListener(_onNetworkChanged);
  }

  // PRO FIX: Clean up the network listener
  @override
  void dispose() {
    NetworkNotifier.instance.removeListener(_onNetworkChanged);
    super.dispose();
  }

  // PRO FIX: Triggers a UI rebuild and an automatic silent data refresh!
  void _onNetworkChanged() {
    if (mounted) {
      setState(() {}); // Instantly hides the offline banner
      
      if (!NetworkNotifier.instance.isOffline) {
        // The second the internet returns, silently fetch the live history!
        _fetchActivity();
      }
    }
  }

  Future<void> _fetchActivity() async {
    final userId = _repository.currentUserId;
    if (userId == null) return;

    try {
      final data = await _repository.fetchActivityLog(userId);
      if (mounted) {
        setState(() {
          _activities = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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
            onReviewSubmitted: _fetchActivity,
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
            onComplaintSubmitted: _fetchActivity,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          // PRO FIX: Allows the history list to update silently in the background
          (_isLoading && _activities.isEmpty)
              ? Center(
                child: CircularProgressIndicator(color: AppColors.primaryGreen),
              )
              : _activities.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                padding: EdgeInsets.all(24),
                // Increase item count by 1 to make room for the banner
                itemCount:
                    _activities.length +
                    (NetworkNotifier.instance.isOffline ? 1 : 0),
                itemBuilder: (context, index) {
                  // PRO FIX: Show the offline warning at the top of the history list
                  if (NetworkNotifier.instance.isOffline && index == 0) {
                    return _buildOfflineWarningBanner();
                  }

                  // Adjust the index if the banner is showing
                  final actualIndex =
                      NetworkNotifier.instance.isOffline ? index - 1 : index;
                  final item = _activities[actualIndex];

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
                    margin: EdgeInsets.only(bottom: 16),
                    padding: EdgeInsets.all(16),
                    decoration: AppStyles.surfaceCard(
                      context,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.all(10),
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
                        SizedBox(width: 16),
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
                              SizedBox(height: 4),
                              Text(
                                "Appointment with $doctorName",
                                style: TextStyle(
                                  color: context.colorTextDark,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 4),
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

                              if (action == 'WAITING') ...[
                                SizedBox(height: 16),
                                Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.amber.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline_rounded,
                                        color: Colors.amber,
                                        size: 18,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          "The clinic is running slightly behind schedule. Please wait.",
                                          style: TextStyle(
                                            color: Colors.amber,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              if (action == 'COMPLETED' &&
                                  item['has_review'] != true) ...[
                                SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed:
                                      () => _showReviewDialog(context, item),
                                  icon: Icon(Icons.star_rate_rounded, size: 18),
                                  label: Text(
                                    "Leave a Review",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primaryGreen,
                                    side: BorderSide(
                                      color: AppColors.primaryGreen,
                                      width: 1.5,
                                    ),
                                    minimumSize: Size(double.infinity, 40),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ],

                              // --- UPDATED: Button only shows if has_complaint is false ---
                              // --- UPDATED: Show Complaint Button OR Status Badge ---
                              if (action == 'MISSED') ...[
                                SizedBox(height: 16),
                                if (item['has_complaint'] == true)
                                  // Show a non-interactive status badge if already submitted
                                  Container(
                                    padding: EdgeInsets.symmetric(
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
                                    child: Row(
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
                                  // Show the active button if no complaint exists
                                  OutlinedButton.icon(
                                    onPressed:
                                        () =>
                                            _showComplaintDialog(context, item),
                                    icon: Icon(
                                      Icons.report_problem_outlined,
                                      size: 18,
                                    ),
                                    label: Text(
                                      "File Complaint",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.deepOrange,
                                      side: BorderSide(
                                        color: Colors.deepOrange,
                                        width: 1.5,
                                      ),
                                      minimumSize: Size(double.infinity, 40),
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
          SizedBox(height: 16),
          Text(
            "No Activity Yet",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.colorTextDark,
            ),
          ),
          SizedBox(height: 8),
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
                color: Colors.orange[800], // Darker orange for readability
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
