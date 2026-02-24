import 'package:flutter/material.dart';
import 'dart:io';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/security/biometric_auth_service.dart';
import '../../../../features/auth/data/trusted_device_repository.dart';
import '../../../../features/medical_records/data/medical_record.dart';
import '../../../../features/medical_records/data/medical_record_repository.dart';
import '../models/medical_record_route_args.dart';
import '../../../../presentation/widgets/primary_button.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';
import '../widgets/record_card.dart';

class MedicalRecordsScreen extends StatefulWidget {
  const MedicalRecordsScreen({super.key});

  @override
  State<MedicalRecordsScreen> createState() => _MedicalRecordsScreenState();
}

class _MedicalRecordsScreenState extends State<MedicalRecordsScreen> {
  final MedicalRecordRepository _repository = MedicalRecordRepository();
  final BiometricAuthService _biometricService = BiometricAuthService();
  final TrustedDeviceRepository _deviceRepo = TrustedDeviceRepository();

  List<MedicalRecord> _records = [];
  bool _isLoading = true;
  String? _errorMessage;

  bool _isProtected = false;
  bool _hasSecurityConfigured = false;

  @override
  void initState() {
    super.initState();
    _checkSecurityConfiguration();
    _fetchRecords();
  }

  Future<void> _checkSecurityConfiguration() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return;
    }

    final is2faEnabled = user.appMetadata['is_2fa_enabled'] == true;
    final isBiometricEnabled = await _deviceRepo.isBiometricEnabledForDevice(
      userId: user.id,
    );

    if (mounted) {
      setState(() {
        _hasSecurityConfigured = is2faEnabled || isBiometricEnabled;
      });
    }
  }

  Future<void> _fetchRecords() async {
    if (!mounted) {
      return;
    }
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _errorMessage = "Please log in to view records.";
            _isLoading = false;
          });
        }
        return;
      }

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

  Future<void> _toggleProtection() async {
    if (!_hasSecurityConfigured) {
      _showSetupSuggestion();
      return;
    }

    final reason =
        _isProtected
            ? 'Unlock your medical records'
            : 'Protect your medical records';
    final authenticated = await _biometricService.authenticate(
      localizedReason: reason,
    );

    if (authenticated && mounted) {
      setState(() {
        _isProtected = !_isProtected;
      });
      CustomSnackbar.showSuccess(
        context,
        _isProtected ? "Records protected" : "Records unlocked",
      );
    }
  }

  void _showSetupSuggestion() {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text("Secure Your Records"),
            content: const Text(
              "Protect your medical records for extra security by enabling 2FA or Biometrics in Settings.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Later"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push(AppRoutes.settings);
                },
                child: const Text("Go to Settings"),
              ),
            ],
          ),
    );
  }

  String _getCleanFileName(String path) {
    return path.split('/').last.replaceFirst(RegExp(r'^\d+_'), '');
  }

  Future<void> _deleteRecord(MedicalRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Delete Record?"),
            content: const Text(
              "Are you sure you want to delete this record? This action cannot be undone.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  "Delete",
                  style: TextStyle(color: Colors.red),
                ),
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
    final result = await context.push(
      AppRoutes.addMedicalRecord,
      extra: MedicalRecordRouteArgs(record: record),
    );
    if (result == true && mounted) {
      _fetchRecords();
    }
  }

  Future<void> _viewFile(MedicalRecord record) async {
    if (record.fileUrls.isEmpty) {
      return;
    }

    Future<void> openPath(String path) async {
      try {
        final isImage = [
          'jpg',
          'jpeg',
          'png',
        ].contains(path.split('.').last.toLowerCase());

        final url = await _repository.getSignedUrl(path);

        if (isImage) {
          if (!mounted) {
            return;
          }
          await showDialog(
            context: context,
            builder:
                (_) => Dialog(
                  backgroundColor: Colors.transparent,
                  child: Stack(
                    alignment: Alignment.topRight,
                    children: [
                      InteractiveViewer(
                        child: Image.network(
                          url,
                          loadingBuilder: (_, child, progress) {
                            return progress == null
                                ? child
                                : const Center(
                                  child: CircularProgressIndicator(),
                                );
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
          );
          return;
        }

        if (mounted) {
          CustomSnackbar.showInfo(context, "Opening file...");
        }

        final response = await http.get(Uri.parse(url));
        if (response.statusCode != 200) {
          throw Exception('Failed to download file');
        }

        final dir = await getTemporaryDirectory();
        final fileName = _getCleanFileName(path);
        final file = File('${dir.path}/$fileName');

        await file.writeAsBytes(response.bodyBytes);

        final result = await OpenFilex.open(file.path);
        if (result.type != ResultType.done && mounted) {
          CustomSnackbar.showError(
            context,
            "Could not open file: ${result.message}",
          );
        }
      } catch (e) {
        if (mounted) {
          CustomSnackbar.showError(context, "Error opening file: $e");
        }
      }
    }

    if (record.fileUrls.length == 1) {
      openPath(record.fileUrls.first);
    } else {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder:
            (context) => Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Attached Files", style: AppTextStyles.h3),
                  const SizedBox(height: 16),
                  ...record.fileUrls.asMap().entries.map((entry) {
                    final path = entry.value;
                    final isImage = [
                      'jpg',
                      'jpeg',
                      'png',
                    ].contains(path.split('.').last.toLowerCase());

                    return ListTile(
                      leading: Icon(
                        isImage ? Icons.image : Icons.description,
                        color: AppColors.primaryGreen,
                      ),
                      title: Text(_getCleanFileName(path)),
                      trailing: const Icon(Icons.open_in_new, size: 18),
                      onTap: () {
                        Navigator.pop(context);
                        openPath(path);
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
        actions: [
          if (_hasSecurityConfigured)
            IconButton(
              icon: Icon(
                _isProtected ? Icons.lock_rounded : Icons.lock_open_rounded,
                color: _isProtected ? AppColors.primaryGreen : Colors.grey,
              ),
              onPressed: _toggleProtection,
            ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _isProtected ? null : _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    return Container(
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
            if (result == true && mounted) {
              _fetchRecords();
            }
          },
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      );
    }
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }
    if (_isProtected) {
      return _buildProtectedState();
    }
    if (_records.isEmpty) {
      return _buildEmptyState();
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
            onTap: () {},
            onEdit: () => _editRecord(record),
            onDelete: () => _deleteRecord(record),
            onFileTap: () => _viewFile(record),
          ),
        );
      },
    );
  }

  Widget _buildProtectedState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 80,
            color: AppColors.primaryGreen.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text("Records Protected", style: AppTextStyles.h3),
          const SizedBox(height: 8),
          const Text(
            "Verify your identity to view records.",
            style: TextStyle(color: AppColors.textLight),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
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
          Text("No Records Found", style: AppTextStyles.h3),
          const SizedBox(height: 8),
          const Text(
            "Add a medical record to track your health.",
            style: TextStyle(color: AppColors.textLight),
          ),
        ],
      ),
    );
  }
}
