import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../presentation/widgets/primary_button.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';
import '../../data/appointment_repository.dart';
import '../../../../core/services/appointment_notification_service.dart';
import '../../../settings/presentation/settings_notifier.dart';
import '../models/booking_route_args.dart';

class DummyPaymentScreen extends StatefulWidget {
  final DummyPaymentRouteArgs args;

  const DummyPaymentScreen({super.key, required this.args});

  @override
  State<DummyPaymentScreen> createState() => _DummyPaymentScreenState();
}

class _DummyPaymentScreenState extends State<DummyPaymentScreen> {
  bool _isProcessing = false;
  final _appointmentRepo = AppointmentRepository();
  final _notificationService = AppointmentNotificationService.instance;

  Future<void> _processPayment() async {
    setState(() => _isProcessing = true);

    // 1. Simulate Network Delay for Payment Gateway (Escrow transaction)
    await Future.delayed(const Duration(seconds: 2));

    try {
      // 2. Payment Success! Now lock it into the Database
      int persistedAppointmentId;
      if (widget.args.appointmentId != null) {
        await _appointmentRepo.updateAppointment(
          widget.args.appointmentId!,
          widget.args.appointmentData,
        );
        persistedAppointmentId = widget.args.appointmentId!;
      } else {
        persistedAppointmentId = await _appointmentRepo.createAppointment(
          widget.args.appointmentData,
        );
      }

      // --- NEW: Trigger Immediate Confirmation Notification ---
      if (SettingsNotifier.instance.notificationsEnabled) {
        await _notificationService.showBookingConfirmation(
          appointmentId: persistedAppointmentId,
          doctorName: widget.args.doctorName,
          appointmentTime:
              "${widget.args.displayDate} at ${widget.args.displayTime}",
        );
      }
      // --------------------------------------------------------

      // 3. Schedule Local Notification Alarm
      bool reminderFailed = false;
      try {
        if (SettingsNotifier.instance.notificationsEnabled &&
            widget.args.reminderMinutes > 0) {
          await _notificationService.scheduleReminder(
            appointmentId: persistedAppointmentId,
            appointmentLocalDateTime: widget.args.appointmentDateTime,
            reminderMinutes: widget.args.reminderMinutes,
            doctorName: widget.args.doctorName,
          );
        } else {
          await _notificationService.cancelReminder(persistedAppointmentId);
        }
      } catch (error) {
        debugPrint('Reminder scheduling failed: $error');
        reminderFailed = true;
      }

      if (mounted) {
        setState(() => _isProcessing = false);
        if (reminderFailed) {
          CustomSnackbar.showInfo(
            context,
            "Appointment confirmed, but reminder could not be scheduled.",
          );
        }
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        CustomSnackbar.showError(context, "Booking failed: $e");
      }
    }
  }

  void _showSuccessDialog() {
    final isReschedule = widget.args.appointmentId != null;

    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.check_rounded,
                        color: AppColors.primaryGreen,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isReschedule ? "Rescheduled!" : "Payment Successful!",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isReschedule
                        ? "Appointment Updated"
                        : "Your booking is confirmed",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "You have booked with ${widget.args.doctorName} on ${widget.args.displayDate}, at ${widget.args.displayTime}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textGrey,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final Event event = Event(
                          title: 'Appointment with ${widget.args.doctorName}',
                          description:
                              'Medical appointment booked via DaktarPai.',
                          location: 'Clinic',
                          startDate: widget.args.appointmentDateTime,
                          endDate: widget.args.appointmentDateTime.add(
                            const Duration(minutes: 30),
                          ),
                        );
                        Add2Calendar.addEvent2Cal(event);
                      },
                      icon: const Icon(
                        Icons.calendar_month,
                        color: AppColors.primaryGreen,
                      ),
                      label: const Text(
                        "Add to Calendar",
                        style: TextStyle(
                          color: AppColors.primaryGreen,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: AppColors.primaryGreen,
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.go(
                          AppRoutes.appointments,
                          extra: const AppointmentsRouteArgs(refresh: true),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        "Done",
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
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textDark),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          "Checkout",
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppStyles.surfaceCard(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Order Summary",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Consultation Fee",
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textLight,
                        ),
                      ),
                      const Text(
                        "\$50.00",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Platform Fee",
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textLight,
                        ),
                      ),
                      const Text(
                        "\$2.50",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(color: AppColors.borderColor),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Total (Escrow)",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const Text(
                        "\$52.50",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              "Payment Method",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.05),
                border: Border.all(color: AppColors.primaryGreen, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    color: AppColors.primaryGreen,
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "DaktarPai Wallet",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          "Available Balance: \$150.00",
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.check_circle, color: AppColors.primaryGreen),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: PrimaryButton(
                label:
                    widget.args.appointmentId != null
                        ? "Pay Reschedule Fee"
                        : "Pay Now & Confirm",
                onTap: _processPayment,
                isLoading: _isProcessing,
                borderRadius: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
