import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../features/medical_records/data/medical_record.dart';
import '../../../../features/medical_records/data/medical_record_repository.dart';
import '../../../../presentation/widgets/primary_button.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';
import '../widgets/record_card.dart';

class MedicalRecordsScreen extends StatefulWidget {
  const MedicalRecordsScreen({super.key});

  @override
  State<MedicalRecordsScreen> createState() => _MedicalRecordsScreenState();
}

class _MedicalRecordsScreenState extends State<MedicalRecordsScreen> {
  final _repository = MedicalRecordRepository();
  List<MedicalRecord> _records = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchRecords();
  }

  Future<void> _fetchRecords() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final records = await _repository.fetchRecords();
      if (mounted) {
        setState(() {
          _records = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteRecord(MedicalRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Record?"),
        content: const Text("Are you sure you want to delete this record? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _repository.deleteRecord(record.id, record.fileUrls);
        if (mounted) {
          CustomSnackbar.showSuccess(context, "Record deleted successfully");
          _fetchRecords();
        }
      } catch (e) {
        if (mounted) {
          CustomSnackbar.showError(context, "Failed to delete: $e");
        }
      }
    }
  }

  void _editRecord(MedicalRecord record) async {
    final result = await context.push(AppRoutes.addMedicalRecord, extra: record);
    if (result == true && mounted) {
      _fetchRecords();
    }
  }

  Future<void> _viewFile(MedicalRecord record) async {
    if (record.fileUrls.isEmpty) return;

    Future<void> launchPath(String path) async {
      try {
        final url = await _repository.getSignedUrl(path);
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) CustomSnackbar.showError(context, "Could not open file.");
        }
      } catch (e) {
        if (mounted) CustomSnackbar.showError(context, "Error opening file: $e");
      }
    }

    if (record.fileUrls.length == 1) {
      launchPath(record.fileUrls.first);
    } else {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Attached Files", style: AppTextStyles.h3),
              const SizedBox(height: 16),
              ...record.fileUrls.asMap().entries.map((entry) {
                final index = entry.key;
                final path = entry.value;
                return ListTile(
                  leading: const Icon(Icons.description, color: AppColors.primaryGreen),
                  title: Text("Document ${index + 1}"),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () {
                    Navigator.pop(context);
                    launchPath(path);
                  },
                );
              }),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text("Medical Records", style: AppTextStyles.h2),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
          color: AppColors.textDark,
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
        ],
      ),
      bottomNavigationBar: Container(
         padding: const EdgeInsets.all(24),
         decoration: BoxDecoration(
           color: Colors.white,
           boxShadow: [
             BoxShadow(
               color: Colors.black.withValues(alpha: 0.05),
               blurRadius: 10,
               offset: const Offset(0, -5),
             ),
           ],
         ),
         child: SafeArea(
           child: PrimaryButton(
             label: "Add a record",
             onTap: () async {
               final result = await context.push(AppRoutes.addMedicalRecord);
               if (!mounted) return;
               if (result == true) {
                 _fetchRecords();
               }
             },
           ),
         ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text("Error: $_errorMessage"),
            ElevatedButton(
              onPressed: _fetchRecords,
              child: const Text("Retry"),
            )
          ],
        ),
      );
    }

    if (_records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.folder_open_rounded,
                size: 60,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "No Records Found",
              style: AppTextStyles.h3,
            ),
            const SizedBox(height: 8),
            const Text(
              "Add a medical record to keep track of your health.",
              style: TextStyle(color: AppColors.textLight),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      itemCount: _records.length,
      itemBuilder: (context, index) {
        final record = _records[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: RecordCard(
            record: record,
            onTap: () {}, // Disabled as per user request (only open on Edit)
            onEdit: () => _editRecord(record),
            onDelete: () => _deleteRecord(record),
            onFileTap: () => _viewFile(record),
          ),
        );
      },
    );
  }
}
