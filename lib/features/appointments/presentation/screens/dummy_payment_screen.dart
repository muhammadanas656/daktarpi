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
import '../../../notifications/presentation/notification_notifier.dart';

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

      // --- PRO FIX: Granular Notification Logic ---

      // 1. Handle Booking Confirmations (Native + In-App Inbox)
      if (SettingsNotifier.instance.notificationsEnabled &&
          SettingsNotifier.instance.bookingAlertsEnabled) {
        await _notificationService.showBookingConfirmation(
          appointmentId: persistedAppointmentId,
          doctorName: widget.args.doctorName,
          appointmentTime:
              "${widget.args.displayDate} at ${widget.args.displayTime}",
        );

        await NotificationNotifier.instance.addNotification(
          title: "Booking Confirmed! ✅",
          body:
              "Your appointment with ${widget.args.doctorName} is set for ${widget.args.displayDate} at ${widget.args.displayTime}.",
        );
      }

      // 2. Handle Reminder Scheduling (Background Alarms) - 100% GLOBAL NOW
      try {
        if (SettingsNotifier.instance.notificationsEnabled &&
            SettingsNotifier.instance.reminderAlertsEnabled &&
            SettingsNotifier.instance.globalReminderMinutes > 0) {
          final globalMins = SettingsNotifier.instance.globalReminderMinutes;
          final maxWaitTime = widget.args.clinic['max_wait_time'] ?? 30;
          final maxWaitInt =
              maxWaitTime is int
                  ? maxWaitTime
                  : int.tryParse(maxWaitTime.toString()) ?? 30;

          final timeoutDateTime = widget.args.appointmentDateTime.add(
            Duration(minutes: maxWaitInt + 15),
          );

          // A. Schedule the OS Banner
          await _notificationService.scheduleReminder(
            appointmentId: persistedAppointmentId,
            appointmentLocalDateTime: widget.args.appointmentDateTime,
            appointmentEndDateTime: timeoutDateTime,
            reminderMinutes: globalMins,
            doctorName: widget.args.doctorName,
          );

          // PRO FIX B: Create the Time-Released In-App Notification!
          final reminderUnlockTime = widget.args.appointmentDateTime.subtract(
            Duration(minutes: globalMins),
          );

          // Only add it to the inbox if the reminder time is actually in the future
          if (reminderUnlockTime.isAfter(DateTime.now())) {
            await NotificationNotifier.instance.addNotification(
              title: "Upcoming Appointment",
              body:
                  "Reminder: You have an appointment with Dr. ${widget.args.doctorName} at ${widget.args.displayTime}.",
              scheduledTime:
                  reminderUnlockTime, // It stays hidden until this exact minute
            );
          }
        } else {
          await _notificationService.cancelReminder(persistedAppointmentId);
        }
      } catch (error) {
        debugPrint('Reminder scheduling failed: $error');
      }
      // --------------------------------------------------------

      if (mounted) {
        setState(() => _isProcessing = false);
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
            // PRO FIX: Dynamic success modal
            backgroundColor: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: EdgeInsets.all(24.0),
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
                    child: Center(
                      child: Icon(
                        Icons.check_rounded,
                        color: AppColors.primaryGreen,
                        size: 40,
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    isReschedule ? "Rescheduled!" : "Payment Successful!",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: context.colorTextDark,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    isReschedule
                        ? "Appointment Updated"
                        : "Your booking is confirmed",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: context.colorTextLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    "You have booked with ${widget.args.doctorName} on ${widget.args.displayDate}, at ${widget.args.displayTime}",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.colorTextGrey,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Calculate end time using max wait time
                        final maxWaitTime =
                            widget.args.clinic['max_wait_time'] ?? 30;
                        final maxWaitInt =
                            maxWaitTime is int
                                ? maxWaitTime
                                : int.tryParse(maxWaitTime.toString()) ?? 30;

                        final Event event = Event(
                          title: 'Appointment with ${widget.args.doctorName}',
                          description:
                              'Medical appointment booked via DaktarPai.',
                          location: 'Clinic',
                          startDate: widget.args.appointmentDateTime,
                          endDate: widget.args.appointmentDateTime.add(
                            Duration(minutes: maxWaitInt),
                          ),
                        );
                        Add2Calendar.addEvent2Cal(event);
                      },
                      icon: Icon(
                        Icons.calendar_month,
                        color: AppColors.primaryGreen,
                      ),
                      label: Text(
                        "Add to Calendar",
                        style: TextStyle(
                          color: AppColors.primaryGreen,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: AppColors.primaryGreen,
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.go(
                          AppRoutes.appointments,
                          extra: AppointmentsRouteArgs(refresh: true),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
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
      backgroundColor: context.colorBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: context.colorTextDark),
          onPressed: () => context.pop(),
        ),
        title: Text(
          "Checkout",
          style: TextStyle(
            color: context.colorTextDark,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: AppStyles.surfaceCard(
                context,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Order Summary",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.colorTextDark,
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Consultation Fee",
                        style: TextStyle(
                          fontSize: 14,
                          color: context.colorTextLight,
                        ),
                      ),
                      Text(
                        "\$50.00",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.colorTextDark,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Platform Fee",
                        style: TextStyle(
                          fontSize: 14,
                          color: context.colorTextLight,
                        ),
                      ),
                      Text(
                        "\$2.50",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.colorTextDark,
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(color: context.colorBorder),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Total (Escrow)",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: context.colorTextDark,
                        ),
                      ),
                      Text(
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
            SizedBox(height: 32),
            Text(
              "Payment Method",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.colorTextDark,
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.05),
                border: Border.all(color: AppColors.primaryGreen, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
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
                            color: context.colorTextDark,
                          ),
                        ),
                        Text(
                          "Available Balance: \$150.00",
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colorTextLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.check_circle, color: AppColors.primaryGreen),
                ],
              ),
            ),
            Spacer(),
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
