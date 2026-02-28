import 'package:flutter/material.dart';
import '../../../../core/services/appointment_notification_service.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_routes.dart';
import '../../data/appointment_repository.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';
import '../appointment_notifier.dart';
import '../../../../presentation/widgets/appointment_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;
import 'package:uuid/uuid.dart';
import '../models/booking_route_args.dart';

class MyAppointmentsScreen extends StatefulWidget {
  const MyAppointmentsScreen({super.key});

  @override
  State<MyAppointmentsScreen> createState() => _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends State<MyAppointmentsScreen> {
  final Uuid _uuid = const Uuid();
  final _appointmentRepo = AppointmentRepository();
  final _appointmentNotifier = AppointmentNotifier.instance;
  RealtimeChannel? _appointmentsSubscription;

  @override
  void initState() {
    super.initState();
    _appointmentNotifier.fetchAppointments();
    _appointmentNotifier.addListener(_onNotifierChanged);
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _appointmentNotifier.removeListener(_onNotifierChanged);
    if (_appointmentsSubscription != null) {
      _appointmentRepo.removeChannel(_appointmentsSubscription!);
    }
    super.dispose();
  }

  void _onNotifierChanged() {
    if (mounted) setState(() {});
  }

  // --- REFRESH LOGIC ---
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra;
    if (extra is AppointmentsRouteArgs && extra.refresh) {
      _appointmentNotifier.fetchAppointments();
      // Clear extra logic would ideally happen here or inside router
      WidgetsBinding.instance.addPostFrameCallback((_) {
        CustomSnackbar.showSuccess(context, "Appointment Successful!");
      });
    }
  }

  void _setupRealtimeSubscription() {
    final userId = _appointmentRepo.currentUserId;
    if (userId == null) return;

    _appointmentsSubscription = _appointmentRepo.subscribeToAppointments(
      userId: userId,
      onChange: (payload) => _appointmentNotifier.fetchAppointments(),
    );
  }

  // _fetchAppointments removed (using notifier)

  Future<void> _cancelAppointment(int id) async {
    try {
      await _appointmentNotifier.cancelAppointment(id);
      await AppointmentNotificationService.instance.cancelReminder(id);

      if (mounted) {
        CustomSnackbar.showSuccess(context, "Appointment Cancelled");
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, "Could not cancel appointment.");
      }
    }
  }

  Future<void> _completeAppointment(int id) async {
    try {
      await _appointmentNotifier.completeAppointment(id);
      await AppointmentNotificationService.instance.cancelReminder(id);

      if (mounted) {
        CustomSnackbar.showSuccess(context, "Appointment marked as completed");
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, "Could not complete appointment.");
      }
    }
  }

  Future<void> _handleReschedule(Map<String, dynamic> appointment) async {
    final doctor = appointment['doctors'];
    final clinic = appointment['clinics'];
    final int appointmentId = appointment['id'];

    debugPrint("Rescheduling Appointment ID: $appointmentId");

    final patientDetails = {
      'name': appointment['patient_name'] ?? "",
      'phone': appointment['patient_phone'] ?? "",
      'email': appointment['patient_email'] ?? "",
      'gender': appointment['patient_gender'] ?? "Male",
      'dob': appointment['patient_dob'] ?? DateTime.now().toIso8601String(),
    };

    final result = await context.push(
      AppRoutes.paymentMethod,
      extra: PaymentMethodArgs(
        doctor: Map<String, dynamic>.from(doctor ?? const {}),
        clinic: Map<String, dynamic>.from(clinic ?? const {}),
        patientDetails: patientDetails,
        appointmentDate: DateTime.now().add(const Duration(days: 1)),
        appointmentId: appointmentId,
        idempotencyKey: _uuid.v4(),
      ),
    );

    if (result == true && mounted) {
      CustomSnackbar.showSuccess(context, "Reschedule Successful!");
      _appointmentNotifier.fetchAppointments();
    }
  }

  void _showActionSheet(Map<String, dynamic> appointment) {
    final String doctorName = appointment['doctors']?['full_name'] ?? "Doctor";

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (context) => SafeArea(
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Manage Appointment",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "With $doctorName",
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      _handleReschedule(appointment);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withValues(
                                alpha: 0.1,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit_calendar,
                              color: AppColors.primaryGreen,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            "Reschedule",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Divider(color: AppColors.borderColor),
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      _completeAppointment(appointment['id']);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF2196F3,
                              ).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle_outline,
                              color: Color(0xFF2196F3),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            "Mark as Completed",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Divider(color: AppColors.borderColor),
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      _confirmCancellation(appointment);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.dangerRed.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: AppColors.dangerRed,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            "Cancel Appointment",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: AppColors.dangerRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _confirmCancellation(Map<String, dynamic> appointment) {
    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      color: AppColors.dangerRed.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.dangerRed,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Cancel Appointment?",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Are you sure you want to cancel this appointment? This action cannot be undone.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textLight,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Back",
                            style: TextStyle(
                              color: AppColors.textLight,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _cancelAppointment(appointment['id']);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.dangerRed,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Yes, Cancel",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppStyles.pageGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              _buildUpcomingBanner(),
              const SizedBox(height: 24),
              Expanded(
                child:
                    _appointmentNotifier.isLoading
                        ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryGreen,
                          ),
                        )
                        : _buildListView(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.calendar_today,
              size: 18,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(width: 20),
          Text("My Appointments", style: AppTextStyles.h1),
        ],
      ),
    );
  }

  Widget _buildUpcomingBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.primaryGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primaryGreen.withValues(alpha: 0.2),
          ),
        ),
        child: const Center(
          child: Text(
            "Upcoming Schedule",
            style: TextStyle(
              color: AppColors.primaryGreen,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListView() {
    final appointments = _appointmentNotifier.appointments;

    if (appointments.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          const Center(
            child: Text(
              "No upcoming appointments",
              style: TextStyle(color: AppColors.textLight),
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _appointmentNotifier.fetchAppointments,
      color: AppColors.primaryGreen,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        itemCount: appointments.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final apt =
              appointments[index]
                  .toJson(); // Convert model to map for existing UI compatibility
          final doctor = apt['doctors'] as Map<String, dynamic>? ?? {};
          final specialty =
              doctor['specialties'] != null
                  ? doctor['specialties']['name']
                  : "Specialist";

          return AppointmentCard(
            name: doctor['full_name'] ?? "Unknown Doctor",
            specialty: specialty,
            date: _formatDate(apt['schedule_date']),
            time: _formatTimeRange(apt['start_time'], apt['end_time']),
            imageUrl: doctor['profile_picture_url'] ?? "",
            onTap: () {}, // No detail screen yet
            onMoreTap: () => _showActionSheet(apt),
          );
        },
      ),
    );
  }

  String _formatDate(String? d) {
    if (d == null) return "";
    try {
      return DateFormat('EEEE, d MMMM').format(DateTime.parse(d));
    } catch (_) {
      return d;
    }
  }

  String _formatTimeRange(String? s, String? e) {
    if (s == null) return "";
    return "${_formatTime(s)} - ${_formatTime(e ?? s)}";
  }

  String _formatTime(String t) {
    try {
      return DateFormat("h:mm a").format(DateFormat("HH:mm:ss").parse(t));
    } catch (_) {
      return t;
    }
  }
}
