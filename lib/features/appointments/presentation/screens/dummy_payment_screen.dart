import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/widgets/volumetric_scaffold.dart';
import 'package:go_router/go_router.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/custom_app_bar.dart'; 
import '../../../../presentation/widgets/primary_button.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';
import '../../data/appointment_repository.dart';
import '../../../../core/services/appointment_notification_service.dart';
import '../../../settings/presentation/settings_notifier.dart';
import '../models/booking_route_args.dart';
import '../../../notifications/presentation/notification_notifier.dart';
import '../../../medical_records/data/medical_record_repository.dart';
import '../../../../presentation/widgets/app_floating_dialog.dart';
import '../../../../presentation/widgets/app_bottom_tray.dart';

class DummyPaymentScreen extends StatefulWidget {
  final DummyPaymentRouteArgs args;

  const DummyPaymentScreen({super.key, required this.args});

  @override
  State<DummyPaymentScreen> createState() => _DummyPaymentScreenState();
}

class _DummyPaymentScreenState extends State<DummyPaymentScreen> {
  bool _isProcessing = false;
  final _appointmentRepo = AppointmentRepository();
  final _medicalRepo = MedicalRecordRepository();
  final _notificationService = AppointmentNotificationService.instance;

  Future<void> _processPayment() async {
    setState(() => _isProcessing = true);

    // 1. Simulate Network Delay for Payment Gateway
    await Future.delayed(const Duration(seconds: 2));

    try {
      // 2. Payment Success! Lock into DB
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

        final attachedIds =
            widget.args.appointmentData['attached_record_ids']
                as List<dynamic>? ??
            [];

        if (attachedIds.isNotEmpty) {
          await Future.wait(
            attachedIds.map(
              (id) => _medicalRepo.lockRecordForReview(
                int.parse(id.toString()),
                unlockDate: widget.args.appointmentDateTime,
              ),
            ),
          );
        }
      }

      // 3. Notification Handling
      if (SettingsNotifier.instance.notificationsEnabled &&
          SettingsNotifier.instance.bookingAlertsEnabled) {
        await _notificationService.showBookingConfirmation(
          appointmentId: persistedAppointmentId,
          doctorName: widget.args.doctorName,
          appointmentTime: "${widget.args.displayDate} at ${widget.args.displayTime}",
        );

        await NotificationNotifier.instance.addNotification(
          title: "Booking Confirmed! ✅",
          body: "Your appointment with ${widget.args.doctorName} is set for ${widget.args.displayDate} at ${widget.args.displayTime}.",
        );
      }

      // 4. Background Reminder Setup
      try {
        if (SettingsNotifier.instance.notificationsEnabled &&
            SettingsNotifier.instance.reminderAlertsEnabled &&
            SettingsNotifier.instance.globalReminderMinutes > 0) {
          final globalMins = SettingsNotifier.instance.globalReminderMinutes;
          final maxWaitTime = widget.args.clinic['max_wait_time'] ?? 30;
          final maxWaitInt = maxWaitTime is int ? maxWaitTime : int.tryParse(maxWaitTime.toString()) ?? 30;

          final timeoutDateTime = widget.args.appointmentDateTime.add(Duration(minutes: maxWaitInt + 15));

          await _notificationService.scheduleReminder(
            appointmentId: persistedAppointmentId,
            appointmentLocalDateTime: widget.args.appointmentDateTime,
            appointmentEndDateTime: timeoutDateTime,
            reminderMinutes: globalMins,
            doctorName: widget.args.doctorName,
            includeFiveHourWarning: SettingsNotifier.instance.fiveHourWarningEnabled,
            includeMorningOfReminder: SettingsNotifier.instance.morningOfReminderEnabled,
            includeMissedStatusUpdate: SettingsNotifier.instance.missedAppointmentAlertEnabled,
          );
        } else {
          await _notificationService.cancelReminder(persistedAppointmentId);
        }
      } catch (error) {
        debugPrint('Reminder scheduling failed: $error');
      }

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
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => AppFloatingDialog(
        headerIcon: Icons.check_circle_outline_rounded,
        iconColor: AppColors.primaryGreen,
        title: isReschedule ? "Rescheduled!" : "Payment Successful!",
        description: isReschedule
            ? "Appointment Updated.\n\nYou have re-booked with ${widget.args.doctorName} on ${widget.args.displayDate}, at ${widget.args.displayTime}."
            : "Your booking is confirmed.\n\nYou have booked with ${widget.args.doctorName} on ${widget.args.displayDate}, at ${widget.args.displayTime}.",
        isUpdating: false,
        content: const SizedBox.shrink(),
        actions: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  final maxWaitTime = widget.args.clinic['max_wait_time'] ?? 30;
                  final maxWaitInt = maxWaitTime is int ? maxWaitTime : int.tryParse(maxWaitTime.toString()) ?? 30;

                  final Event event = Event(
                    title: 'Appointment with ${widget.args.doctorName}',
                    description: 'Medical appointment booked via AeviaPulse.',
                    location: widget.args.clinic['name'] ?? 'Clinic',
                    startDate: widget.args.appointmentDateTime,
                    endDate: widget.args.appointmentDateTime.add(Duration(minutes: maxWaitInt)),
                  );
                  Add2Calendar.addEvent2Cal(event);
                },
                icon: const Icon(Icons.calendar_month, color: AppColors.primaryGreen),
                label: const Text(
                  "Add to Calendar",
                  style: TextStyle(color: AppColors.primaryGreen, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primaryGreen, width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                label: "Done",
                onTap: () {
                  Navigator.of(context).pop();
                  context.go(AppRoutes.appointments, extra: const AppointmentsRouteArgs(refresh: true));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // A sleek, responsive dashed divider for the digital receipt
  Widget _buildDashedDivider() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 6.0;
        const dashHeight = 1.5;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth, height: dashHeight,
              child: DecoratedBox(decoration: BoxDecoration(color: context.colorBorder)),
            );
          }),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return VolumetricScaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: const CustomAppBar(title: "Checkout"),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24, 
          MediaQuery.paddingOf(context).top + kToolbarHeight + 20, 
          24, 
          140 + MediaQuery.viewInsetsOf(context).bottom // Standardized dynamic clearance
        ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Order Summary", style: AppTextStyles.h2(context).copyWith(fontSize: 20)),
                    const SizedBox(height: 16),
                    
                    // --- THE DIGITAL RECEIPT ---
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: AppStyles.surfaceCard(context, borderRadius: BorderRadius.circular(24)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: AppColors.primaryGreen.withValues(alpha: 0.1), shape: BoxShape.circle),
                                child: const Icon(Icons.medical_services_rounded, color: AppColors.primaryGreen, size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(widget.args.doctorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text("${widget.args.displayDate} • ${widget.args.displayTime}", style: TextStyle(color: context.colorTextLight, fontSize: 13, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _buildDashedDivider(),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Consultation Fee", style: TextStyle(fontSize: 14, color: context.colorTextLight, fontWeight: FontWeight.w500)),
                              Text("\$50.00", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.colorTextDark)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Platform Fee", style: TextStyle(fontSize: 14, color: context.colorTextLight, fontWeight: FontWeight.w500)),
                              Text("\$2.50", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.colorTextDark)),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _buildDashedDivider(),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Total (Escrow)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.colorTextDark)),
                              const Text("\$52.50", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primaryGreen, letterSpacing: -0.5)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    Text("Payment Method", style: AppTextStyles.h2(context).copyWith(fontSize: 20)),
                    const SizedBox(height: 16),
                    
                    // --- THE DIGITAL WALLET PASS ---
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primaryGreen, AppColors.primaryGreen.withValues(alpha: 0.8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryGreen.withValues(alpha: 0.3), 
                            blurRadius: 16, 
                            offset: const Offset(0, 8)
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                            child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("AeviaPulse Wallet", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)),
                                const SizedBox(height: 4),
                                Text("Available Balance: \$150.00", style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: const Icon(Icons.check_rounded, color: AppColors.primaryGreen, size: 16),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      // --- FROSTED GLASS CTA ---
      bottomNavigationBar: AppBottomTray(
        child: PrimaryButton(
          label: widget.args.appointmentId != null ? "Pay Reschedule Fee" : "Pay Now & Confirm",
          onTap: _processPayment,
          isLoading: _isProcessing,
          height: 54,
          borderRadius: 16,
        ),
      ),
    );
  }
}
