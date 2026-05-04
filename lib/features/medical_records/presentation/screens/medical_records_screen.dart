import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:open_filex/open_filex.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/security/biometric_auth_service.dart';
import '../../../../features/auth/data/trusted_device_repository.dart';
import '../../../../features/medical_records/data/medical_record.dart';
import '../../../../features/medical_records/data/medical_record_repository.dart';
import '../../../../features/profile/data/profile_repository.dart';
import '../../../../presentation/widgets/app_floating_dialog.dart';
import '../models/medical_record_route_args.dart';
import '../../../../presentation/widgets/primary_button.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';
import '../../../settings/presentation/settings_notifier.dart'; // IMPORTED
import '../widgets/record_card.dart';
import '../../../../presentation/widgets/app_network_image.dart';
import '../../../../core/network/network_notifier.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../presentation/widgets/app_bottom_tray.dart';

class MedicalRecordsScreen extends StatefulWidget {
  const MedicalRecordsScreen({super.key});

  @override
  State<MedicalRecordsScreen> createState() => _MedicalRecordsScreenState();
}

class _MedicalRecordsScreenState extends State<MedicalRecordsScreen>
    with WidgetsBindingObserver {
  final MedicalRecordRepository _repository = MedicalRecordRepository();
  final BiometricAuthService _biometricService = BiometricAuthService();
  final TrustedDeviceRepository _deviceRepo = TrustedDeviceRepository();
  final ProfileRepository _profileRepo = ProfileRepository();

  List<MedicalRecord> _records = [];
  bool _isLoading = true;
  bool _hasEverLoaded = false;
  String? _errorMessage;
  String _selectedCategory = "All";
  List<String> _categories = ["All", "My Self"];
  final Map<String, String?> _patientAvatars = {};
  bool _isOpeningRecordEditor = false;

  // REMOVED local _isProtected variable to use global SettingsNotifier instead
  bool _hasSecurityConfigured = false;

  // Real-time subscription for live DB updates
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkSecurityConfiguration();
    _fetchRecords();
    _loadCategories();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _teardownRealtimeSubscription();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      // Force a fresh fetch when the app returns to foreground
      _fetchRecords(forceRefresh: true);
    }
  }

  void _setupRealtimeSubscription() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    _realtimeChannel = _repository.subscribeToRecords(
      userId: userId,
      onChange: (_) => _onRealtimeChange(),
    );
  }

  void _teardownRealtimeSubscription() {
    final channel = _realtimeChannel;
    _realtimeChannel = null;
    if (channel != null) {
      _repository.removeChannel(channel);
    }
  }

  /// Called by the real-time listener whenever the DB changes.
  /// Invalidates the cache and re-fetches so the UI always shows truth.
  Future<void> _onRealtimeChange() async {
    if (!mounted) return;
    await _repository.invalidateCache();
    await _fetchRecords();
  }

  Future<void> _loadCategories() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final profile = await _profileRepo.getProfile(userId);
    _patientAvatars["My Self"] = profile?.profilePictureUrl;

    final patients = await _profileRepo.getSavedPatients(userId);
    final dynamicCategories = ["All", "My Self"];

    for (final patient in patients) {
      final relation = patient['relation']?.toString();
      if (relation != null && relation != "My Self") {
        dynamicCategories.add(relation);
        _patientAvatars[relation] = patient['image_path']?.toString();
      }
    }

    if (mounted) {
      setState(() {
        _categories = dynamicCategories.toSet().toList();
        if (!_categories.contains(_selectedCategory)) {
          _selectedCategory = "All";
        }
      });
    }
  }

  Future<void> _checkSecurityConfiguration() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return;
    }

    final isBiometricEnabled = await _deviceRepo.isBiometricEnabledForDevice(
      userId: user.id,
    );

    if (mounted) {
      setState(() {
        _hasSecurityConfigured = isBiometricEnabled;
      });
    }
  }

  Future<void> _fetchRecords({bool forceRefresh = false}) async {
    if (!mounted) return;
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

      // Invalidate cache when explicitly requested (realtime event, app resume)
      if (forceRefresh) {
        await _repository.invalidateCache();
      }

      final records = await _repository.fetchRecords();
      if (mounted) {
        setState(() {
          _records = records;
          _isLoading = false;
          _hasEverLoaded = true;
          _errorMessage = null;
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
          _fetchRecords(forceRefresh: true);
        }
      }
    }
  }

  String _getCleanFileName(String path) {
    return path
        .split(RegExp(r'[\\/]'))
        .last
        .replaceFirst(RegExp(r'^\d+_'), '');
  }

  Future<void> _deleteRecord(MedicalRecord record) async {
    if (_isRecordLocked(record)) {
      _showLockedRecordMessage(record);
      return;
    }
    await showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dialogCtx) {
        bool isDeleting = false;

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AppFloatingDialog(
              headerIcon: Icons.delete_forever_rounded,
              iconColor: AppColors.dangerRed,
              title: "Delete Record?",
              description:
                  "Are you sure you want to delete this record? This action cannot be undone.",
              isUpdating: isDeleting,
              content: const SizedBox.shrink(),
              actions: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed:
                          isDeleting ? null : () => Navigator.pop(dialogCtx),
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
                      label: "Delete",
                      backgroundColor: AppColors.dangerRed,
                      onTap:
                          isDeleting
                              ? () {}
                              : () async {
                                setDialogState(() => isDeleting = true);
                                try {
                                  await _repository.deleteRecord(record);
                                  if (dialogCtx.mounted) {
                                    Navigator.pop(dialogCtx);
                                  }
                                  if (mounted) {
                                    CustomSnackbar.showSuccess(
                                      context,
                                      "Record deleted successfully",
                                    );
                                    _fetchRecords(forceRefresh: true);
                                  }
                                } on AppFailure catch (e) {
                                  if (dialogCtx.mounted) {
                                    Navigator.pop(dialogCtx);
                                  }
                                  if (mounted) {
                                    CustomSnackbar.showError(
                                      context,
                                      e.userMessage,
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    CustomSnackbar.showError(
                                      context,
                                      "Failed to delete: $e",
                                    );
                                  }
                                } finally {
                                  if (ctx.mounted) {
                                    setDialogState(() => isDeleting = false);
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
    );
  }

  void _showSetupSuggestion() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dialogCtx) {
        return AppFloatingDialog(
          headerIcon: Icons.security_rounded,
          iconColor: AppColors.primaryGreen,
          title: "Secure Your Records",
          description:
              "Protect your medical records for extra security by enabling Biometrics in Settings.",
          isUpdating: false,
          content: const SizedBox.shrink(),
          actions: Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text(
                    "Later",
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
                  label: "Settings",
                  onTap: () {
                    Navigator.pop(dialogCtx);
                    context.push(AppRoutes.settings);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openRecordEditor({MedicalRecord? record}) async {
    if (_isOpeningRecordEditor || !mounted) return;

    _isOpeningRecordEditor = true;
    try {
      final routeUri = Uri(
        path: AppRoutes.addMedicalRecord,
        queryParameters: {
          'mode': record == null ? 'new' : 'edit',
          'nonce': DateTime.now().microsecondsSinceEpoch.toString(),
        },
      ).toString();

      final result = await context.push(
        routeUri,
        extra: MedicalRecordRouteArgs(record: record),
      );
      if (result == true && mounted) {
        _fetchRecords();
        _loadCategories();
      }
    } finally {
      _isOpeningRecordEditor = false;
    }
  }

  void _editRecord(MedicalRecord record) async {
    if (_isRecordLocked(record)) {
      _showLockedRecordMessage(record);
      return;
    }
    await _openRecordEditor(record: record);
  }

  bool _isRecordLocked(MedicalRecord record) {
    final lockedUntil = record.lockedUntil;
    return lockedUntil != null && lockedUntil.isAfter(DateTime.now());
  }

  void _showLockedRecordMessage(MedicalRecord record) {
    final remaining = record.lockedUntil!.difference(DateTime.now());
    final days = remaining.inDays;
    final hours = remaining.inHours % 24;
    String timeStr;
    if (days > 0) {
      timeStr = '$days day${days > 1 ? 's' : ''}, $hours hour${hours != 1 ? 's' : ''}';
    } else {
      timeStr = '$hours hour${hours != 1 ? 's' : ''}';
    }
    CustomSnackbar.showError(
      context,
      'This record is locked for medical review. Unlocks in $timeStr.',
    );
  }

  Future<void> _viewFile(MedicalRecord record) async {
    if (record.fileUrls.isEmpty) return;

    Future<void> openPath(String path) async {
      try {
        final isImage = [
          'jpg',
          'jpeg',
          'png',
          'heic',
        ].contains(path.split('.').last.toLowerCase());

        final isOffline = NetworkNotifier.instance.isOffline;
        final localFile = await _repository.getLocalAttachmentFile(path);

        if (isOffline && localFile == null) {
          if (mounted) {
            CustomSnackbar.showError(
              context,
              "You need internet to download this file for the first time.",
            );
          }
          return;
        }

        String? networkUrl;
        if (!isOffline && localFile == null) {
          networkUrl = await _repository.getSignedUrl(path);
          unawaited(_repository.cacheRemoteFile(path, signedUrl: networkUrl));
        }

        if (isImage) {
          if (!mounted) return;
          await showDialog(
            context: context,
            builder: (dialogCtx) {
              final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
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
                        maxHeight: MediaQuery.of(dialogCtx).size.height * 0.7,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(dialogCtx).colorScheme.surface,
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
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final imageChild =
                                localFile != null
                                    ? Image.file(
                                      localFile,
                                      fit: BoxFit.contain,
                                      gaplessPlayback: true,
                                    )
                                    : AppNetworkImage(
                                      imageUrl: networkUrl,
                                      cacheKey: path,
                                      width: constraints.maxWidth,
                                      height: constraints.maxHeight,
                                      fit: BoxFit.contain,
                                    );

                            return InteractiveViewer(
                              child: SizedBox(
                                width: constraints.maxWidth,
                                height: constraints.maxHeight,
                                child: imageChild,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Positioned(
                      top: -12,
                      right: -12,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(dialogCtx),
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

        File? fileToOpen = localFile;
        if (fileToOpen == null) {
          if (mounted) {
            CustomSnackbar.showInfo(context, "Downloading file...");
          }
          fileToOpen = await _repository.cacheRemoteFile(
            path,
            signedUrl: networkUrl,
          );
        }

        if (fileToOpen == null) {
          throw Exception('Failed to download file');
        }

        final result = await OpenFilex.open(fileToOpen.path);
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
    return AnimatedBuilder(
      animation: SettingsNotifier.instance,
      builder: (context, child) {
        final isLocked = SettingsNotifier.instance.medicalRecordsLocked;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          extendBodyBehindAppBar: true,
          extendBody: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: CustomAppBar(
            title: "Medical Records",
            actions: [
              if (_hasSecurityConfigured)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: IconButton(
                    icon: Icon(
                      isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                      color: isLocked ? AppColors.primaryGreen : Colors.grey,
                    ),
                    onPressed: _toggleProtection,
                  ),
                ),
            ],
          ),
          body: RefreshIndicator(
            color: AppColors.primaryGreen,
            onRefresh: () => _fetchRecords(forceRefresh: true),
            edgeOffset: MediaQuery.paddingOf(context).top + kToolbarHeight,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.only(
                    top: MediaQuery.paddingOf(context).top + kToolbarHeight + 17,
                  ),
                ),
                _buildSliverBody(isLocked),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
          bottomNavigationBar: isLocked ? null : AppBottomTray(
            child: PrimaryButton(
              label: "Add a record",
              height: 54,
              borderRadius: 16,
              onTap: _openRecordEditor,
            ),
          ),
        );
      },
    );
  }



  Widget _buildSliverBody(bool isLocked) {
    if (_isLoading && !_hasEverLoaded) {
      return const SliverFillRemaining(child: AppLoader(color: AppColors.primaryGreen));
    }
    if (_errorMessage != null) {
      return SliverFillRemaining(child: Center(child: Text(_errorMessage!)));
    }

    if (isLocked) {
      return SliverFillRemaining(hasScrollBody: false, child: _buildProtectedState());
    }

    if (_records.isEmpty) {
      return SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState());
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filteredRecords =
        _selectedCategory == "All"
            ? _records
            : _records
                .where((record) => record.recordFor == _selectedCategory)
                .toList();

    return SliverMainAxisGroup(
      slivers: [
        if (_categories.length > 2)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = _selectedCategory == category;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedCategory = category);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? AppColors.primaryGreen
                                : (isDark
                                    ? Colors.white10
                                    : Colors.black.withValues(alpha: 0.04)),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color:
                              isSelected
                                  ? Colors.transparent
                                  : context.colorBorder,
                        ),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          color:
                              isSelected ? Colors.white : context.colorTextLight,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        if (_categories.length > 2)
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        if (filteredRecords.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 120),
              child: Center(
                child: Text(
                  "No records found for $_selectedCategory.",
                  style: TextStyle(color: context.colorTextLight, fontSize: 14),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final record = filteredRecords[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: RecordCard(
                      record: record,
                      patientAvatarUrl: _patientAvatars[record.recordFor],
                      onTap: () => _viewFile(record),
                      onEdit: () => _editRecord(record),
                      onDelete: () => _deleteRecord(record),
                      onFileTap: () => _viewFile(record),
                    ),
                  );
                },
                childCount: filteredRecords.length,
              ),
            ),
          ),
      ],
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
          const SizedBox(height: 20),
          // THE FIX: Synchronized typography with h2 and tight tracking
          Text(
            "Records Protected", 
            style: AppTextStyles.h2(context).copyWith(letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          Text(
            "Verify your identity to view records.",
            style: TextStyle(color: context.colorTextLight, fontSize: 14),
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
          // THE FIX: Synchronized typography with h2 and tight tracking
          Text(
            "No Records Found", 
            style: AppTextStyles.h2(context).copyWith(letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          Text(
            "Add a medical record to track your health.",
            style: TextStyle(color: context.colorTextLight, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

