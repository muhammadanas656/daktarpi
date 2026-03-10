import 'dart:ui' as ui; // PRO FIX: Added for image capture

import 'dart:typed_data'; // PRO FIX: Added for image processing

import 'dart:io'; // PRO FIX: Added for file handling

import 'package:flutter/rendering.dart'; // PRO FIX: Added for RepaintBoundary

import 'package:flutter/material.dart';

import 'package:cached_network_image/cached_network_image.dart';

import 'package:add_2_calendar/add_2_calendar.dart';

import 'package:path_provider/path_provider.dart'; // PRO FIX: Added

import 'package:share_plus/share_plus.dart'; // PRO FIX: Added

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

import '../../../../core/network/network_notifier.dart';

class MyAppointmentsScreen extends StatefulWidget {
  const MyAppointmentsScreen({super.key});

  @override
  State<MyAppointmentsScreen> createState() => _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends State<MyAppointmentsScreen> {
  final Uuid _uuid = Uuid();

  final _appointmentRepo = AppointmentRepository();

  final _appointmentNotifier = AppointmentNotifier.instance;
  bool _hasProcessedRouteArgs = false;
  @override
  void initState() {
    super.initState();

    _appointmentNotifier.initializeRealtime();

    _appointmentNotifier.fetchAppointments();

    _appointmentNotifier.addListener(_onNotifierChanged);

    NetworkNotifier.instance.addListener(_onNetworkChanged);
  }

  @override
  void dispose() {
    _appointmentNotifier.removeListener(_onNotifierChanged);

    NetworkNotifier.instance.removeListener(_onNetworkChanged);

    super.dispose();
  }

  void _onNetworkChanged() {
    if (mounted) {
      setState(() {});

      if (!NetworkNotifier.instance.isOffline) {
        // PRO FIX: Silent refresh when network is restored!
        _appointmentNotifier.fetchAppointments(isBackground: true);
      }
    }
  }

  void _onNotifierChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // PRO FIX: Only process the GoRouter 'extra' arguments ONCE
    if (!_hasProcessedRouteArgs) {
      final extra = GoRouterState.of(context).extra;
      if (extra is AppointmentsRouteArgs && extra.refresh) {
        _appointmentNotifier.fetchAppointments();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          CustomSnackbar.showSuccess(context, "Appointment Successful!");
        });
      }
      _hasProcessedRouteArgs =
          true; // Lock it so it never runs again on resume!
    }
  }

  Future<void> _cancelAppointment(int id) async {
    try {
      await _appointmentNotifier.cancelAppointment(id);

      await AppointmentNotificationService.instance.cancelReminder(id);

      if (mounted) {
        CustomSnackbar.showSuccess(context, "Appointment Cancelled");
      }
    } catch (e) {
      if (mounted) CustomSnackbar.showError(context, e.toString());
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

  // --- PRO FIX: Helper to draw a ticket "tear-off" dashed line ---

  Widget _buildDashedDivider(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();

        const dashWidth = 6.0;

        const dashHeight = 1.5;

        final dashCount = (boxWidth / (2 * dashWidth)).floor();

        return Flex(
          direction: Axis.horizontal,

          mainAxisAlignment: MainAxisAlignment.spaceBetween,

          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,

              height: dashHeight,

              child: DecoratedBox(
                decoration: BoxDecoration(color: context.colorBorder),
              ),
            );
          }),
        );
      },
    );
  }

  // --- PRO FIX: Premium "Boarding Pass" Style Receipt Dialog ---

  void _showReceiptDialog(Map<String, dynamic> appointment) {
    final doctorName = appointment['doctors']?['full_name'] ?? 'Unknown Doctor';

    final clinicName = appointment['clinics']?['name'] ?? 'Unknown Clinic';

    final date = _formatDate(appointment['schedule_date']);

    final time = _formatTimeRange(
      appointment['start_time'],

      appointment['end_time'],
    );

    final patientName = appointment['patient_name'] ?? 'Guest';

    final patientPhone = appointment['patient_phone'] ?? 'N/A';

    final status = appointment['status']?.toString().toUpperCase() ?? 'UNKNOWN';

    final bookingId = '#DP-${appointment['id'].toString().padLeft(4, '0')}';

    final GlobalKey receiptBoundaryKey = GlobalKey();

    bool isProcessing = false;

    showDialog(
      context: context,

      builder:
          (ctx) => StatefulBuilder(
            builder: (context, setDialogState) {
              final isDark = Theme.of(context).brightness == Brightness.dark;

              return Dialog(
                backgroundColor: Colors.transparent,

                elevation: 0,

                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 20,

                  vertical: 24,
                ),

                child: Container(
                  // The "Tray" background holding the ticket and buttons
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? const Color(0xFF1A1A1A)
                            : const Color(0xFFF3F4F6),

                    borderRadius: BorderRadius.circular(24),

                    // PRO FIX: Added the clean dialog border
                    border: Border.all(color: context.colorBorder, width: 1.2),
                  ),

                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,

                      children: [
                        // --- The Area Captured for the Image (The Official Ticket) ---
                        RepaintBoundary(
                          key: receiptBoundaryKey,

                          child: Container(
                            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),

                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,

                              borderRadius: BorderRadius.circular(20),

                              // PRO FIX: Added a subtle paper edge border
                              border: Border.all(
                                color: context.colorBorder.withValues(
                                  alpha: 0.5,
                                ),

                                width: 1,
                              ),

                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),

                                  blurRadius: 15,

                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),

                            child: Column(
                              mainAxisSize: MainAxisSize.min,

                              children: [
                                // 1. TICKET HEADER (Solid Branded Color)
                                Container(
                                  width: double.infinity,

                                  padding: const EdgeInsets.symmetric(
                                    vertical: 24,

                                    horizontal: 20,
                                  ),

                                  decoration: const BoxDecoration(
                                    color: AppColors.primaryGreen,

                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(20),
                                    ),
                                  ),

                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),

                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.2,
                                          ),

                                          shape: BoxShape.circle,
                                        ),

                                        child: const Icon(
                                          Icons.check_circle_outline_rounded,

                                          color: Colors.white,

                                          size: 36,
                                        ),
                                      ),

                                      const SizedBox(height: 12),

                                      const Text(
                                        "Confirmed Booking",

                                        style: TextStyle(
                                          color: Colors.white,

                                          fontSize: 20,

                                          fontWeight: FontWeight.bold,

                                          letterSpacing: 0.5,
                                        ),
                                      ),

                                      const SizedBox(height: 4),

                                      Text(
                                        status == 'COMPLETED'
                                            ? "Visit Completed"
                                            : "Scheduled Visit",

                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.8,
                                          ),

                                          fontSize: 13,

                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // 2. TICKET BODY (Patient & Doctor Details)
                                Padding(
                                  padding: const EdgeInsets.all(24),

                                  child: Column(
                                    children: [
                                      _buildReceiptRow(
                                        context,

                                        "Patient",

                                        patientName,
                                      ),

                                      const SizedBox(height: 12),

                                      _buildReceiptRow(
                                        context,

                                        "Phone",

                                        patientPhone,
                                      ),

                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),

                                        child: _buildDashedDivider(context),
                                      ),

                                      _buildReceiptRow(
                                        context,

                                        "Doctor",

                                        doctorName,
                                      ),

                                      const SizedBox(height: 12),

                                      _buildReceiptRow(
                                        context,

                                        "Clinic",

                                        clinicName,
                                      ),

                                      const SizedBox(height: 12),

                                      _buildReceiptRow(context, "Date", date),

                                      const SizedBox(height: 12),

                                      _buildReceiptRow(context, "Time", time),
                                    ],
                                  ),
                                ),

                                // 3. TICKET TEAR-OFF LINE
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),

                                  child: _buildDashedDivider(context),
                                ),

                                // 4. TICKET FOOTER (Barcode & Ref)
                                Padding(
                                  padding: const EdgeInsets.all(24),

                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,

                                    crossAxisAlignment: CrossAxisAlignment.end,

                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,

                                        children: [
                                          Text(
                                            "Reference Number",

                                            style: TextStyle(
                                              color: context.colorTextLight,

                                              fontSize: 12,

                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),

                                          const SizedBox(height: 6),

                                          Text(
                                            bookingId,

                                            style: TextStyle(
                                              color: context.colorTextDark,

                                              fontWeight: FontWeight.w900,

                                              fontSize: 20,

                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        ],
                                      ),

                                      // Fake Scannable QR Code to look professional
                                      Icon(
                                        Icons.qr_code_2_rounded,

                                        size: 48,

                                        color: context.colorTextDark.withValues(
                                          alpha: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // --- The Action Buttons (Stacked Vertically Below the Ticket) ---
                        Padding(
                          padding: const EdgeInsets.all(24.0),

                          child: Column(
                            children: [
                              SizedBox(
                                width: double.infinity,

                                child: ElevatedButton.icon(
                                  onPressed:
                                      isProcessing
                                          ? null
                                          : () async {
                                            setDialogState(
                                              () => isProcessing = true,
                                            );

                                            try {
                                              await Future.delayed(
                                                const Duration(
                                                  milliseconds: 150,
                                                ),
                                              );

                                              RenderRepaintBoundary boundary =
                                                  receiptBoundaryKey
                                                          .currentContext!
                                                          .findRenderObject()
                                                      as RenderRepaintBoundary;

                                              ui.Image image = await boundary
                                                  .toImage(pixelRatio: 3.0);

                                              ByteData? byteData = await image
                                                  .toByteData(
                                                    format:
                                                        ui.ImageByteFormat.png,
                                                  );

                                              Uint8List pngBytes =
                                                  byteData!.buffer
                                                      .asUint8List();

                                              final directory =
                                                  await getTemporaryDirectory();

                                              final file =
                                                  await File(
                                                    '${directory.path}/DaktarPai_$bookingId.png',
                                                  ).create();

                                              await file.writeAsBytes(pngBytes);

                                              // PRO FIX: Flawless SharePlus syntax with ShareParams

                                              await SharePlus.instance.share(
                                                ShareParams(
                                                  files: [XFile(file.path)],

                                                  subject:
                                                      'Appointment Receipt $bookingId',

                                                  text:
                                                      'My appointment booking receipt ($bookingId)',
                                                ),
                                              );
                                            } catch (e) {
                                              debugPrint("Share Error: $e");

                                              if (ctx.mounted) {
                                                CustomSnackbar.showError(
                                                  ctx,

                                                  "Could not generate receipt file.",
                                                );
                                              }
                                            } finally {
                                              if (ctx.mounted) {
                                                setDialogState(
                                                  () => isProcessing = false,
                                                );
                                              }
                                            }
                                          },

                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryGreen,

                                    foregroundColor: Colors.white,

                                    elevation: 0,

                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),

                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),

                                  icon:
                                      isProcessing
                                          ? const SizedBox(
                                            width: 18,

                                            height: 18,

                                            child: CircularProgressIndicator(
                                              color: Colors.white,

                                              strokeWidth: 2,
                                            ),
                                          )
                                          : const Icon(
                                            Icons.share_rounded,

                                            size: 20,
                                          ),

                                  label: Text(
                                    isProcessing
                                        ? "Generating..."
                                        : "Share Receipt",

                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,

                                      fontSize: 16,

                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              SizedBox(
                                width: double.infinity,

                                child: TextButton(
                                  onPressed:
                                      isProcessing
                                          ? null
                                          : () => Navigator.pop(ctx),

                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),

                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),

                                  child: Text(
                                    "Close",

                                    style: TextStyle(
                                      color: context.colorTextLight,

                                      fontWeight: FontWeight.w600,

                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
    );
  }

  // Helper for receipt row

  Widget _buildReceiptRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Text(
          label,

          style: TextStyle(color: context.colorTextLight, fontSize: 14),
        ),

        const SizedBox(width: 16),

        Expanded(
          child: Text(
            value,

            textAlign: TextAlign.right,

            style: TextStyle(
              color: context.colorTextDark,

              fontSize: 14,

              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _showActionSheet(Map<String, dynamic> appointment) {
    final String doctorName = appointment['doctors']?['full_name'] ?? "Doctor";

    bool canCancel = true;

    try {
      final dateStr = appointment['schedule_date'].toString().split('T')[0];

      final startTimeStr = appointment['start_time'].toString();

      final startDateTime = DateTime.parse('$dateStr $startTimeStr');

      final timeDifference = startDateTime.difference(DateTime.now());

      if (timeDifference.inHours < 4) {
        canCancel = false;
      }
    } catch (e) {
      debugPrint("Error parsing time for cancellation check: $e");
    }

    showModalBottomSheet(
      context: context,

      useRootNavigator: true,

      isScrollControlled: true,

      backgroundColor: Theme.of(context).colorScheme.surface,

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
                        color: context.colorBorder,

                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      "Manage Appointment",

                      style: TextStyle(
                        fontSize: 18,

                        fontWeight: FontWeight.w600,

                        color: context.colorTextDark,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      "With $doctorName",

                      style: TextStyle(
                        color: context.colorTextLight,

                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 24),

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
                      padding: const EdgeInsets.symmetric(vertical: 8.0),

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
                      padding: const EdgeInsets.symmetric(vertical: 8.0),

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
                      padding: const EdgeInsets.symmetric(vertical: 8.0),

                      child: Divider(color: context.colorBorder),
                    ),

                    // --- CANCEL BUTTON ---
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);

                        if (canCancel) {
                          _confirmCancellation(appointment);
                        } else {
                          CustomSnackbar.showError(
                            context,

                            "Appointments cannot be canceled within 4 hours of the scheduled time. Please contact support or the clinic directly.",
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
                                color:
                                    canCancel
                                        ? AppColors.dangerRed.withValues(
                                          alpha: 0.1,
                                        )
                                        : Colors.grey.withValues(alpha: 0.1),

                                shape: BoxShape.circle,
                              ),

                              child: Icon(
                                Icons.close,

                                color:
                                    canCancel
                                        ? AppColors.dangerRed
                                        : Colors.grey,

                                size: 20,
                              ),
                            ),

                            const SizedBox(width: 16),

                            Text(
                              "Cancel Appointment",

                              style: TextStyle(
                                fontWeight: FontWeight.w600,

                                fontSize: 16,

                                color:
                                    canCancel
                                        ? AppColors.dangerRed
                                        : Colors.grey,
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

            backgroundColor: Theme.of(context).colorScheme.surface,

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

                  Text(
                    "Cancel Appointment?",

                    textAlign: TextAlign.center,

                    style: TextStyle(
                      fontSize: 20,

                      fontWeight: FontWeight.bold,

                      color: context.colorTextDark,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    "Are you sure you want to cancel this appointment? This action cannot be undone.",

                    textAlign: TextAlign.center,

                    style: TextStyle(
                      color: context.colorTextLight,

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

                  insetPadding: const EdgeInsets.symmetric(
                    horizontal: 24,

                    vertical: 24,
                  ),

                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),

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

                        const SizedBox(height: 8),

                        Text(
                          "With ${appointment['doctors']?['full_name'] ?? 'Doctor'}",

                          style: TextStyle(
                            fontSize: 14,

                            color: context.colorTextLight,
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

                        AppTextField(
                          controller: commentController,

                          maxLines: 3,

                          hintText: "Write your review here (optional)...",
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

                                child: Text(
                                  "Cancel",

                                  style: TextStyle(
                                    color: context.colorTextLight,
                                  ),
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
                ),
              );
            },
          ),
    ).whenComplete(() => commentController.dispose());
  }

  Widget _buildActionRequiredCarousel() {
    final pendingItems = _appointmentNotifier.actionRequiredItems;

    if (pendingItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),

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

        const SizedBox(height: 12),

        SizedBox(
          height: 150,

          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24),

            scrollDirection: Axis.horizontal,

            itemCount: pendingItems.length,

            separatorBuilder: (_, __) => const SizedBox(width: 16),

            itemBuilder: (context, index) {
              final appt = pendingItems[index];

              final doctor = appt['doctors'] ?? {};

              final isMissed = appt['status'] == 'missed';

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

                          backgroundImage:
                              doctor['profile_picture_url'] != null &&
                                      doctor['profile_picture_url'].isNotEmpty
                                  ? CachedNetworkImageProvider(
                                    doctor['profile_picture_url'],
                                  )
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

                          style: const TextStyle(fontWeight: FontWeight.bold),
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

        const SizedBox(height: 24),
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

              // PRO FIX: Removed the isLoading check.

              // Now it stays visible during silent background refreshes!
              _buildActionRequiredCarousel(),

              Expanded(
                child:
                    (_appointmentNotifier.isLoading &&
                            _appointmentNotifier.appointments.isEmpty)
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

  // --- PRO FIX: Clean Typographic Header with History Route ---
  Widget _buildAppBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "Appointments", 
            style: AppTextStyles.h1(context).copyWith(
              fontSize: 26, 
              letterSpacing: -0.5,
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? AppColors.darkBorder : context.colorBorder,
              ),
              boxShadow: AppStyles.cardShadow(context),
            ),
            child: IconButton(
              icon: Icon(Icons.history_rounded, color: context.colorTextDark, size: 22),
              onPressed: () => context.push(AppRoutes.accountActivity),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingBanner() {
    return Container(
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
    );
  }

  Widget _buildListView() {
    final appointments = _appointmentNotifier.appointments;

    return RefreshIndicator(
      onRefresh: _appointmentNotifier.fetchAppointments,

      color: AppColors.primaryGreen,

      backgroundColor: Theme.of(context).colorScheme.surface,

      child:
          appointments.isEmpty
              ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),

                padding: const EdgeInsets.symmetric(horizontal: 24),

                children: [
                  const SizedBox(height: 16),

                  _buildRefreshHint(),

                  const SizedBox(height: 24),

                  _buildUpcomingBanner(),

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

                        const SizedBox(height: 16),

                        Text(
                          "No upcoming appointments",

                          style: TextStyle(
                            fontSize: 16,

                            fontWeight: FontWeight.w600,

                            color: context.colorTextLight,
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

                itemCount: appointments.length + 2,

                separatorBuilder:
                    (context, index) => const SizedBox(height: 16),

                itemBuilder: (context, index) {
                  if (index == 0) return _buildRefreshHint();

                  if (index == 1) {
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),

                          child: _buildUpcomingBanner(),
                        ),

                        if (NetworkNotifier.instance.isOffline)
                          _buildOfflineWarningBanner(),
                      ],
                    );
                  }

                  final apt = appointments[index - 2].toJson();

                  final doctor = apt['doctors'] as Map<String, dynamic>? ?? {};

                  final String specialty =
                      (doctor['specialty'] != null &&
                              doctor['specialty'].toString().isNotEmpty)
                          ? doctor['specialty'].toString()
                          : "Specialist";

                  final currentClinicId = apt['clinic_id'];

                  final formattedBookingId =
                      '#DP-${apt['id'].toString().padLeft(4, '0')}';

                  int waitTime = 30;

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

                  return AppointmentCard(
                    bookingId: formattedBookingId,

                    name: doctor['full_name'] ?? "Unknown Doctor",

                    specialty: specialty,

                    date: _formatDate(apt['schedule_date']),

                    time: _formatTimeRange(apt['start_time'], apt['end_time']),

                    imageUrl: doctor['profile_picture_url'] ?? "",

                    status: apt['status'] ?? 'pending',

                    scheduleDate: apt['schedule_date'],

                    startTime: apt['start_time'],

                    maxWaitTime: waitTime,

                    onTap: () {},

                    onMoreTap: () => _showActionSheet(apt),

                    onReceiptTap: () => _showReceiptDialog(apt),
                  );
                },
              ),
    );
  }

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
