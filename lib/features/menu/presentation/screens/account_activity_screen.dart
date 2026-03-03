import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../appointments/data/appointment_repository.dart';
import '../widgets/review_dialog.dart';

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

  // --- UPDATED: Added 'missed' case ---
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
        return Colors.deepOrange; // Distinct color for missed
      default:
        return AppColors.textLight;
    }
  }

  // --- UPDATED: Added 'missed' icon ---
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
        return Icons.alarm_off_rounded; // Distinct icon for missed
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

  // --- NEW: Complaint Dialog Trigger ---
  void _showComplaintDialog(
    BuildContext context,
    Map<String, dynamic> appointment,
  ) {
    // We will build a ComplaintDialog similar to ReviewDialog in the next step!
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Complaint Dialog UI Coming Soon!")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgColor,
      appBar: AppBar(
        title: const Text(
          "Account Activity",
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: AppColors.primaryGreen),
              )
              : _activities.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: _activities.length,
                itemBuilder: (context, index) {
                  final item = _activities[index];
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
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
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
                                style: const TextStyle(
                                  color: AppColors.textDark,
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
                                  style: const TextStyle(
                                    color: AppColors.textLight,
                                    fontSize: 13,
                                  ),
                                ),

                              if (action == 'COMPLETED' &&
                                  item['has_review'] != true) ...[
                                const SizedBox(height: 16),
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

                              // --- NEW: Render the Complaint Button for Missed appointments ---
                              if (action == 'MISSED') ...[
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed:
                                      () => _showComplaintDialog(context, item),
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
                              // ----------------------------------------------------
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
          const Text(
            "No Activity Yet",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Your booking history will appear here.",
            style: TextStyle(color: AppColors.textLight),
          ),
        ],
      ),
    );
  }
}
