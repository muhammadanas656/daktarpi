import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../features/appointments/data/appointment_repository.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';
import '../../../../presentation/widgets/app_text_field.dart';

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
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected 
              ? activeColor.withValues(alpha: 0.1) 
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : context.colorBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? activeColor : Colors.grey, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? activeColor : context.colorTextDark,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colorTextLight,
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.report_problem_outlined,
                      color: Colors.deepOrange,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "File a Complaint",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.colorTextDark,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),

              Text(
                "Who would you like to contact?",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: context.colorTextDark,
                ),
              ),
              SizedBox(height: 12),

              _buildSelectionCard(
                "Directly to $doctorName",
                "Message the doctor or clinic directly regarding this visit.",
                Icons.person_outline,
                'doctor',
              ),
              SizedBox(height: 12),
              _buildSelectionCard(
                "DaktarPai Support",
                "Report app issues, payment errors, or platform disputes.",
                Icons.support_agent,
                'support',
              ),

              SizedBox(height: 24),
              Text(
                "Details",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: context.colorTextDark,
                ),
              ),
              SizedBox(height: 8),

              AppTextField(
                controller: _commentController,
                maxLines: 4,
                hintText: "Please explain what went wrong...",
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
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
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
