import 'dart:async';
import 'dart:ui' as ui;
import 'dart:io';
import 'dart:typed_data';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/material.dart';
import '../../../../core/widgets/volumetric_scaffold.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/services/appointment_notification_service.dart';
import '../../../../presentation/widgets/app_floating_dialog.dart';
import 'package:flutter/services.dart';
import '../../../../core/widgets/app_loader.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';
import '../appointment_notifier.dart';
import '../../../../presentation/widgets/appointment_card.dart';
import '../../../../presentation/widgets/primary_button.dart';
import '../../../../presentation/widgets/app_network_image.dart'; // <-- Missing Import Added
import 'package:uuid/uuid.dart';
import '../models/booking_route_args.dart';
import '../../../../presentation/widgets/complaint_dialog.dart';
import '../../../menu/presentation/widgets/review_dialog.dart';
import '../../../../core/network/network_notifier.dart';
import '../../../../features/medical_records/data/medical_record_repository.dart';

class MyAppointmentsScreen extends StatefulWidget {
  final bool isBackgroundLayer;

  const MyAppointmentsScreen({super.key, this.isBackgroundLayer = false});

  @override
  State<MyAppointmentsScreen> createState() => _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends State<MyAppointmentsScreen> {
  final Uuid _uuid = const Uuid();
  final _appointmentNotifier = AppointmentNotifier.instance;
  AppointmentsRouteArgs? _lastProcessedArgs;
  bool _hasEverLoaded = false;

  @override
  void initState() {
    super.initState();

    if (!widget.isBackgroundLayer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _appointmentNotifier.initializeRealtime();
        unawaited(_appointmentNotifier.fetchAppointments());
      });
    }

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
        _appointmentNotifier.fetchAppointments(isBackground: true);
      }
    }
  }

  void _onNotifierChanged() {
    if (mounted) {
      // PRO FIX: Mark as loaded once any data arrives
      if (!_hasEverLoaded && _appointmentNotifier.appointments.isNotEmpty) {
        _hasEverLoaded = true;
      }
      if (!_hasEverLoaded && !_appointmentNotifier.isLoading) {
        _hasEverLoaded = true; // Even empty result = loaded
      }
      setState(() {});
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra;
    if (extra is AppointmentsRouteArgs &&
        extra.refresh &&
        extra != _lastProcessedArgs) {
      _lastProcessedArgs = extra;
      _appointmentNotifier.fetchAppointments();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        CustomSnackbar.showSuccess(context, "Appointment Successful!");
      });
    }
  }

  // --- CARD ACTION LOGIC ---
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

  void _confirmCancellation(Map<String, dynamic> appointment) {
    HapticFeedback.mediumImpact();

    final List<String> reasons = [
      "Schedule conflict",
      "Found earlier appointment",
      "Feeling better",
      "Cost / Financial reasons",
      "Other",
    ];
    final otherController = TextEditingController();

    showDialog(
      context: context,
      useRootNavigator: true,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dialogCtx) {
        bool isCancelling = false;
        String? selectedReason;

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final isOther = selectedReason == "Other";

            return AppFloatingDialog(
              headerIcon: Icons.event_busy_rounded,
              iconColor: AppColors.dangerRed,
              title: "Cancel Appointment?",
              description: "Please let us know why you are canceling.",
              isUpdating: isCancelling,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...reasons.map(
                    (reason) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setDialogState(() => selectedReason = reason);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: selectedReason == reason
                                ? AppColors.primaryGreen.withOpacity(0.1)
                                : (isDark
                                    ? Colors.white12
                                    : Colors.black.withOpacity(0.04)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selectedReason == reason
                                  ? AppColors.primaryGreen
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                selectedReason == reason
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                color: selectedReason == reason
                                    ? AppColors.primaryGreen
                                    : Colors.grey,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  reason,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (isOther) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: otherController,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      decoration: InputDecoration(
                        hintText: "Briefly explain...",
                        hintStyle: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        filled: true,
                        fillColor: isDark ? Colors.black26 : Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed:
                          isCancelling ? null : () => Navigator.pop(dialogCtx),
                      child: const Text(
                        "Back",
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: PrimaryButton(
                      label: "Confirm",
                      backgroundColor: selectedReason == null
                          ? Colors.grey
                          : AppColors.dangerRed,
                      onTap: isCancelling || selectedReason == null
                          ? () {}
                          : () async {
                              final finalReason = isOther
                                  ? otherController.text.trim()
                                  : selectedReason!;
                              final reasonToSend = finalReason.isEmpty
                                  ? "Other"
                                  : finalReason;

                              setDialogState(() => isCancelling = true);
                              try {
                                await _appointmentNotifier.cancelAppointment(
                                  appointment['id'],
                                  reasonToSend,
                                );
                                await AppointmentNotificationService.instance
                                    .cancelReminder(appointment['id']);
                                if (dialogCtx.mounted) {
                                  Navigator.pop(dialogCtx);
                                }
                                if (mounted) {
                                  CustomSnackbar.showSuccess(
                                    context,
                                    "Appointment Cancelled",
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  CustomSnackbar.showError(
                                    context,
                                    "Failed to cancel.",
                                  );
                                }
                              } finally {
                                if (ctx.mounted) {
                                  setDialogState(() => isCancelling = false);
                                }
                              }
                            },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(otherController.dispose);
  }

  void _addToCalendar(Map<String, dynamic> appointment) {
    try {
      final doctorName = appointment['doctors']?['full_name'] ?? "Doctor";
      final dateStr = appointment['schedule_date'].toString().split('T')[0];
      final startTimeStr = appointment['start_time'].toString();
      final endTimeStr = appointment['end_time']?.toString() ?? startTimeStr;

      final startDateTime = DateTime.parse('$dateStr $startTimeStr');
      final endDateTime = DateTime.parse('$dateStr $endTimeStr');

      final event = Event(
        title: 'Appointment with $doctorName',
        description: 'Medical appointment booked via AeviaPulse.',
        location: appointment['clinics']?['name'] ?? 'Clinic',
        startDate: startDateTime,
        endDate: endDateTime,
      );
      Add2Calendar.addEvent2Cal(event);
    } catch (e) {
      CustomSnackbar.showError(context, "Could not parse appointment time.");
    }
  }

  bool _canCancel(Map<String, dynamic> appointment) {
    try {
      final dateStr = appointment['schedule_date'].toString().split('T')[0];
      final startTimeStr = appointment['start_time'].toString();
      final startDateTime = DateTime.parse('$dateStr $startTimeStr');
      return startDateTime.difference(DateTime.now()).inHours >= 4;
    } catch (e) {
      return false;
    }
  }

  // --- RECEIPT DIALOG ---
  Widget _buildDashedDivider(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        final dashCount = (boxWidth / 14).floor();
        return Flex(
          direction: Axis.horizontal,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            dashCount,
            (_) => SizedBox(
              width: 8,
              height: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.colorBorder.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReceiptRow(
    BuildContext context,
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: context.colorTextLight,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color:
                    isHighlight
                        ? AppColors.primaryGreen
                        : context.colorTextDark,
                fontSize: isHighlight ? 16 : 14,
                fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReceiptDialog(Map<String, dynamic> appointment) {
    HapticFeedback.selectionClick();
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
              return BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Dialog(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  insetPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RepaintBoundary(
                            key: receiptBoundaryKey,
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.fromLTRB(
                                      24,
                                      32,
                                      24,
                                      24,
                                    ),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primaryGreen,
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(24),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.2,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.verified_rounded,
                                            color: Colors.white,
                                            size: 40,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        const Text(
                                          "Appointment Confirmed",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            status,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      24,
                                      24,
                                      24,
                                      8,
                                    ),
                                    child: Column(
                                      children: [
                                        _buildReceiptRow(
                                          context,
                                          "Patient",
                                          patientName,
                                        ),
                                        _buildReceiptRow(
                                          context,
                                          "Phone",
                                          patientPhone,
                                        ),
                                        _buildReceiptRow(
                                          context,
                                          "Date",
                                          date,
                                          isHighlight: true,
                                        ),
                                        _buildReceiptRow(
                                          context,
                                          "Time",
                                          time,
                                          isHighlight: true,
                                        ),
                                        _buildReceiptRow(
                                          context,
                                          "Doctor",
                                          doctorName,
                                        ),
                                        _buildReceiptRow(
                                          context,
                                          "Clinic",
                                          clinicName,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 8,
                                    ),
                                    child: _buildDashedDivider(context),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Booking ID",
                                              style: TextStyle(
                                                color: context.colorTextLight,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              bookingId,
                                              style: TextStyle(
                                                color: context.colorTextDark,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 22,
                                                letterSpacing: 1.0,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color:
                                                isDark
                                                    ? Colors.white10
                                                    : Colors.black.withValues(
                                                      alpha: 0.05,
                                                    ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.qr_code_2_rounded,
                                            size: 50,
                                            color: context.colorTextDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed:
                                      isProcessing
                                          ? null
                                          : () => Navigator.pop(ctx),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    backgroundColor:
                                        Theme.of(context).colorScheme.surface,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Text(
                                    "Close",
                                    style: TextStyle(
                                      color: context.colorTextDark,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: PrimaryButton(
                                  onTap:
                                      isProcessing
                                          ? () {}
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
                                                    '${directory.path}/AeviaPulse_$bookingId.png',
                                                  ).create();
                                              await file.writeAsBytes(pngBytes);
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
                                              if (ctx.mounted) {
                                                CustomSnackbar.showError(
                                                  ctx,
                                                  "Could not generate receipt.",
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
                                  label: isProcessing ? "Processing" : "Share",
                                  icon:
                                      isProcessing
                                          ? null
                                          : Icons.ios_share_rounded,
                                  customIcon:
                                      isProcessing
                                          ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: AppLoader(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                          : null,
                                  backgroundColor: AppColors.primaryGreen,
                                  borderRadius: 16,
                                  height: 54,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
    );
  }

  // --- 1. THE FRIENDLY ACTION BAR ---
  Widget _buildAppBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16), 
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "Your Schedule",
            style: AppTextStyles.h2(context).copyWith(
              fontSize: 24, 
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: isDark ? Colors.white : const Color(0xFF1D1D1F),
            ),
          ),
          
          Material(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.primaryGreen.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                context.push(AppRoutes.accountActivity);
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.history_rounded, size: 16, color: isDark ? Colors.white : AppColors.primaryGreen),
                    const SizedBox(width: 6),
                    Text(
                      "History",
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.primaryGreen,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. THE UNIFIED VIP CAROUSEL ---
  Widget _buildActionRequiredCarousel() {
    final pendingItems = _appointmentNotifier.actionRequiredItems;
    if (pendingItems.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: AppColors.dangerRed, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.dangerRed.withValues(alpha: 0.4), blurRadius: 4)]),
              ),
              const SizedBox(width: 8),
              Text(
                "ACTION REQUIRED",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: isDark ? Colors.white54 : const Color(0xFF86868B)),
              ),
            ],
          ),
        ),
        SizedBox(
          // REVERTED: Back to your strict original layout height
          height: 100, 
          child: ListView.separated(
            // THE FIX: Allows the shadow to freely bleed out of the 100px box and paint over the empty space below it
            clipBehavior: Clip.none, 
            // REVERTED: Back to your original sleek padding
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), 
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: pendingItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final appt = pendingItems[index];
              final isMissed = appt['status'] == 'missed';
              
              final themeColor = isMissed ? AppColors.dangerRed : Colors.amber.shade600;
              final actionText = isMissed ? "Resolve" : "Review";
              final statusText = isMissed ? "Missed Visit" : "Rate Your Visit";
              
              final doctor = appt['doctors'] as Map<String, dynamic>? ?? {};
              final doctorName = doctor['full_name'] ?? 'Doctor';
              final imageUrl = doctor['profile_picture_url'] ?? '';

              return Container(
                width: MediaQuery.of(context).size.width * 0.85, 
                decoration: BoxDecoration(
                  color: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
                  borderRadius: BorderRadius.circular(24), 
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04), 
                    width: 1,
                  ),
                  boxShadow: isDark ? [] : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04), 
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: themeColor.withValues(alpha: 0.15), width: 2)),
                      child: ClipOval(
                        child: imageUrl.isNotEmpty
                            ? AppNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover)
                            : Icon(Icons.person, color: Colors.grey[400], size: 24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              doctorName,
                              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1D1D1F), fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.3),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            statusText,
                            style: TextStyle(color: themeColor, fontSize: 13, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Material(
                      color: themeColor.withValues(alpha: 0.1), 
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias, 
                      elevation: 0, 
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          if (isMissed) {
                            showDialog(context: context, barrierDismissible: false, builder: (ctx) => ComplaintDialog(appointment: appt, onComplaintSubmitted: () => _appointmentNotifier.removePendingComplaint(appt['id'])));
                          } else {
                            showDialog(context: context, barrierDismissible: false, useRootNavigator: true, builder: (ctx) => ReviewDialog(appointment: appt, onReviewSubmitted: () => _appointmentNotifier.removePendingReview(appt['id'])));
                          }
                        },
                        highlightColor: Colors.transparent, 
                        splashColor: themeColor.withValues(alpha: 0.2), 
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Text(
                            actionText,
                            style: TextStyle(color: themeColor, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.2),
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
        // The shadow will now physically overlap into this empty space below it!
        const SizedBox(height: 4), 
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return VolumetricScaffold(
      // THE FIX: A perfectly uniform, solid background color for the entire page. Zero gradients.
      tier: VolumetricTier.base,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAppBar(),
            _buildActionRequiredCarousel(),
            if (NetworkNotifier.instance.isOffline)
              _buildOfflineWarningBanner(),
            Expanded(
              child: ClipRect(
                child:
                    (_appointmentNotifier.isLoading &&
                            !_hasEverLoaded &&
                            _appointmentNotifier.appointments.isEmpty)
                        ? const Center(
                          child: AppLoader(color: AppColors.primaryGreen),
                        )
                        : _buildDynamicTimeline(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicTimeline() {
    final appointments = _appointmentNotifier.appointments;
    final dynamicBottomPadding = MediaQuery.paddingOf(context).bottom + 20;

    return RefreshIndicator(
      onRefresh: _appointmentNotifier.fetchAppointments,
      color: AppColors.primaryGreen,
      backgroundColor: Theme.of(context).colorScheme.surface,
      child:
          appointments.isEmpty
              ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(24, 0, 24, dynamicBottomPadding),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withOpacity(0.05),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.event_available_rounded,
                            size: 56,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Your schedule is clear',
                          style: AppTextStyles.h2(context),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Upcoming appointments will appear here.',
                          style: TextStyle(
                            fontSize: 14,
                            color: context.colorTextLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
              : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(24, 16, 24, dynamicBottomPadding),
                itemCount: appointments.length,
                separatorBuilder: (_, __) => const SizedBox(height: 20),
                itemBuilder: (context, index) {
                  final apt = appointments[index].toJson();
                  final doctor = apt['doctors'] as Map<String, dynamic>? ?? {};
                  final currentClinicId = apt['clinic_id'];
                  final formattedBookingId =
                      '#DP-${apt['id'].toString().padLeft(4, '0')}';
                  int waitTime = 30;

                  if (doctor['doctor_clinics'] != null) {
                    final docClinicsList =
                        doctor['doctor_clinics'] as List<dynamic>;
                    for (final dc in docClinicsList) {
                      if (dc['clinic_id'] == currentClinicId) {
                        waitTime = dc['max_wait_time'] ?? 30;
                        break;
                      }
                    }
                  }

                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(
                      milliseconds: 300 + (index * 40).clamp(0, 300),
                    ),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: Opacity(opacity: value, child: child),
                      );
                    },
                    child: AppointmentCard(
                      bookingId: formattedBookingId,
                      name: doctor['full_name'] ?? 'Unknown',
                      specialty:
                          doctor['specialty']?.toString() ?? 'Specialist',
                      date: _formatDate(apt['schedule_date']),
                      time: _formatTimeRange(
                        apt['start_time'],
                        apt['end_time'],
                      ),
                      imageUrl: doctor['profile_picture_url'] ?? '',
                      status: apt['status'] ?? 'pending',
                      scheduleDate: apt['schedule_date'],
                      startTime: apt['start_time'],
                      maxWaitTime: waitTime,
                      canCancel: _canCancel(apt),
                      onReceiptTap: () => _showReceiptDialog(apt),
                      onCalendarTap: () => _addToCalendar(apt),
                      onRescheduleTap: () => _handleReschedule(apt),
                      onCancelTap: () {
                        if (_canCancel(apt)) {
                          _confirmCancellation(apt);
                        } else {
                          CustomSnackbar.showError(
                            context,
                            'Cannot cancel within 4 hours. Contact support.',
                          );
                        }
                      },
                      onLocationTap: () {
                        final docId = doctor['id'];
                        if (docId != null) {
                          context.push(
                            AppRoutes.doctorDetailsById('$docId') + '?scrollToMap=true',
                            extra: doctor,
                          );
                        }
                      },
                    ),
                  );
                },
              ),
    );
  }

  String _formatDate(String? d) {
    if (d == null) return "";
    try {
      return DateFormat('EEEE, MMM d').format(DateTime.parse(d));
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
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
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
              "You are offline. Live wait times will update when you reconnect.",
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

class SoftPressButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scaleDown;
  final double pressedOpacity;

  const SoftPressButton({
    super.key,
    required this.child,
    required this.onTap,
    this.scaleDown = 0.95,
    this.pressedOpacity = 0.6,
  });

  @override
  State<SoftPressButton> createState() => _SoftPressButtonState();
}

class _SoftPressButtonState extends State<SoftPressButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isValidTap = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
      reverseDuration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    _isValidTap = true;
    HapticFeedback.lightImpact();
    _controller.forward();
  }

  void _onPointerUp(PointerUpEvent event) {
    if (!_isValidTap) return;

    HapticFeedback.selectionClick();
    _controller.reverse();

    Future<void>.delayed(const Duration(milliseconds: 50), () {
      if (!mounted) return;
      widget.onTap();
    });

    _isValidTap = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_isValidTap && event.localDelta.distance > 10) {
      _isValidTap = false;
      _controller.reverse();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _isValidTap = false;
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerMove: _onPointerMove,
      onPointerCancel: _onPointerCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final double currentScale =
              1.0 - (_controller.value * (1.0 - widget.scaleDown));
          final double currentOpacity =
              1.0 - (_controller.value * (1.0 - widget.pressedOpacity));

          return Transform.scale(
            scale: currentScale,
            alignment: Alignment.center,
            child: Opacity(opacity: currentOpacity, child: widget.child),
          );
        },
      ),
    );
  }
}
