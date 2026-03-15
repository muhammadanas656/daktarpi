import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'custom_snackbar.dart';
import 'app_text_field.dart';
import 'primary_button.dart';
import 'app_floating_dialog.dart'; // Core wrapper
import '../../features/appointments/presentation/appointment_notifier.dart';

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
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_commentController.text.trim().isEmpty) {
      CustomSnackbar.showError(context, "Please provide details.");
      return;
    }

    if (widget.appointment != null) {
      AppointmentNotifier.instance.submitComplaint(
        widget.appointment!,
        _commentController.text.trim(),
        widget.isSupportMode ? 'support' : 'doctor',
      );
    }

    Navigator.pop(context);
    CustomSnackbar.showSuccess(context, "Submitted successfully.");
    widget.onComplaintSubmitted();
  }

  @override
  Widget build(BuildContext context) {
    final brandColor =
        widget.isSupportMode ? AppColors.infoBlue : Colors.deepOrange;

    return AppFloatingDialog(
      headerIcon:
          widget.isSupportMode
              ? Icons.support_agent_rounded
              : Icons.report_problem_rounded,
      iconColor: brandColor,
      title: widget.isSupportMode ? "Contact Support" : "File a Complaint",
      description:
          widget.isSupportMode
              ? "Describe the issue you're facing with the platform or payment."
              : "Message the clinic directly regarding your visit.",
      isUpdating: false, // RAM-vault sync is instant
      content: AppTextField(
        controller: _commentController,
        maxLines: 4,
        hintText: "Enter details here...",
      ),
      actions: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Cancel",
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
              label: "Submit",
              onTap: _submit,
              backgroundColor: brandColor,
            ),
          ),
        ],
      ),
    );
  }
}
