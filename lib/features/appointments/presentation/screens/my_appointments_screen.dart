import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart'; // PRO FIX
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
import '../../../../presentation/widgets/complaint_dialog.dart';
import '../../../../presentation/widgets/app_text_field.dart';

class MyAppointmentsScreen extends StatefulWidget {
  const MyAppointmentsScreen({super.key});

  @override
  State<MyAppointmentsScreen> createState() => _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends State<MyAppointmentsScreen> {
  final Uuid _uuid = Uuid();
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
        appointmentDate: DateTime.now().add(Duration(days: 1)),
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

    // --- NEW: Calculate the 4-hour cancellation window ---
    bool canCancel = true;
    try {
      final dateStr = appointment['schedule_date'].toString().split('T')[0];
      final startTimeStr = appointment['start_time'].toString();
      final startDateTime = DateTime.parse('$dateStr $startTimeStr');

      // Check if the appointment is less than 4 hours away
      final timeDifference = startDateTime.difference(DateTime.now());
      if (timeDifference.inHours < 4) {
        canCancel = false;
      }
    } catch (e) {
      debugPrint("Error parsing time for cancellation check: $e");
    }
    // ----------------------------------------------------

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      // PRO FIX: Dynamic surface for the bottom sheet
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (context) => SafeArea(
            child: Container(
              padding: EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.colorBorder,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    SizedBox(height: 24),
                    Text(
                      "Manage Appointment",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: context.colorTextDark,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "With $doctorName",
                      style: TextStyle(
                        color: context.colorTextLight,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 24),

                    // --- CALENDAR BUTTON ---
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
                        padding: EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.calendar_month,
                                color: Colors.orange,
                                size: 20,
                              ),
                            ),
                            SizedBox(width: 16),
                            Text(
                              "Add to Device Calendar",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: context.colorTextDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Divider(color: context.colorBorder),
                    ),

                    // --- RESCHEDULE BUTTON ---
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _handleReschedule(appointment);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen.withValues(
                                  alpha: 0.1,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.edit_calendar,
                                color: AppColors.primaryGreen,
                                size: 20,
                              ),
                            ),
                            SizedBox(width: 16),
                            Text(
                              "Reschedule",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: context.colorTextDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Divider(color: context.colorBorder),
                    ),

                    // --- COMPLETE BUTTON ---
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _completeAppointment(appointment['id']);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Color(0xFF2196F3).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check_circle_outline,
                                color: Color(0xFF2196F3),
                                size: 20,
                              ),
                            ),
                            SizedBox(width: 16),
                            Text(
                              "Mark as Completed",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: context.colorTextDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Divider(color: context.colorBorder),
                    ),

                    // --- UPDATED: CANCEL BUTTON (WITH 4-HOUR LOGIC) ---
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        if (canCancel) {
                          _confirmCancellation(appointment);
                        } else {
                          // Show the rule if they tap the greyed-out button!
                          CustomSnackbar.showError(
                            context,
                            "Appointments cannot be canceled within 4 hours of the scheduled time. Please contact support or the clinic directly.",
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color:
                                    canCancel
                                        ? AppColors.dangerRed.withValues(
                                          alpha: 0.1,
                                        )
                                        : Colors.grey.withValues(
                                          alpha: 0.1,
                                        ), // Turns grey if too close!
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close,
                                color:
                                    canCancel
                                        ? AppColors.dangerRed
                                        : Colors
                                            .grey, // Turns grey if too close!
                                size: 20,
                              ),
                            ),
                            SizedBox(width: 16),
                            Text(
                              "Cancel Appointment",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color:
                                    canCancel
                                        ? AppColors.dangerRed
                                        : Colors
                                            .grey, // Turns grey if too close!
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
            // PRO FIX: Dynamic surface for the dialog
            backgroundColor: Theme.of(context).colorScheme.surface,
            insetPadding: EdgeInsets.symmetric(horizontal: 24),
            child: Padding(
              padding: EdgeInsets.all(24),
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
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.dangerRed,
                      size: 40,
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    "Cancel Appointment?",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: context.colorTextDark,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    "Are you sure you want to cancel this appointment? This action cannot be undone.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.colorTextLight,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            "Back",
                            style: TextStyle(
                              color: context.colorTextLight,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _cancelAppointment(appointment['id']);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.dangerRed,
                            elevation: 0,
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
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
              return AnimatedPadding(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  insetPadding: EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Rate Your Experience",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: context.colorTextDark,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "With ${appointment['doctors']?['full_name'] ?? 'Doctor'}",
                          style: TextStyle(
                            fontSize: 14,
                            color: context.colorTextLight,
                          ),
                        ),
                        SizedBox(height: 24),
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
                        SizedBox(height: 16),
                        AppTextField(
                          controller: commentController,
                          maxLines: 3,
                          hintText: "Write your review here (optional)...",
                        ),
                        SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed:
                                    isSubmitting
                                        ? null
                                        : () => Navigator.pop(ctx),
                                child: Text(
                                  "Cancel",
                                  style: TextStyle(
                                    color: context.colorTextLight,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
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
                                              doctorId:
                                                  appointment['doctor_id'],
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
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                ),
                                child:
                                    isSubmitting
                                        ? SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                        : Text(
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
                ),
              );
            },
          ),
    ).whenComplete(() => commentController.dispose());
  }

  // --- NEW: Pending Reviews Carousel ---
  // --- UPDATED: Action Required Carousel (Handles Reviews & Complaints) ---
  Widget _buildActionRequiredCarousel() {
    final pendingItems = _appointmentNotifier.actionRequiredItems;
    if (pendingItems.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            "Action Required",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.colorTextDark,
              letterSpacing: 0.5,
            ),
          ),
        ),
        SizedBox(height: 12),
        SizedBox(
          height: 150,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: 24),
            scrollDirection: Axis.horizontal,
            itemCount: pendingItems.length,
            separatorBuilder: (_, __) => SizedBox(width: 16),
            itemBuilder: (context, index) {
              final appt = pendingItems[index];
              final doctor = appt['doctors'] ?? {};

              final isMissed = appt['status'] == 'missed';

              // Define themes based on the action type
              final themeColor = isMissed ? Colors.deepOrange : Colors.orange;
              final actionText =
                  isMissed ? "Appointment Missed" : "Rate your visit";
              final buttonText = isMissed ? "File Complaint" : "Leave a Review";
              final buttonIcon =
                  isMissed
                      ? Icons.report_problem_outlined
                      : Icons.star_rate_rounded;

              return Container(
                width: 280,
                padding: const EdgeInsets.all(16),
                // PRO FIX: Dynamic dark mode cards for the carousel
                decoration: AppStyles.surfaceCard(
                  context,
                  borderRadius: BorderRadius.circular(16),
                ).copyWith(
                  border: Border.all(
                    color: themeColor.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor:
                              Theme.of(context).brightness == Brightness.dark
                                  ? AppColors.darkBorder
                                  : Colors.grey[100],
                          // PRO FIX: Use CachedNetworkImageProvider for offline support
                          backgroundImage:
                              doctor['profile_picture_url'] != null &&
                                      doctor['profile_picture_url'].isNotEmpty
                                  ? CachedNetworkImageProvider(doctor['profile_picture_url'])
                                  : null,
                          child:
                              (doctor['profile_picture_url'] == null ||
                                      doctor['profile_picture_url'].isEmpty)
                                  ? Icon(Icons.person, color: Colors.grey)
                                  : null,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                actionText,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: themeColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                doctor['full_name'] ?? 'Doctor',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: context.colorTextDark,
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
                        onPressed: () {
                          if (isMissed) {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder:
                                  (ctx) => ComplaintDialog(
                                    appointment: appt,
                                    onComplaintSubmitted: () {
                                      _appointmentNotifier
                                          .removePendingComplaint(appt['id']);
                                    },
                                  ),
                            );
                          } else {
                            _showReviewDialog(context, appt);
                          }
                        },
                        icon: Icon(buttonIcon, size: 18),
                        label: Text(
                          buttonText,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: themeColor,
                          side: BorderSide(color: themeColor, width: 1.5),
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
        SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppStyles.pageGradient(context)),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAppBar(),

              if (!_appointmentNotifier.isLoading)
                _buildActionRequiredCarousel(),

              // REMOVED the rigid banner and spacing from here!
              Expanded(
                child:
                    _appointmentNotifier.isLoading
                        ? Center(
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
            // PRO FIX: Context-aware app bar icon button
            decoration: AppStyles.surfaceCard(
              context,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.calendar_today,
              size: 18,
              color: context.colorTextDark,
            ),
          ),
          const SizedBox(width: 20),
          Text("My Appointments", style: AppTextStyles.h1(context)),
        ],
      ),
    );
  }

  Widget _buildUpcomingBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: 0.2),
        ),
      ),
      child: Center(
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
    );
  }

  Widget _buildListView() {
    final appointments = _appointmentNotifier.appointments;

    return RefreshIndicator(
      onRefresh: _appointmentNotifier.fetchAppointments,
      color: AppColors.primaryGreen,
      // PRO FIX: Dynamic refresh indicator background
      backgroundColor: Theme.of(context).colorScheme.surface,
      child:
          appointments.isEmpty
              ? ListView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: 24,
                ), // Added padding here
                children: [
                  SizedBox(height: 16),
                  _buildRefreshHint(),
                  SizedBox(height: 24),
                  _buildUpcomingBanner(), // Scrolls naturally in the empty state!
                  SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_available,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        SizedBox(height: 16),
                        Text(
                          "No upcoming appointments",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: context.colorTextLight,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Your scheduled visits will appear here.",
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              )
              : ListView.separated(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(24, 16, 24, 24),
                // +2 because index 0 is the hint, and index 1 is the Banner
                itemCount: appointments.length + 2,
                separatorBuilder: (context, index) {
                  return SizedBox(height: 16);
                },
                itemBuilder: (context, index) {
                  // 1. Render the pull-to-refresh hint at the very top
                  if (index == 0) return _buildRefreshHint();

                  // 2. Render the Banner smoothly underneath the hint
                  if (index == 1) {
                    return Padding(
                      padding: EdgeInsets.only(bottom: 8.0),
                      child: _buildUpcomingBanner(),
                    );
                  }

                  // 3. Shift index by 2 to get the actual appointment data
                  final apt = appointments[index - 2].toJson();
                  final doctor = apt['doctors'] as Map<String, dynamic>? ?? {};
                  final specialty =
                      doctor['specialties'] != null
                          ? doctor['specialties']['name']
                          : "Specialist";

                  // 1. Get the current appointment's clinic ID
                  final currentClinicId = apt['clinic_id'];

                  // 2. Default fallback
                  int waitTime = 30;

                  // 3. Find the matching wait time for this specific doctor/clinic combo
                  if (doctor['doctor_clinics'] != null) {
                    final docClinicsList =
                        doctor['doctor_clinics'] as List<dynamic>;
                    for (var dc in docClinicsList) {
                      if (dc['clinic_id'] == currentClinicId) {
                        waitTime = dc['max_wait_time'] ?? 30;
                        break;
                      }
                    }
                  }

                  // Inside _buildListView() -> itemBuilder
                  return AppointmentCard(
                    name: doctor['full_name'] ?? "Unknown Doctor",
                    specialty: specialty,
                    date: _formatDate(apt['schedule_date']),
                    time: _formatTimeRange(apt['start_time'], apt['end_time']),
                    imageUrl: doctor['profile_picture_url'] ?? "",
                    status:
                        apt['status'] ??
                        'pending', // NEW: Pass the status down!
                    // NEW: Pass the raw time data for the countdown math!
                    scheduleDate: apt['schedule_date'],
                    startTime: apt['start_time'],
                    maxWaitTime: waitTime, // <--- PASS THE CALCULATED TIME

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
        SizedBox(width: 4),
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
