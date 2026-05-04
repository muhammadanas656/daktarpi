import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../presentation/widgets/app_text_field.dart';
import '../../../../presentation/widgets/app_floating_dialog.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';
import '../../../../presentation/widgets/primary_button.dart';
import '../../../../features/profile/data/profile_repository.dart';
import '../../data/medical_record.dart';
import '../../data/medical_record_repository.dart';
import '../../../../presentation/widgets/app_network_image.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/network/network_notifier.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../presentation/widgets/app_bottom_tray.dart';
import '../../../../presentation/widgets/app_bottom_tray.dart';

class AddRecordScreen extends StatefulWidget {
  final MedicalRecord? recordToEdit;
  const AddRecordScreen({super.key, this.recordToEdit});

  @override
  State<AddRecordScreen> createState() => _AddRecordScreenState();
}

class _AddRecordScreenState extends State<AddRecordScreen> {
  final _repository = MedicalRecordRepository();
  final ProfileRepository _profileRepo = ProfileRepository();

  String _selectedType = 'Report';
  DateTime _selectedDate = DateTime.now();

  final List<File> _selectedImages = [];
  final List<File> _selectedDocs = [];

  final List<String> _existingImageUrls = [];
  final List<String> _existingDocUrls = [];

  final _picker = ImagePicker();
  bool _isLoading = false;
  bool _isPickingAttachments = false;
  List<Map<String, dynamic>> _patientProfiles = [];
  String _selectedPatient = "My Self";
  String? _mySelfAvatarUrl;
  String? _managingCategory;

  final List<Map<String, dynamic>> _recordTypes = [
    {'type': 'Report', 'icon': Icons.analytics_outlined},
    {'type': 'Prescription', 'icon': Icons.medical_services_outlined},
    {'type': 'Invoice', 'icon': Icons.receipt_long_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _loadPatientProfiles();
    if (widget.recordToEdit != null) {
      final record = widget.recordToEdit!;
      _selectedType = record.recordType;
      _selectedDate = record.recordDate;

      for (var url in record.fileUrls) {
        if (_isImage(url)) {
          _existingImageUrls.add(url);
        } else {
          _existingDocUrls.add(url);
        }
      }
    }
  }

  Future<void> _loadPatientProfiles() async {
    final userId = _profileRepo.currentUserId;
    if (userId == null) return;

    final patients = await _profileRepo.getSavedPatients(userId);
    final myProfile = await _profileRepo.getProfile(userId);

    if (mounted) {
      final newProfiles =
          patients
              .where(
                (patient) =>
                    patient['relation']?.toString().isNotEmpty ?? false,
              )
              .toList();

      if (_patientProfiles.toString() != newProfiles.toString() ||
          _mySelfAvatarUrl != myProfile?.profilePictureUrl) {
        setState(() {
          _patientProfiles = newProfiles;
          _mySelfAvatarUrl = myProfile?.profilePictureUrl;
        });
      }
    }
  }

  bool _isImage(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'heic'].contains(ext);
  }

