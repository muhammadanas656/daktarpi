import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';
import '../../../../presentation/widgets/app_text_field.dart';
import '../../../../presentation/widgets/primary_button.dart';
import '../../../../presentation/widgets/app_floating_dialog.dart'; // Core wrapper
import '../../../appointments/data/appointment_repository.dart';
import '../../../appointments/presentation/appointment_notifier.dart';

class ReviewDialog extends StatefulWidget {
  final Map<String, dynamic> appointment;
  final VoidCallback onReviewSubmitted;

  const ReviewDialog({
    super.key,
    required this.appointment,
    required this.onReviewSubmitted,
  });

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  int _selectedRating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;
  final AppointmentRepository _repository = AppointmentRepository();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_selectedRating == 0) {
      CustomSnackbar.showError(context, "Please select a star rating first.");
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _repository.submitReview(
        appointmentId: widget.appointment['id'],
        doctorId: widget.appointment['doctor_id'],
        rating: _selectedRating,
        comment: _commentController.text.trim(),
      );

      AppointmentNotifier.instance.removePendingReview(
        widget.appointment['id'],
      );

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        CustomSnackbar.showSuccess(context, "Thank you for your feedback!");
        widget.onReviewSubmitted();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        CustomSnackbar.showError(context, "Error: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppFloatingDialog(
      headerIcon: Icons.star_rate_rounded,
      iconColor: Colors.amber,
      title: "Rate Your Experience",
      description:
          "With ${widget.appointment['doctors']?['full_name'] ?? 'Doctor'}",
      isUpdating:
          _isSubmitting, // Automatically handles the loading spinner & lock!
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < _selectedRating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: Colors.amber,
                    size: 40,
                  ),
                  onPressed: () => setState(() => _selectedRating = index + 1),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _commentController,
            maxLines: 4,
            hintText: "Write your review here...",
          ),
        ],
      ),
      actions: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: _isSubmitting ? null : () => Navigator.pop(context),
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
              onTap: _isSubmitting ? () {} : _submitReview,
              backgroundColor: AppColors.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }
}
