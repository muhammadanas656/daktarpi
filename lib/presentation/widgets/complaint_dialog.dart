import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../features/appointments/data/appointment_repository.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';
import '../../../../presentation/widgets/app_text_field.dart';

class ComplaintDialog extends StatefulWidget {
  final Map<String, dynamic>? appointment;
  final VoidCallback onComplaintSubmitted;
  final bool isSupportMode;

  const ComplaintDialog({
    super.key,
    this.appointment,
    required this.onComplaintSubmitted,
    this.isSupportMode = false,
  });

  @override
  State<ComplaintDialog> createState() => _ComplaintDialogState();
}

class _ComplaintDialogState extends State<ComplaintDialog> {
  final _repository = AppointmentRepository();
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brandColor =
        widget.isSupportMode ? AppColors.infoBlue : Colors.deepOrange;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Theme.of(context).colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 24,
      ), // Prevents it from stretching too wide
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          // PRO FIX: Much softer, more premium border that looks great in Dark Mode
          border: Border.all(
            color: brandColor.withValues(alpha: isDark ? 0.2 : 0.1),
            width: 1.5,
          ),
          boxShadow: AppStyles.elevatedShadow(context),
        ),
        // PRO FIX: Added scrolling so the keyboard doesn't break the slick UI
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28), // Slightly more breathing room
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- PREMIUM GLOWING HEADER ---
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: brandColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  // PRO FIX: A beautiful "Halo" bloom effect behind the icon
                  boxShadow: [
                    BoxShadow(
                      color: brandColor.withValues(alpha: 0.25),
                      blurRadius: 24,
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: Icon(
                  widget.isSupportMode
                      ? Icons.support_agent_rounded
                      : Icons.report_problem_rounded,
                  color: brandColor,
                  size: 34,
                ),
              ),
              const SizedBox(height: 24),

              Text(
                widget.isSupportMode ? "Contact Support" : "File a Complaint",
                style: AppTextStyles.h2(context).copyWith(letterSpacing: 0.5),
              ),
              const SizedBox(height: 12),

              Text(
                widget.isSupportMode
                    ? "Describe the issue you're facing with the platform or payment."
                    : "Message the clinic directly regarding your visit.",
                textAlign: TextAlign.center,
                style: AppTextStyles.body(context).copyWith(
                  color: context.colorTextLight,
                  height: 1.4, // Better line height for readability
                ),
              ),
              const SizedBox(height: 28),

              // --- INPUT FIELD ---
              AppTextField(
                controller: _commentController,
                maxLines: 4,
                hintText: "Enter details here...",
              ),
              const SizedBox(height: 32),

              // --- ACTION BUTTONS ---
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed:
                          _isSubmitting ? null : () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        "Cancel",
                        style: TextStyle(
                          color: context.colorTextLight,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: AppStyles.primaryShadow(
                          context,
                          brandColor,
                          alpha: 0.35,
                        ),
                      ),
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child:
                            _isSubmitting
                                ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
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
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_commentController.text.trim().isEmpty) {
      CustomSnackbar.showError(context, "Please provide details.");
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await _repository.submitComplaint(
        appointmentId: widget.appointment?['id'],
        doctorId: widget.appointment?['doctor_id'],
        description: _commentController.text.trim(),
        recipient: widget.isSupportMode ? 'support' : 'doctor',
      );
      if (mounted) {
        Navigator.pop(context);
        CustomSnackbar.showSuccess(context, "Submitted successfully.");
        widget.onComplaintSubmitted();
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, e.toString());
        setState(() => _isSubmitting = false);
      }
    }
  }
}