  String _getCleanFileName(String path) {
    final name = path.split(RegExp(r'[\\/]')).last;
    return name.replaceFirst(RegExp(r'^\d+_'), '');
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_isPickingAttachments) return;
    _isPickingAttachments = true;
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (!mounted) return;
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images.map((x) => File(x.path)));
        });
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, "Failed to pick images: $e");
      }
    } finally {
      _isPickingAttachments = false;
    }
  }

  Future<void> _takePhoto() async {
    if (_isPickingAttachments) return;
    _isPickingAttachments = true;
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (!mounted) return;
      if (photo != null) {
        setState(() {
          _selectedImages.add(File(photo.path));
        });
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, "Failed to capture photo: $e");
      }
    } finally {
      _isPickingAttachments = false;
    }
  }

  Future<void> _pickFiles() async {
    if (_isPickingAttachments) return;
    _isPickingAttachments = true;
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );

      if (!mounted) return;
      if (result != null) {
        setState(() {
          _selectedDocs.addAll(
            result.paths.map((path) => File(path!)).toList(),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, "Failed to pick files: $e");
      }
    } finally {
      _isPickingAttachments = false;
    }
  }

  // --- PRO FIX: Premium Bottom Sheet Design ---
  Future<void> _showImageOptions() async {
    final currentFocus = FocusManager.instance.primaryFocus;
    final bool isKeyboardOpen = currentFocus != null && currentFocus.hasFocus;

    if (isKeyboardOpen) {
      currentFocus.unfocus();
      await Future.delayed(const Duration(milliseconds: 300));
    }
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (ctx) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag Handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Upload Photo",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(ctx).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Choose an option to attach a medical document",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildBottomSheetOption(
                        context: ctx,
                        icon: Icons.camera_alt_rounded,
                        label: "Camera",
                        onTap: () {
                          Navigator.pop(ctx);
                          _takePhoto();
                        },
                      ),
                      _buildBottomSheetOption(
                        context: ctx,
                        icon: Icons.photo_library_rounded,
                        label: "Gallery",
                        onTap: () {
                          Navigator.pop(ctx);
                          _pickImages();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
          },
    );
  }

  Future<void> _handleAddNewCategory() async {
    final categoryController = TextEditingController();
    final nameController = TextEditingController();
    final categoryFocusNode = FocusNode();
    final nameFocusNode = FocusNode();
    File? selectedImage;
    bool isUploading = false;
    bool showMore = false;
    String selectedGender = "Male";
    DateTime? selectedDob;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder:
          (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
              final isDark = Theme.of(context).brightness == Brightness.dark;

              Future<void> closeDialog([Map<String, dynamic>? result]) async {
                categoryFocusNode.unfocus();
                nameFocusNode.unfocus();
                FocusManager.instance.primaryFocus?.unfocus();
                await Future.delayed(const Duration(milliseconds: 140));
                if (ctx.mounted) {
                  Navigator.pop(ctx, result);
                }
              }

              return AppFloatingDialog(
                headerIcon: Icons.person_add_rounded,
                iconColor: AppColors.primaryGreen,
                title: "Add New Patient",
                description: "Create a profile for this record.",
                isUpdating: isUploading,
                content: AnimatedSize(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.fastOutSlowIn,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () async {
                              categoryFocusNode.unfocus();
                              nameFocusNode.unfocus();
                              FocusManager.instance.primaryFocus?.unfocus();
                              await Future.delayed(const Duration(milliseconds: 140));
                              final picked = await _picker.pickImage(
                                source: ImageSource.gallery,
                              );
                              if (picked != null && ctx.mounted) {
                                setDialogState(
                                  () => selectedImage = File(picked.path),
                                );
                              }
                            },
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.primaryGreen,
                                  width: 1.5,
                                ),
                                image:
                                    selectedImage != null
                                        ? DecorationImage(
                                          image: FileImage(selectedImage!),
                                          fit: BoxFit.cover,
                                        )
                                        : null,
                              ),
                              child:
                                  selectedImage == null
                                      ? const Icon(
                                        Icons.add_a_photo_rounded,
                                        color: AppColors.primaryGreen,
                                        size: 22,
                                      )
                                      : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: AppTextField(
                              controller: categoryController,
                              focusNode: categoryFocusNode,
                              hintText: "Category (e.g. Son)",
                              autofocus: true,
                              onChanged: (val) {
                                if (val.length >= 2 && !showMore) {
                                  setDialogState(() => showMore = true);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      if (showMore) ...[
                        const SizedBox(height: 20),
                        Divider(color: context.colorBorder),
                        const SizedBox(height: 16),
                        AppTextField(
                          controller: nameController,
                          focusNode: nameFocusNode,
                          hintText: "Full Legal Name",
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () async {
                            FocusScope.of(context).unfocus();
                            categoryFocusNode.unfocus();
                            nameFocusNode.unfocus();
                            await Future.delayed(
                              const Duration(milliseconds: 140),
                            );
                            final date = await showDatePicker(
                              context: context,
                              initialDate:
                                  selectedDob ??
                                  DateTime.now().subtract(
                                    const Duration(days: 365 * 20),
                                  ),
                              firstDate: DateTime(1900),
                              lastDate: DateTime.now(),
                              builder: (context, child) {
                                final isDark =
                                    Theme.of(context).brightness ==
                                    Brightness.dark;
                                final baseFont =
                                    AppTextStyles.body(context).fontFamily;

                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    textTheme: Theme.of(
                                      context,
                                    ).textTheme.apply(fontFamily: baseFont),
                                    colorScheme: Theme.of(
                                      context,
                                    ).colorScheme.copyWith(
                                      primary: AppColors.primaryGreen,
                                      onPrimary: Colors.white,
                                      onSurface:
                                          isDark
                                              ? Colors.white
                                              : context.colorTextDark,
                                    ),
                                    dialogBackgroundColor:
                                        Theme.of(context).colorScheme.surface,
                                    dialogTheme: DialogTheme(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                    ),
                                    textButtonTheme: TextButtonThemeData(
                                      style: TextButton.styleFrom(
                                        foregroundColor:
                                            AppColors.primaryGreen,
                                        textStyle: TextStyle(
                                          fontFamily: baseFont,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (date != null) {
                              setDialogState(() => selectedDob = date);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: context.colorBorder),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  selectedDob == null
                                      ? "Select Date of Birth"
                                      : DateFormat(
                                        'dd MMM yyyy',
                                      ).format(selectedDob!),
                                  style: TextStyle(
                                    color:
                                        selectedDob == null
                                            ? context.colorTextLight
                                            : context.colorTextDark,
                                    fontSize: 15,
                                    fontWeight:
                                        selectedDob == null
                                            ? FontWeight.w400
                                            : FontWeight.w500,
                                  ),
                                ),
                                Icon(
                                  Icons.calendar_month_rounded,
                                  color: context.colorTextLight,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? AppColors.darkSurface
                                    : const Color(0xFFF5F6F8),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: ["Male", "Female", "Others"].map((g) {
                              final isSelected = selectedGender == g;
                              return Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setDialogState(() => selectedGender = g);
                                  },
                                  behavior: HitTestBehavior.opaque,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.fastOutSlowIn,
                                    margin: EdgeInsets.only(
                                      right: g == "Others" ? 0 : 8,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryGreen.withValues(
                                        alpha: isSelected ? 1.0 : 0.0,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                              AppColors.primaryGreen.withValues(
                                                alpha: isSelected ? 0.3 : 0.0,
                                              ),
                                          blurRadius: isSelected ? 8 : 0,
                                          offset:
                                              isSelected
                                                  ? const Offset(0, 2)
                                                  : Offset.zero,
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: AnimatedDefaultTextStyle(
                                      duration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      curve: Curves.fastOutSlowIn,
                                      style: TextStyle(
                                        fontFamily:
                                            AppTextStyles.body(
                                              context,
                                            ).fontFamily,
                                        color:
                                            isSelected
                                                ? Colors.white
                                                : context.colorTextGrey,
                                        fontWeight:
                                            isSelected
                                                ? FontWeight.bold
                                                : FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                      child: Text(g),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () => setDialogState(() => showMore = true),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Text(
                                "Add full details",
                                style: TextStyle(
                                  color: AppColors.primaryGreen,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: AppColors.primaryGreen,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => closeDialog(),
                        child: const Text("Cancel"),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: PrimaryButton(
                        label: "Save",
                        height: 54,
                        borderRadius: 16,
                        onTap: () async {
                          if (categoryController.text.trim().isEmpty) return;

                          setDialogState(() => isUploading = true);
                          String? imageUrl;

                          if (selectedImage != null) {
                            try {
                              final userId = _profileRepo.currentUserId;
                              if (userId != null) {
                                imageUrl = await _profileRepo.uploadPatientPicture(
                                  userId,
                                  categoryController.text.trim(),
                                  selectedImage!,
                                );
                              }
                            } catch (e) {
                              debugPrint("Image upload failed: $e");
                            }
                          }

                          await closeDialog({
                            'relation': categoryController.text.trim(),
                            'full_name': nameController.text.trim(),
                            'gender': selectedGender,
                            'date_of_birth':
                                selectedDob?.toIso8601String().split('T')[0],
                            'image_path': imageUrl,
                          });
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
    );
    await Future.delayed(const Duration(milliseconds: 220));
    categoryController.dispose();
    nameController.dispose();
    categoryFocusNode.dispose();
    nameFocusNode.dispose();

    if (result != null && result['relation'] != null) {
      final newCategory = result['relation'] as String;
      final newImage = result['image_path'] as String?;

      setState(() {
        final alreadyExists = _patientProfiles.any(
          (p) => p['relation']?.toString() == newCategory,
        );
        if (!alreadyExists) {
          _patientProfiles.add({
            'relation': newCategory,
            'image_path': newImage,
          });
        }
        _selectedPatient = newCategory;
      });

      unawaited(
        _profileRepo.savePatientDetails({
          'relation': newCategory,
          'full_name':
              (result['full_name'] as String).isNotEmpty
                  ? result['full_name']
                  : newCategory,
          'gender': result['gender'],
          if (result['date_of_birth'] != null)
            'date_of_birth': result['date_of_birth'],
          'image_path': newImage,
        }),
      );
    }
  }

  Future<void> _deleteCategory(String category) async {
    if (_managingCategory != null) {
      setState(() => _managingCategory = null);
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
              title: "Delete Profile?",
              description:
                  "Are you sure you want to remove '$category'? This action cannot be undone.",
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
                      height: 54,
                      borderRadius: 16,
                      backgroundColor: AppColors.dangerRed,
                      onTap:
                          isDeleting
                              ? () {}
                              : () async {
                                setDialogState(() => isDeleting = true);
                                await Future.delayed(
                                  const Duration(milliseconds: 150),
                                );

                                if (dialogCtx.mounted) {
                                  Navigator.pop(dialogCtx);
                                }

                                final backupPatients =
                                    List<Map<String, dynamic>>.from(
                                      _patientProfiles,
                                    );

                                setState(() {
                                  _patientProfiles.removeWhere(
                                    (p) => p['relation'] == category,
                                  );
                                  if (_selectedPatient == category) {
                                    _selectedPatient = "My Self";
                                  }
                                });

                                try {
                                  await _profileRepo.removePatientCategory(
                                    category,
                                  );
                                  if (mounted) {
                                    CustomSnackbar.showSuccess(
                                      context,
                                      "Profile removed",
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    setState(
                                      () => _patientProfiles = backupPatients,
                                    );
                                    CustomSnackbar.showError(
                                      context,
                                      "Failed to delete: $e",
                                    );
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

  Widget _buildBottomSheetOption({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:
                  isDark
                      ? AppColors.darkSurface
                      : AppColors.primaryGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color:
                    isDark
                        ? AppColors.darkBorder
                        : AppColors.primaryGreen.withValues(alpha: 0.3),
              ),
            ),
            child: Icon(icon, size: 32, color: AppColors.primaryGreen),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final currentFocus = FocusManager.instance.primaryFocus;
    final bool isKeyboardOpen = currentFocus != null && currentFocus.hasFocus;

    if (isKeyboardOpen) {
      currentFocus.unfocus();
      await Future.delayed(const Duration(milliseconds: 300));
    }
    if (!mounted) return;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data:
              Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.darkTheme
                  : AppTheme.lightTheme.copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: AppColors.primaryGreen,
                    ),
                  ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _uploadRecord() async {
    // Block edits on locked records
    if (widget.recordToEdit != null) {
      final lockedUntil = widget.recordToEdit!.lockedUntil;
      if (lockedUntil != null && lockedUntil.isAfter(DateTime.now())) {
        final remaining = lockedUntil.difference(DateTime.now());
        final days = remaining.inDays;
        final hours = remaining.inHours % 24;
        String timeStr;
        if (days > 0) {
          timeStr = '$days day${days > 1 ? "s" : ""}, $hours hour${hours != 1 ? "s" : ""}';
        } else {
          timeStr = '$hours hour${hours != 1 ? "s" : ""}';
        }
        CustomSnackbar.showError(
          context,
          'This record is locked for medical review. Unlocks in $timeStr.',
        );
        return;
      }
    }
    if (_selectedPatient.trim().isEmpty) {
      CustomSnackbar.showError(context, "Please select who this record is for.");
      return;
    }

    final hasImages =
        _selectedImages.isNotEmpty || _existingImageUrls.isNotEmpty;
    final hasDocs = _selectedDocs.isNotEmpty || _existingDocUrls.isNotEmpty;

    if (!hasImages && !hasDocs) {
      CustomSnackbar.showError(
        context,
        "Please add at least one image or document.",
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final newImageUrls = await _repository.prepareFilesForSave(_selectedImages);
      final newDocUrls = await _repository.prepareFilesForSave(_selectedDocs);

      final allFilePaths = [
        ..._existingImageUrls,
        ..._existingDocUrls,
        ...newImageUrls,
        ...newDocUrls,
      ];

      if (widget.recordToEdit != null) {
        await _repository.updateRecord(
          id: widget.recordToEdit!.id,
          recordFor: _selectedPatient.trim(),
          recordType: _selectedType,
          recordDate: _selectedDate,
          fileUrls: allFilePaths,
        );
        if (mounted) {
          CustomSnackbar.showSuccess(context, "Record updated successfully!");
        }
      } else {
        await _repository.addRecord(
          recordFor: _selectedPatient.trim(),
          recordType: _selectedType,
          recordDate: _selectedDate,
          fileUrls: allFilePaths,
        );
        if (mounted) {
          CustomSnackbar.showSuccess(context, "Record added successfully!");
        }
      }

      if (mounted) context.pop(true);
    } catch (e) {
      if (mounted) CustomSnackbar.showError(context, "Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showFullImage(ImageProvider imageProvider) {
    showDialog(
      context: context,
      builder:
          (dialogCtx) => Dialog(
            backgroundColor: Colors.transparent,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = MediaQuery.of(context).size.width * 0.86;
                final maxHeight = MediaQuery.of(context).size.height * 0.7;

                return SizedBox(
                  width: maxWidth,
                  height: maxHeight,
                  child: Stack(
                    alignment: Alignment.topRight,
                    children: [
                      InteractiveViewer(
                        child: SizedBox(
                          width: maxWidth,
                          height: maxHeight,
                          child: Image(
                            image: imageProvider,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(dialogCtx),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
    );
  }

  Future<_ResolvedMedicalRecordImage> _resolveExistingImage(String path) async {
    final localFile = await _repository.getLocalAttachmentFile(path);
    if (localFile != null) {
      return _ResolvedMedicalRecordImage(file: localFile);
    }

    if (NetworkNotifier.instance.isOffline) {
      return const _ResolvedMedicalRecordImage();
    }

    final signedUrl = await _repository.getSignedUrl(path);
    unawaited(_repository.cacheRemoteFile(path, signedUrl: signedUrl));
    return _ResolvedMedicalRecordImage(networkUrl: signedUrl);
  }

  Future<void> _openExistingImage(String path) async {
    try {
      final resolvedImage = await _resolveExistingImage(path);
      if (!mounted) {
        return;
      }

      if (resolvedImage.file != null) {
        _showFullImage(FileImage(resolvedImage.file!));
        return;
      }

      if (resolvedImage.networkUrl != null) {
        _showFullImage(NetworkImage(resolvedImage.networkUrl!));
        return;
      }

      CustomSnackbar.showInfo(
        context,
        "This image isn't available offline yet.",
      );
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, "Unable to open image: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        if (_managingCategory != null) {
          setState(() => _managingCategory = null);
        }
      },
      child: Focus(
        onFocusChange: (hasFocus) {
          if (hasFocus) _loadPatientProfiles();
        },
        child: Container(
          decoration: BoxDecoration(gradient: AppStyles.pageGradient(context)),
          child: Scaffold(
            extendBodyBehindAppBar: true,
            backgroundColor: Colors.transparent,
            extendBody: true,
            appBar: CustomAppBar(
              title: widget.recordToEdit != null ? "Edit Record" : "Add Records",
            ),
            body: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.only(
                    top: MediaQuery.paddingOf(context).top + kToolbarHeight,
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 120 + MediaQuery.of(context).viewInsets.bottom),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel("Who is this record for?"),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 100,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            clipBehavior: Clip.none,
                            children: [
                              _buildPatientAvatar(
                                name: "My Self",
                                imageUrl: _mySelfAvatarUrl,
                                isSelected: _selectedPatient == "My Self",
                                isManaging: false,
                                onTap: () {
                                  if (_managingCategory != null) {
                                    setState(() => _managingCategory = null);
                                  }
                                  HapticFeedback.selectionClick();
                                  setState(() => _selectedPatient = "My Self");
                                },
                              ),
                              ..._patientProfiles.map((patient) {
                                final relation = patient['relation'].toString();
                                final isManaging = _managingCategory == relation;

                                return _buildPatientAvatar(
                                  name: relation,
                                  imageUrl: patient['image_path']?.toString(),
                                  isSelected: _selectedPatient == relation,
                                  isManaging: isManaging,
                                  profileRepository: _profileRepo,
                                  onTap: () {
                                    if (_managingCategory != null) {
                                      setState(() => _managingCategory = null);
                                    } else {
                                      HapticFeedback.selectionClick();
                                      setState(() => _selectedPatient = relation);
                                    }
                                  },
                                  onLongPress: () {
                                    HapticFeedback.heavyImpact();
                                    setState(() {
                                      _managingCategory =
                                          isManaging ? null : relation;
                                      _selectedPatient = relation;
                                    });
                                  },
                                  onDeleteTap: () => _deleteCategory(relation),
                                );
                              }),
                              _buildPatientAvatar(
                                name: "Add New",
                                isAddButton: true,
                                isSelected: false,
                                isManaging: false,
                                onTap: () {
                                  if (_managingCategory != null) {
                                    setState(() => _managingCategory = null);
                                  }
                                  HapticFeedback.lightImpact();
                                  _handleAddNewCategory();
                                },
                              ),
                            ],
                          ),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.fastOutSlowIn,
                          child: _patientProfiles.any((p) => p['relation'] != null && p['relation'] != "My Self")
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 4, bottom: 16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.touch_app_rounded,
                                        size: 13,
                                        color: context.colorTextGrey.withValues(alpha: 0.6),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        "Long press a profile to manage",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: context.colorTextGrey.withValues(alpha: 0.8),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 32,
                                offset: const Offset(0, 12),
                              ),
                            ],
                            border: Border.all(
                              color: isDark ? AppColors.darkBorder : Colors.black.withValues(alpha: 0.08),
                              width: 1.5,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(30.5),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 28),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    child: _buildLabel("Type of record"),
                                  ),
                                  const SizedBox(height: 16),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    child: Row(
                                      children: _recordTypes.asMap().entries.map((entry) {
                                        final index = entry.key;
                                        final item = entry.value;
                                        final type = item['type'] as String;
                                        final icon = item['icon'] as IconData;
                                        final isSelected = _selectedType == type;

                                        return Expanded(
                                          child: Padding(
                                            padding: EdgeInsets.only(
                                              right: index < _recordTypes.length - 1 ? 12 : 0,
                                            ),
                                            child: GestureDetector(
                                              onTap: () {
                                                HapticFeedback.selectionClick();
                                                setState(() => _selectedType = type);
                                              },
                                              behavior: HitTestBehavior.opaque,
                                              child: AnimatedContainer(
                                                duration: const Duration(milliseconds: 250),
                                                curve: Curves.fastOutSlowIn,
                                                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 4),
                                                decoration: BoxDecoration(
                                                  color: isSelected 
                                                      ? AppColors.primaryGreen 
                                                      : (isDark ? Colors.white10 : const Color(0xFFF5F6F8)),
                                                  borderRadius: BorderRadius.circular(20),
                                                  boxShadow: isSelected
                                                      ? [
                                                          BoxShadow(
                                                            color: AppColors.primaryGreen.withValues(alpha: 0.3),
                                                            blurRadius: 12,
                                                            offset: const Offset(0, 6),
                                                          )
                                                        ]
                                                      : [],
                                                ),
                                                child: Column(
                                                  children: [
                                                    Icon(
                                                      icon,
                                                      color: isSelected ? Colors.white : context.colorTextLight,
                                                      size: 26,
                                                    ),
                                                    const SizedBox(height: 8),
                                                    FittedBox(
                                                      fit: BoxFit.scaleDown,
                                                      child: AnimatedDefaultTextStyle(
                                                        duration: const Duration(milliseconds: 250),
                                                        curve: Curves.fastOutSlowIn,
                                                        style: TextStyle(
                                                          fontFamily: AppTextStyles.body(context).fontFamily,
                                                          color: isSelected ? Colors.white : context.colorTextLight,
                                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                                          fontSize: 13,
                                                        ),
                                                        child: Text(type),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    child: _buildLabel("Attachments"),
                                  ),
                                  const SizedBox(height: 16),
                                  if (_selectedImages.isNotEmpty || _existingImageUrls.isNotEmpty)
                                    Container(
                                      height: 144,
                                      margin: const EdgeInsets.only(bottom: 16),
                                      child: ShaderMask(
                                        shaderCallback: (Rect bounds) {
                                          return const LinearGradient(
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                            colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
                                            stops: [0.0, 0.08, 0.92, 1.0],
                                          ).createShader(bounds);
                                        },
                                        blendMode: BlendMode.dstIn,
                                        child: ListView(
                                          scrollDirection: Axis.horizontal,
                                          clipBehavior: Clip.none,
                                          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 16, top: 4),
                                          children: [
                                            ..._existingImageUrls.asMap().entries.map((e) => _buildThumbnail(
                                              path: e.value,
                                              onDelete: () => setState(() => _existingImageUrls.removeAt(e.key)),
                                            )),
                                            ..._selectedImages.asMap().entries.map((e) => _buildThumbnail(
                                              file: e.value,
                                              onDelete: () => setState(() => _selectedImages.removeAt(e.key)),
                                            )),
                                          ],
                                        ),
                                      ),
                                    ),
                                  if (_selectedDocs.isNotEmpty || _existingDocUrls.isNotEmpty)
                                    Container(
                                      height: 86,
                                      margin: const EdgeInsets.only(bottom: 16),
                                      child: ShaderMask(
                                        shaderCallback: (Rect bounds) {
                                          return const LinearGradient(
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                            colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
                                            stops: [0.0, 0.08, 0.92, 1.0],
                                          ).createShader(bounds);
                                        },
                                        blendMode: BlendMode.dstIn,
                                        child: ListView(
                                          scrollDirection: Axis.horizontal,
                                          clipBehavior: Clip.none,
                                          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 16, top: 4),
                                          children: [
                                            ..._existingDocUrls.asMap().entries.map((entry) => _buildDocItem(
                                              name: _getCleanFileName(entry.value),
                                              onDelete: () => setState(() => _existingDocUrls.removeAt(entry.key)),
                                            )),
                                            ..._selectedDocs.asMap().entries.map((entry) => _buildDocItem(
                                              name: entry.value.path.split('/').last,
                                              onDelete: () => setState(() => _selectedDocs.removeAt(entry.key)),
                                            )),
                                          ],
                                        ),
                                      ),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: _showImageOptions,
                                            child: _buildUploadActionCard(context, icon: Icons.add_a_photo_rounded, label: "Add Photo"),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: _pickFiles,
                                            child: _buildUploadActionCard(context, icon: Icons.upload_file_rounded, label: "Add Document"),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    child: _buildLabel("Record date"),
                                  ),
                                  const SizedBox(height: 16),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    child: GestureDetector(
                                      onTap: () => _selectDate(context),
                                      behavior: HitTestBehavior.opaque,
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? AppColors.darkSurface
                                              : const Color(0xFFF5F6F8),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: Theme.of(context).brightness == Brightness.dark 
                                                ? Colors.transparent 
                                                : Colors.black.withValues(alpha: 0.03),
                                            width: 1,
                                          )
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              DateFormat('dd MMM, yyyy').format(_selectedDate),
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: context.colorTextDark,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryGreen.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Icon(
                                                Icons.calendar_month_rounded,
                                                color: AppColors.primaryGreen,
                                                size: 18,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: AppBottomTray(
              child: PrimaryButton(
                label:
                    _isLoading
                        ? "Processing..."
                        : (widget.recordToEdit != null
                            ? "Update record"
                            : "Upload record"),
                onTap: _isLoading ? () {} : _uploadRecord,
                isLoading: _isLoading,
                borderRadius: 16,
                height: 54,
              ),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildUploadActionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color:
            isDark
                ? AppColors.primaryGreen.withValues(alpha: 0.1)
                : context.colorLightGreenBg.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isDark
                  ? AppColors.primaryGreen.withValues(alpha: 0.3)
                  : AppColors.primaryGreen.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.primaryGreen, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primaryGreen,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocItem({required String name, required VoidCallback onDelete}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 180,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              isDark
                  ? AppColors.darkBorder
                  : Colors.grey.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.description_rounded,
              color: AppColors.primaryGreen,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colorTextDark,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.dangerRed.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 14,
                color: AppColors.dangerRed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientAvatar({
    required String name,
    String? imageUrl,
    required bool isSelected,
    required VoidCallback onTap,
    bool isAddButton = false,
    bool isManaging = false,
    VoidCallback? onLongPress,
    VoidCallback? onDeleteTap,
    ProfileRepository? profileRepository,
  }) {
    return _DynamicAvatarPill(
      name: name,
      imageUrl: imageUrl,
      isSelected: isSelected,
      isAddButton: isAddButton,
      isManaging: isManaging,
      onTap: onTap,
      onLongPress: onLongPress,
      onDeleteTap: onDeleteTap,
      profileRepository: profileRepository ?? _profileRepo,
    );
  }

  Widget _buildThumbnail({
    String? path,
    File? file,
    required VoidCallback onDelete,
  }) {
    final imageWidget =
        file != null
            ? GestureDetector(
              onTap: () => _showFullImage(FileImage(file)),
              child: Image.file(
                file,
                width: 100,
                height: 120,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            )
            : FutureBuilder<_ResolvedMedicalRecordImage>(
              future: _resolveExistingImage(path!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildThumbnailPlaceholder();
                }

                final resolvedImage = snapshot.data;
                final resolvedFile = resolvedImage?.file;
                if (resolvedFile != null) {
                  return GestureDetector(
                    onTap: () => _showFullImage(FileImage(resolvedFile)),
                    child: Image.file(
                      resolvedFile,
                      width: 100,
                      height: 120,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
                  );
                }

                final resolvedNetworkUrl = resolvedImage?.networkUrl;
                if (resolvedNetworkUrl != null) {
                  return GestureDetector(
                    onTap: () => _openExistingImage(path!),
                    child: AppNetworkImage(
                      imageUrl: resolvedNetworkUrl,
                      cacheKey: path,
                      width: 100,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  );
                }

                return _buildUnavailableThumbnail();
              },
            );

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkBorder
                        : Colors.white,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: imageWidget,
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: onDelete,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    color: Colors.black.withValues(alpha: 0.4),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailPlaceholder() {
    return const SizedBox(
      width: 100,
      height: 120,
      child: AppLoader(),
    );
  }

  Widget _buildUnavailableThumbnail() {
    return Container(
      width: 100,
      height: 120,
      color: Theme.of(context).colorScheme.surface,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: context.colorTextLight,
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.primaryGreen,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
            color: context.colorTextDark,
          ),
        ),
      ],
    );
  }
}

class _ResolvedMedicalRecordImage {
  final File? file;
  final String? networkUrl;

  const _ResolvedMedicalRecordImage({this.file, this.networkUrl});
}

class _DynamicAvatarPill extends StatefulWidget {
  final String name;
  final String? imageUrl;
  final bool isSelected;
  final bool isAddButton;
  final bool isManaging;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDeleteTap;
  final ProfileRepository profileRepository;

  const _DynamicAvatarPill({
    required this.name,
    this.imageUrl,
    required this.isSelected,
    required this.isAddButton,
    required this.isManaging,
    required this.onTap,
    this.onLongPress,
    this.onDeleteTap,
    required this.profileRepository,
  });

  @override
  State<_DynamicAvatarPill> createState() => _DynamicAvatarPillState();
}

class _DynamicAvatarPillState extends State<_DynamicAvatarPill>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  bool _isUnlocked = false;
  String _backendLockState = 'checking';

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -6.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 0.0), weight: 1),
    ]).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant _DynamicAvatarPill oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isManaging && !oldWidget.isManaging) {
      _checkBackendLock();
    }

    if (!widget.isManaging) {
      _isUnlocked = false;
      _backendLockState = 'checking';
    }
  }

  Future<void> _checkBackendLock() async {
    final isLocked = await widget.profileRepository.isCategoryLocked(
      widget.name,
    );
    if (mounted) {
      setState(() {
        _backendLockState = isLocked ? 'locked' : 'clear';
      });
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _triggerShake() {
    HapticFeedback.heavyImpact();
    _shakeController.forward(from: 0.0);

    if (_backendLockState == 'locked') {
      CustomSnackbar.showInfo(
        context,
        "Cannot modify. Tied to an active medical appointment.",
      );
    } else {
      CustomSnackbar.showInfo(
        context,
        "Locked for safety. Tap the padlock to unlock deletion.",
      );
    }
  }

  bool _isLocalImagePath(String path) {
    return path.startsWith('/') ||
        path.startsWith('file://') ||
        RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double size = widget.isSelected || widget.isManaging ? 72 : 64;
    final double expandedWidth = 180;
    final double currentWidth = widget.isManaging ? expandedWidth : size;

    final Color idleBaseColor =
        widget.isAddButton
            ? (isDark
                ? Colors.white10
                : Colors.black.withValues(alpha: 0.05))
            : (widget.imageUrl == null || widget.imageUrl!.isEmpty
                ? AppColors.primaryGreen.withValues(alpha: 0.1)
                : Colors.transparent);

    final Color managingBaseColor =
        _isUnlocked
            ? AppColors.dangerRed.withValues(alpha: 0.1)
            : (isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.04));

    final Color borderColor =
        widget.isManaging
            ? (_isUnlocked
                ? AppColors.dangerRed.withValues(alpha: 0.6)
                : Colors.transparent)
            : (widget.isSelected
                ? AppColors.primaryGreen
                : Colors.transparent);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      onLongPress: () {
        setState(() => _isPressed = false);
        widget.onLongPress?.call();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Container(
          margin: const EdgeInsets.only(right: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 72,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.fastOutSlowIn,
                    width: currentWidth,
                    height: size,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.centerLeft,
                      children: [
                        Positioned.fill(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: widget.isManaging ? 1.0 : 0.0,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              decoration: BoxDecoration(
                                color: managingBaseColor,
                                borderRadius: BorderRadius.circular(36),
                                border: Border.all(
                                  color: borderColor,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: widget.isManaging ? 0.0 : 1.0,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.fastOutSlowIn,
                            width: size,
                            height: size,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: idleBaseColor,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryGreen.withValues(
                                    alpha:
                                        widget.isSelected &&
                                                !widget.isManaging
                                            ? 0.25
                                            : 0.0,
                                  ),
                                  blurRadius:
                                      widget.isSelected && !widget.isManaging
                                          ? 12
                                          : 0,
                                  offset:
                                      widget.isSelected && !widget.isManaging
                                          ? const Offset(0, 6)
                                          : Offset.zero,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // LAYER 3A: The Padlock / Spinner (Permanently visible while managing)
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.fastOutSlowIn,
                          top: 0, bottom: 0,
                          right: widget.isManaging ? 54 : -size, 
                          width: 54, 
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 250),
                            opacity: widget.isManaging ? 1.0 : 0.0,
                            child: GestureDetector(
                              onTap: () {
                                if (_backendLockState == 'clear') {
                                  HapticFeedback.mediumImpact();
                                  setState(() => _isUnlocked = !_isUnlocked);
                                } else if (_backendLockState == 'locked') {
                                  // If backend locked, tapping the padlock triggers the warning shake!
                                  _triggerShake();
                                }
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Center(
                                child: AnimatedBuilder(
                                  animation: _shakeAnimation,
                                  builder: (context, child) => Transform.translate(
                                    offset: Offset(_shakeAnimation.value, 0),
                                    child: child,
                                  ),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                                    child: _backendLockState == 'checking'
                                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey))
                                        : Icon(
                                            _isUnlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                                            key: ValueKey(_isUnlocked),
                                            color: _isUnlocked ? AppColors.dangerRed : context.colorTextLight.withValues(alpha: 0.6),
                                            size: 24,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // LAYER 3B: The Trash Button (Triggers wiggle if locked or checking)
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.fastOutSlowIn,
                          top: 0, bottom: 0,
                          right: widget.isManaging ? 0 : -size, 
                          width: 54, 
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 250),
                            opacity: widget.isManaging ? 1.0 : 0.0,
                            child: GestureDetector(
                              onTap: _isUnlocked ? widget.onDeleteTap : _triggerShake,
                              behavior: HitTestBehavior.opaque,
                              child: Center(
                                child: Icon(
                                  Icons.delete_sweep_rounded, 
                                  color: _isUnlocked ? AppColors.dangerRed : context.colorTextLight.withValues(alpha: 0.3), 
                                  size: 26,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // LAYER 4: The Avatar Content
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.fastOutSlowIn,
                          width: size,
                          height: size,
                          padding: EdgeInsets.all(widget.isManaging ? 4.0 : 0.0), 
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primaryGreen.withValues(alpha: widget.isSelected && !widget.isManaging ? 1.0 : 0.0),
                              width: 3, 
                            ),
                          ),
                          clipBehavior: Clip.antiAlias, 
                          child: ClipOval(
                            child: widget.isAddButton
                                ? Icon(Icons.add_rounded, color: isDark ? Colors.white : Colors.black, size: 28)
                                : (widget.imageUrl != null && widget.imageUrl!.isNotEmpty
                                    ? (_isLocalImagePath(widget.imageUrl!)
                                        ? Image.file(File(widget.imageUrl!), fit: BoxFit.cover)
                                        : AppNetworkImage(imageUrl: widget.imageUrl!, fit: BoxFit.cover))
                                    : Icon(Icons.person, color: AppColors.primaryGreen, size: 28)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.fastOutSlowIn,
                width: currentWidth,
                alignment: Alignment.center,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.3),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    widget.isManaging
                        ? (_backendLockState == 'checking'
                            ? "Checking..."
                            : (_backendLockState == 'locked'
                                ? "Appointment Active"
                                : (_isUnlocked
                                    ? "Tap to confirm"
                                    : "Unlock to delete")))
                        : widget.name,
                    key: ValueKey(
                      '${widget.isManaging}_$_isUnlocked$_backendLockState',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          widget.isSelected || widget.isManaging
                              ? FontWeight.bold
                              : FontWeight.w500,
                      color:
                          widget.isManaging
                              ? (_isUnlocked
                                  ? AppColors.dangerRed
                                  : context.colorTextLight.withValues(
                                    alpha: 0.6,
                                  ))
                              : (widget.isSelected
                                  ? AppColors.primaryGreen
                                  : context.colorTextLight),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
