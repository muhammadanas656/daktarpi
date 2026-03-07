import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';
import '../../../../presentation/widgets/app_text_field.dart';
import '../../../appointments/data/appointment_repository.dart';

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
    setState(() => _isSubmitting = true);
    try {
      await _repository.submitReview(
        appointmentId: widget.appointment['id'],
        doctorId: widget.appointment['doctor_id'],
        rating: _selectedRating,
        comment: _commentController.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        CustomSnackbar.showSuccess(
          context,
          "Thank you! Your review has been submitted.",
        );
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: SingleChildScrollView(
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
                "With ${widget.appointment['doctors']?['full_name'] ?? 'Doctor'}",
                style: TextStyle(fontSize: 14, color: context.colorTextLight),
              ),
              SizedBox(height: 24),
              Row(
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
                    onPressed:
                        () => setState(() => _selectedRating = index + 1),
                  );
                }),
              ),
              SizedBox(height: 16),
              AppTextField(
                controller: _commentController,
                maxLines: 3,
                hintText: "Write your review here (optional)...",
              ),
              SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed:
                          _isSubmitting ? null : () => Navigator.pop(context),
                      child: Text(
                        "Cancel",
                        style: TextStyle(color: context.colorTextLight),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          (_selectedRating == 0 || _isSubmitting)
                              ? null
                              : _submitReview,
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
                          _isSubmitting
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
  }
}
