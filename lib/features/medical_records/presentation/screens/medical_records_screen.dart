import 'package:flutter/material.dart';
import 'dart:io';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/security/biometric_auth_service.dart';
import '../../../../features/auth/data/trusted_device_repository.dart';
import '../../../../features/medical_records/data/medical_record.dart';
import '../../../../features/medical_records/data/medical_record_repository.dart';
import '../models/medical_record_route_args.dart';
import '../../../../presentation/widgets/primary_button.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';
import '../../../settings/presentation/settings_notifier.dart'; // IMPORTED
import '../widgets/record_card.dart';
import '../../../../presentation/widgets/app_network_image.dart';
import '../../../../core/network/network_notifier.dart';

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

  // REMOVED local _isProtected variable to use global SettingsNotifier instead
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

    // Access global state from the Notifier
    final isCurrentlyLocked = SettingsNotifier.instance.medicalRecordsLocked;
    final reason =
        isCurrentlyLocked
            ? 'Unlock your medical records'
            : 'Protect your medical records';

    final authenticated = await _biometricService.authenticate(
      localizedReason: reason,
    );

    if (authenticated && mounted) {
      // Update global persistent state
      await SettingsNotifier.instance.updateMedicalRecordsLock(
        !isCurrentlyLocked,
      );

      if (mounted) {
        CustomSnackbar.showSuccess(
          context,
          SettingsNotifier.instance.medicalRecordsLocked
              ? "Records protected"
              : "Records unlocked",
        );
        if (!SettingsNotifier.instance.medicalRecordsLocked) {
          _fetchRecords();
        }
      }
    }
  }

  void _showSetupSuggestion() {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text("Secure Your Records"),
            content: Text(
              "Protect your medical records for extra security by enabling 2FA or Biometrics in Settings.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text("Later"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push(AppRoutes.settings);
                },
                child: Text("Go to Settings"),
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
            title: Text("Delete Record?"),
            content: Text(
              "Are you sure you want to delete this record? This action cannot be undone.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text("Delete", style: TextStyle(color: Colors.red)),
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
    if (record.fileUrls.isEmpty) return;

    Future<void> openPath(String path) async {
      try {
        final isImage = [
          'jpg',
          'jpeg',
          'png',
        ].contains(path.split('.').last.toLowerCase());

        // PRO FIX: OFFLINE CACHE SYSTEM
        // Check the local app directory for the file before hitting the network
        final dir = await getApplicationDocumentsDirectory();
        final fileName = _getCleanFileName(path);
        final localFile = File('${dir.path}/$fileName');
        final bool existsLocally = await localFile.exists();

        final isOffline = NetworkNotifier.instance.isOffline;

        if (isOffline && !existsLocally) {
          if (mounted) {
            CustomSnackbar.showError(
              context,
              "You need internet to download this file for the first time.",
            );
          }
          return;
        }

        String? networkUrl;
        if (!isOffline) {
          networkUrl = await _repository.getSignedUrl(path);
        }

        // PRO FIX: Background Caching. If we are online and don't have it locally, save it forever!
        if (!isOffline && !existsLocally && networkUrl != null) {
          http.get(Uri.parse(networkUrl)).then((response) {
            if (response.statusCode == 200) {
              localFile.writeAsBytes(response.bodyBytes);
            }
          });
        }

        if (isImage) {
          if (!mounted) return;
          await showDialog(
            context: context,
            builder: (_) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 40,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topRight,
                  children: [
                    Container(
                      width: double.infinity,
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.7,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color:
                              isDark ? AppColors.darkBorder : Colors.grey[300]!,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: InteractiveViewer(
                          // PRO FIX: Instantly load the local file if it exists
                          child:
                              existsLocally
                                  ? Image.file(localFile, fit: BoxFit.contain)
                                  : AppNetworkImage(
                                    imageUrl: networkUrl,
                                    cacheKey: path,
                                    fit: BoxFit.contain,
                                  ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: -12,
                      right: -12,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.dangerRed,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  isDark
                                      ? const Color(0xFF1E1E1E)
                                      : Colors.white,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.dangerRed.withValues(
                                  alpha: 0.4,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
          return;
        }

        // PRO FIX: Handling non-image documents (PDFs) offline
        if (existsLocally) {
          final result = await OpenFilex.open(localFile.path);
          if (result.type != ResultType.done && mounted) {
            CustomSnackbar.showError(
              context,
              "Could not open file: ${result.message}",
            );
          }
        } else {
          if (mounted) CustomSnackbar.showInfo(context, "Downloading file...");
          final response = await http.get(Uri.parse(networkUrl!));
          if (response.statusCode == 200) {
            await localFile.writeAsBytes(response.bodyBytes);
            final result = await OpenFilex.open(localFile.path);
            if (result.type != ResultType.done && mounted) {
              CustomSnackbar.showError(
                context,
                "Could not open file: ${result.message}",
              );
            }
          } else {
            throw Exception('Failed to download file');
          }
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder:
            (context) => Container(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Attached Files", style: AppTextStyles.h3(context)),
                  SizedBox(height: 16),
                  ...record.fileUrls.asMap().entries.map((entry) {
                    final index = entry.key;
                    final path = entry.value;
                    final isImage = [
                      'jpg',
                      'jpeg',
                      'png',
                    ].contains(path.split('.').last.toLowerCase());

                    return Container(
                      margin: EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color:
                            Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkSurface
                                : Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primaryGreen.withValues(alpha: 0.2),
                        ),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isImage
                                ? Icons.image_rounded
                                : Icons.description_rounded,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                        title: Text(
                          "Document ${index + 1}",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          _getCleanFileName(path),
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Icon(
                          Icons.open_in_new_rounded,
                          size: 20,
                          color: AppColors.primaryGreen,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          openPath(path);
                        },
                      ),
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
    // Listen to SettingsNotifier for persistent protection state
    return AnimatedBuilder(
      animation: SettingsNotifier.instance,
      builder: (context, child) {
        final isLocked = SettingsNotifier.instance.medicalRecordsLocked;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text("Medical Records", style: AppTextStyles.h2(context)),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => context.pop(),
              color: context.colorTextDark,
            ),
            actions: [
              if (_hasSecurityConfigured)
                IconButton(
                  icon: Icon(
                    isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                    color: isLocked ? AppColors.primaryGreen : Colors.grey,
                  ),
                  onPressed: _toggleProtection,
                ),
            ],
          ),
          body: _buildBody(isLocked),
          bottomNavigationBar: isLocked ? null : _buildBottomBar(),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: AppStyles.cardShadow(context),
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

  Widget _buildBody(bool isLocked) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      );
    }
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }

    // UI reacts to persistent lock state
    if (isLocked) {
      return _buildProtectedState();
    }

    if (_records.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      itemCount: _records.length,
      itemBuilder: (context, index) {
        final record = _records[index];
        return Padding(
          padding: EdgeInsets.only(bottom: 16),
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
          SizedBox(height: 16),
          Text("Records Protected", style: AppTextStyles.h3(context)),
          SizedBox(height: 8),
          Text(
            "Verify your identity to view records.",
            style: TextStyle(color: context.colorTextLight),
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
            child: Icon(
              Icons.folder_open_rounded,
              size: 60,
              color: AppColors.primaryGreen,
            ),
          ),
          SizedBox(height: 24),
          Text("No Records Found", style: AppTextStyles.h3(context)),
          SizedBox(height: 8),
          Text(
            "Add a medical record to track your health.",
            style: TextStyle(color: context.colorTextLight),
          ),
        ],
      ),
    );
  }
}
