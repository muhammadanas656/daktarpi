import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../features/appointments/data/appointment_repository.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';

class ComplaintDialog extends StatefulWidget {
  final Map<String, dynamic> appointment;
  final VoidCallback onComplaintSubmitted;

  const ComplaintDialog({
    super.key,
    required this.appointment,
    required this.onComplaintSubmitted,
  });

  @override
  State<ComplaintDialog> createState() => _ComplaintDialogState();
}

class _ComplaintDialogState extends State<ComplaintDialog> {
  final _repository = AppointmentRepository();
  final _commentController = TextEditingController();

  bool _isSubmitting = false;
  String _selectedRecipient = 'doctor'; // Default selection

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_commentController.text.trim().isEmpty) {
      CustomSnackbar.showError(context, "Please provide some details.");
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _repository.submitComplaint(
        appointmentId: widget.appointment['id'],
        doctorId:
            widget.appointment['doctor_id'] ??
            widget.appointment['doctors']['id'],
        description: _commentController.text.trim(),
        recipient: _selectedRecipient,
      );

      if (mounted) {
        Navigator.pop(context);
        CustomSnackbar.showSuccess(
          context,
          "Your complaint has been sent securely.",
        );
        widget.onComplaintSubmitted();
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, e.toString());
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildSelectionCard(
    String title,
    String subtitle,
    IconData icon,
    String value,
  ) {
    final isSelected = _selectedRecipient == value;
    final activeColor = value == 'support' ? Colors.blue : Colors.deepOrange;

    return GestureDetector(
      onTap: () => setState(() => _selectedRecipient = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : AppColors.borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? activeColor : Colors.grey, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? activeColor : AppColors.textDark,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: activeColor, size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doctorName = widget.appointment['doctors']?['full_name'] ?? 'Doctor';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.report_problem_outlined,
                      color: Colors.deepOrange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "File a Complaint",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              const Text(
                "Who would you like to contact?",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),

              _buildSelectionCard(
                "Directly to $doctorName",
                "Message the doctor or clinic directly regarding this visit.",
                Icons.person_outline,
                'doctor',
              ),
              const SizedBox(height: 12),
              _buildSelectionCard(
                "DaktarPai Support",
                "Report app issues, payment errors, or platform disputes.",
                Icons.support_agent,
                'support',
              ),

              const SizedBox(height: 24),
              const Text(
                "Details",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),

              TextField(
                controller: _commentController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: "Please explain what went wrong...",
                  hintStyle: const TextStyle(
                    color: AppColors.hintText,
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Colors.deepOrange,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed:
                          _isSubmitting ? null : () => Navigator.pop(context),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(color: AppColors.textLight),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child:
                          _isSubmitting
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
  }
}
