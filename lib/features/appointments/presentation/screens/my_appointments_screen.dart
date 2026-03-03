import 'package:flutter/material.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
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

  @override
  void initState() {
    super.initState();
    _appointmentNotifier.initializeRealtime();
    _appointmentNotifier.fetchAppointments();
    _appointmentNotifier.addListener(_onNotifierChanged);
  }

  @override
  void dispose() {
    _appointmentNotifier.removeListener(_onNotifierChanged);
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
        CustomSnackbar.showError(context, e.toString());
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
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (context) => SafeArea(
            child: Container(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
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

                        try {
                          final dateStr =
                              appointment['schedule_date'].toString().split(
                                'T',
                              )[0];
                          final startTimeStr =
                              appointment['start_time'].toString();
                          final endTimeStr =
                              appointment['end_time']?.toString() ??
                              startTimeStr;

                          final startDateTime = DateTime.parse(
                            '$dateStr $startTimeStr',
                          );
                          final endDateTime = DateTime.parse(
                            '$dateStr $endTimeStr',
                          );

                          final event = Event(
                            title: 'Appointment with $doctorName',
                            description:
                                'Medical appointment booked via DaktarPai.',
                            location:
                                appointment['clinics']?['name'] ?? 'Clinic',
                            startDate: startDateTime,
                            endDate: endDateTime,
                          );
                          Add2Calendar.addEvent2Cal(event);
                        } catch (e) {
                          CustomSnackbar.showError(
                            context,
                            "Could not parse appointment time.",
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.calendar_month,
                                color: Colors.orange,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Text(
                              "Add to Device Calendar",
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
                                color: AppColors.dangerRed.withValues(
                                  alpha: 0.1,
                                ),
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

  // --- NEW: Interactive Review Dialog ---
  void _showReviewDialog(
    BuildContext context,
    Map<String, dynamic> appointment,
  ) {
    int selectedRating = 0;
    final commentController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => StatefulBuilder(
            builder: (context, setDialogState) {
              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                backgroundColor: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Rate Your Experience",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "With ${appointment['doctors']?['full_name'] ?? 'Doctor'}",
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textLight,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (index) {
                            return IconButton(
                              icon: Icon(
                                index < selectedRating
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: Colors.amber,
                                size: 40,
                              ),
                              onPressed:
                                  () => setDialogState(
                                    () => selectedRating = index + 1,
                                  ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: commentController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: "Write your review here (optional)...",
                          hintStyle: const TextStyle(
                            color: AppColors.hintText,
                            fontSize: 14,
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.borderColor,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primaryGreen,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed:
                                  isSubmitting
                                      ? null
                                      : () => Navigator.pop(ctx),
                              child: const Text(
                                "Cancel",
                                style: TextStyle(color: AppColors.textLight),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  (selectedRating == 0 || isSubmitting)
                                      ? null
                                      : () async {
                                        setDialogState(
                                          () => isSubmitting = true,
                                        );
                                        try {
                                          await _appointmentRepo.submitReview(
                                            appointmentId: appointment['id'],
                                            doctorId: appointment['doctor_id'],
                                            rating: selectedRating,
                                            comment:
                                                commentController.text.trim(),
                                          );
                                          if (ctx.mounted) {
                                            Navigator.pop(ctx);
                                            CustomSnackbar.showSuccess(
                                              ctx,
                                              "Thank you! Your review has been submitted.",
                                            );
                                            // Automatically hide the card!
                                            _appointmentNotifier
                                                .removePendingReview(
                                                  appointment['id'],
                                                );
                                          }
                                        } catch (e) {
                                          setDialogState(
                                            () => isSubmitting = false,
                                          );
                                          if (ctx.mounted) {
                                            CustomSnackbar.showError(
                                              ctx,
                                              "Error: $e",
                                            );
                                          }
                                        }
                                      },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey[300],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child:
                                  isSubmitting
                                      ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : const Text(
                                        "Submit",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }

  // --- NEW: Pending Reviews Carousel ---
  Widget _buildPendingReviewsCarousel() {
    final pending = _appointmentNotifier.pendingReviews;
    // The magic logic: If it's empty, this takes up ZERO space!
    if (pending.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            "Action Required",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 150,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            scrollDirection: Axis.horizontal,
            itemCount: pending.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final appt = pending[index];
              final doctor = appt['doctors'] ?? {};

              return Container(
                width: 280,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.grey[100],
                          backgroundImage:
                              doctor['profile_picture_url'] != null &&
                                      doctor['profile_picture_url'].isNotEmpty
                                  ? NetworkImage(doctor['profile_picture_url'])
                                  : null,
                          child:
                              (doctor['profile_picture_url'] == null ||
                                      doctor['profile_picture_url'].isEmpty)
                                  ? const Icon(Icons.person, color: Colors.grey)
                                  : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Rate your visit",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                doctor['full_name'] ?? 'Doctor',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.textDark,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: OutlinedButton.icon(
                        onPressed: () => _showReviewDialog(context, appt),
                        icon: const Icon(Icons.star_rate_rounded, size: 18),
                        label: const Text(
                          "Leave a Review",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: const BorderSide(
                            color: Colors.orange,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppStyles.pageGradient),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAppBar(),

              // --- NEW: Only shows if there are pending reviews! ---
              if (!_appointmentNotifier.isLoading)
                _buildPendingReviewsCarousel(),

              // -----------------------------------------------------
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

    // We now wrap the ENTIRE logic in the RefreshIndicator so it always works
    return RefreshIndicator(
      onRefresh: _appointmentNotifier.fetchAppointments,
      color: AppColors.primaryGreen,
      backgroundColor: Colors.white,
      child:
          appointments.isEmpty
              ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 16),
                  _buildRefreshHint(), // The visual hint!
                  SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_available,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "No upcoming appointments",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textLight,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Your scheduled visits will appear here.",
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              )
              : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                // We add 1 to the item count so the hint is the very first item
                itemCount: appointments.length + 1,
                separatorBuilder: (context, index) {
                  if (index == 0) return const SizedBox(height: 16);
                  return const SizedBox(height: 16);
                },
                itemBuilder: (context, index) {
                  // Render the hint at the top of the list
                  if (index == 0) {
                    return _buildRefreshHint();
                  }

                  // Shift index by 1 to get the actual appointment data
                  final apt = appointments[index - 1].toJson();
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
                    onTap: () {},
                    onMoreTap: () => _showActionSheet(apt),
                  );
                },
              ),
    );
  }

  // --- NEW: A beautiful, subtle UI hint indicating the list can be pulled ---
  Widget _buildRefreshHint() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 16,
          color: Colors.grey[400],
        ),
        const SizedBox(width: 4),
        Text(
          "Pull down to refresh",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey[400],
          ),
        ),
      ],
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
