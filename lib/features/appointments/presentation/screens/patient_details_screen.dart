import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../profile/data/profile_repository.dart';
import '../../data/booking_draft_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'package:intl/intl.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';
import '../../../../presentation/widgets/app_text_field.dart';
import '../../../../presentation/widgets/primary_button.dart';
import '../../../../features/profile/presentation/profile_notifier.dart'; 
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_routes.dart';
import '../models/booking_route_args.dart';
import '../../../../presentation/widgets/app_floating_dialog.dart';
import '../../../../presentation/widgets/app_network_image.dart'; 
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/router/app_router.dart'; // Needed for routeObserver
import '../../../../presentation/widgets/app_bottom_tray.dart';

import '../../../../features/medical_records/data/medical_record.dart';
import '../../../../features/medical_records/data/medical_record_repository.dart';

class PatientDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> doctor;
  final Map<String, dynamic> clinic;
  final DateTime initialDate;
  final String? timeSlot;
  final String idempotencyKey;

  const PatientDetailsScreen({
    super.key,
    required this.doctor,
    required this.clinic,
    required this.initialDate,
    this.timeSlot,
    required this.idempotencyKey,
  });

  @override
  State<PatientDetailsScreen> createState() => _PatientDetailsScreenState();
}

class _PatientDetailsScreenState extends State<PatientDetailsScreen>
    with WidgetsBindingObserver {
  Color get primaryGreen => AppColors.primaryGreen;
  Color get textDark => context.colorTextDark;
  Color get textLight => context.colorTextLight;
  Color get textGrey => context.colorTextGrey;
  Color get borderColor => context.colorBorder;
  Color get lightGreenBg => context.colorLightGreenBg;

  final _profileRepo = ProfileRepository();
  final _draftRepo = BookingDraftRepository();
  final _medicalRecordRepo = MedicalRecordRepository(); 
  
  Timer? _draftDebounce;
  bool _restoringDraft = false;
  bool _isSavingCategory = false;
  
  List<MedicalRecord> _availableRecords = [];
  List<MedicalRecord> _selectedRecords = [];
  bool _recordsFetched = false;

  TextStyle get _labelStyle =>
      TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textDark);

  TextStyle get _inputStyle => TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: textDark,
    height: 1.1,
  );

  TextStyle get _hintStyle => TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: textGrey,
    height: 1.1,
  );

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
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
            color: context.colorTextDark,
          ),
        ),
      ],
    );
  }

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();

  String _selectedGender = "Male";
  String? _selectedDay;
  String? _selectedMonth;
  String? _selectedYear;

  List<Map<String, dynamic>> _savedPatients = [];
  String? _newPendingCategory;
  String _selectedCategoryName = "My Self";
  String? _managingCategory;

  String? _userProfileUrl;
  File? _newPatientImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _nameController.addListener(_onFormFieldChanged);
    _phoneController.addListener(_onFormFieldChanged);
    _emailController.addListener(_onFormFieldChanged);
    unawaited(_bootstrapForm());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draftDebounce?.cancel();
    _nameController.removeListener(_onFormFieldChanged);
    _phoneController.removeListener(_onFormFieldChanged);
    _emailController.removeListener(_onFormFieldChanged);
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  void _updateDobText() {
    if (_selectedDay != null &&
        _selectedMonth != null &&
        _selectedYear != null) {
      _dobController.text = "$_selectedDay $_selectedMonth, $_selectedYear";
    } else {
      _dobController.clear();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _persistDraftNow();
    }
  }

  Future<void> _bootstrapForm() async {
    await _restoreDraftIfMatchingContext();
    await _fetchUserProfile();
  }

  void _onFormFieldChanged() {
    if (_restoringDraft) return;
    _scheduleDraftSave();
  }

  void _scheduleDraftSave() {
    _draftDebounce?.cancel();
    _draftDebounce = Timer(const Duration(milliseconds: 350), _persistDraftNow);
  }

  Future<void> _persistDraftNow() async {
    final doctorId = widget.doctor['id']?.toString();
    final clinicId = widget.clinic['id']?.toString();
    if (doctorId == null || clinicId == null) {
      return;
    }
    try {
      await _draftRepo.saveDraft({
        'doctor_id': doctorId,
        'clinic_id': clinicId,
        'name': _nameController.text,
        'phone': _phoneController.text,
        'email': _emailController.text,
        'gender': _selectedGender,
        'day': _selectedDay,
        'month': _selectedMonth,
        'year': _selectedYear,
        'selected_category_name': _selectedCategoryName,
        'new_pending_category': _newPendingCategory,
        'patient_image_path': _newPatientImage?.path,
        'time_slot': widget.timeSlot,
        'appointment_date': widget.initialDate.toIso8601String(),
        'attached_record_ids': _selectedRecords.map((e) => e.id).toList(),
      });
    } catch (_) {}
  }

  Future<void> _restoreDraftIfMatchingContext() async {
    try {
      final draft = await _draftRepo.loadDraft();
      if (draft == null) return;

      final doctorId = widget.doctor['id']?.toString();
      final clinicId = widget.clinic['id']?.toString();
      if (draft['doctor_id']?.toString() != doctorId ||
          draft['clinic_id']?.toString() != clinicId) {
        return;
      }

      _restoringDraft = true;
      if (!mounted) return;
      setState(() {
        _nameController.text = draft['name']?.toString() ?? '';
        _phoneController.text = draft['phone']?.toString() ?? '';
        _emailController.text = draft['email']?.toString() ?? '';
        _selectedGender = draft['gender']?.toString() ?? _selectedGender;
        _selectedDay = draft['day']?.toString();
        _selectedMonth = draft['month']?.toString();
        _selectedYear = draft['year']?.toString();
        _selectedCategoryName =
            draft['selected_category_name']?.toString() ?? "My Self";
        _newPendingCategory = draft['new_pending_category']?.toString();

        final imagePath = draft['patient_image_path']?.toString();
        if (imagePath != null && imagePath.isNotEmpty) {
          _newPatientImage = File(imagePath);
        }
      });
      _updateDobText();
      
      final attachedIdsRaw = draft['attached_record_ids'];
      if (attachedIdsRaw != null && attachedIdsRaw is List && attachedIdsRaw.isNotEmpty) {
         _fetchAndMapDraftRecords(attachedIdsRaw);
      }
      
    } catch (_) {
    } finally {
      _restoringDraft = false;
    }
  }

  Future<void> _fetchAndMapDraftRecords(List<dynamic> ids) async {
    try {
      _availableRecords = await _medicalRecordRepo.fetchRecords();
      _recordsFetched = true;
      if (mounted) {
        setState(() {
          _selectedRecords = _availableRecords.where((r) => ids.contains(r.id)).toList();
        });
      }
    } catch (e) {
      debugPrint("Failed to load draft medical records: $e");
    }
  }

  Future<void> _clearDraft() async {
    try {
      await _draftRepo.clearDraft();
    } catch (_) {}
  }

  Future<void> _fetchUserProfile() async {
    final userId = _profileRepo.currentUserId;
    if (userId != null) {
      try {
        final patients = await _profileRepo.getSavedPatients(userId);

        if (mounted) {
          setState(() {
            _savedPatients = patients;
          });
        }

        final notifier = ProfileNotifier.instance;
        final profile = notifier.profile;
        if (!notifier.isLoaded) {
          await notifier.loadProfile();
        }

        if (mounted && profile != null) {
          setState(() {
            _userProfileUrl = profile.profilePictureUrl;

            if (_phoneController.text.isEmpty) {
              _phoneController.text = notifier.phoneNumber ?? "";
            }
            if (_emailController.text.isEmpty) {
              _emailController.text = _profileRepo.currentUserEmail ?? "";
            }

            if (_selectedCategoryName == "My Self" && _nameController.text.isEmpty) {
              _nameController.text = profile.fullName;
              if (profile.dateOfBirth != null) {
                _selectedDay = profile.dateOfBirth!.day.toString();
                _selectedMonth = DateFormat('MMMM').format(profile.dateOfBirth!);
                _selectedYear = profile.dateOfBirth!.year.toString();
              } else {
                _selectedDay = null;
                _selectedMonth = null;
                _selectedYear = null;
              }
            }
          });
          _updateDobText();
        }
      } catch (e) {
        debugPrint("Error loading profile details: $e");
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _newPatientImage = File(image.path);
        });
        _scheduleDraftSave();
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  Future<void> _showAddCategoryDialog() async {
    final TextEditingController categoryController = TextEditingController();
    File? selectedImage;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AppFloatingDialog(
              headerIcon: Icons.person_add_alt_1_rounded,
              iconColor: AppColors.primaryGreen,
              title: "Add Profile Category",
              description: "Who is this patient? (e.g. Brother, Wife)",
              isUpdating: false,
              content: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () async {
                      final picked = await _picker.pickImage(
                        source: ImageSource.gallery,
                      );
                      if (picked != null && dialogCtx.mounted) {
                        setDialogState(() => selectedImage = File(picked.path));
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
                      autofocus: true,
                      hintText: "Category (e.g. Son)",
                    ),
                  ),
                ],
              ),
              actions: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogCtx),
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
                      label: "Add",
                      height: 54,
                      borderRadius: 16,
                      onTap: () {
                        if (categoryController.text.trim().isNotEmpty) {
                          Navigator.pop(dialogCtx, {
                            'category': categoryController.text.trim(),
                            'image': selectedImage,
                          });
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

    if (result != null && result['category'] != null) {
      setState(() {
        _newPendingCategory = result['category'];
        _selectedCategoryName = result['category'];
        _newPatientImage = result['image'];
        _nameController.clear();
        _selectedDay = null;
        _selectedMonth = null;
        _selectedYear = null;
        _selectedGender = "Male";
      });
      _updateDobText();
      _scheduleDraftSave();
    }
  }

  Future<void> _saveCategoryLocally() async {
    if (_nameController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _selectedDay == null ||
        _selectedMonth == null ||
        _selectedYear == null) {
      CustomSnackbar.showError(context, "Please fill all fields to save");
      return;
    }

    setState(() => _isSavingCategory = true);

    try {
      final catToSave = _newPendingCategory ?? _selectedCategoryName;
      String? finalImagePath;

      if (_newPatientImage != null && _newPatientImage!.existsSync()) {
        final userId = _profileRepo.currentUserId;
        if (userId != null) {
          final uploadedUrl = await _profileRepo.uploadPatientPicture(
            userId,
            catToSave,
            _newPatientImage!,
          );
          finalImagePath = uploadedUrl;
        }
      } else {
        final existingPatient = _savedPatients.where((p) => p['relation'] == catToSave).firstOrNull;
        finalImagePath = existingPatient?['image_path'];

        if (finalImagePath == null || finalImagePath.isEmpty) {
          try {
            final userId = _profileRepo.currentUserId;
            if (userId != null) {
              final freshPatients = await _profileRepo.getSavedPatients(userId, forceRefresh: true);
              final freshMatch = freshPatients.where((p) => p['relation'] == catToSave).firstOrNull;
              finalImagePath = freshMatch?['image_path'];
            }
          } catch (_) {}
        }
      }

      final monthInt = _monthStringToInt(_selectedMonth!);
      final dobString = DateTime(
        int.parse(_selectedYear!),
        monthInt,
        int.parse(_selectedDay!),
      ).toIso8601String().split('T')[0];

      await _profileRepo.savePatientDetails({
        'relation': catToSave,
        'full_name': _nameController.text,
        'gender': _selectedGender,
        'date_of_birth': dobString,
        'image_path': finalImagePath,
      });

      await _profileRepo.getSavedPatients(
        _profileRepo.currentUserId ?? '',
        forceRefresh: true,
      );
      await _fetchUserProfile();
      
      setState(() {
        _newPendingCategory = null;
        _newPatientImage = null;
      });

      if (mounted) CustomSnackbar.showSuccess(context, "Profile saved successfully!");
    } catch (e) {
      if (mounted) CustomSnackbar.showError(context, "Failed to save profile");
    } finally {
      if (mounted) setState(() => _isSavingCategory = false);
    }
  }

  Future<void> _deleteCategory(String category) async {
    FocusScope.of(context).unfocus();

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
                      onPressed: isDeleting ? null : () => Navigator.pop(dialogCtx),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
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
                      onTap: isDeleting
                          ? () {}
                          : () async {
                              setDialogState(() => isDeleting = true);
                              await Future.delayed(const Duration(milliseconds: 150));

                              if (dialogCtx.mounted) Navigator.pop(dialogCtx);

                              final backupPatients = List<Map<String, dynamic>>.from(_savedPatients);
                              final wasSelected = _selectedCategoryName == category;

                              setState(() {
                                _savedPatients.removeWhere((p) => p['relation'] == category);
                                if (wasSelected) {
                                  _selectedCategoryName = "My Self";
                                  _nameController.clear();
                                }
                              });

                              try {
                                await _profileRepo.removePatientCategory(category);

                                if (wasSelected) {
                                  await _fetchUserProfile();
                                }

                                if (mounted) {
                                  CustomSnackbar.showSuccess(context, "Profile removed");
                                }
                              } catch (e) {
                                if (mounted) {
                                  setState(() {
                                    _savedPatients = backupPatients;
                                    if (wasSelected) _selectedCategoryName = category;
                                  });
                                  CustomSnackbar.showError(context, "Failed to delete: $e");
                                }
                              }
                            },
                    ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  void _handleContinue() async {
    if (_nameController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _selectedDay == null ||
        _selectedMonth == null ||
        _selectedYear == null) {
      CustomSnackbar.showError(context, "Please fill all fields");
      return;
    }

    final monthInt = _monthStringToInt(_selectedMonth!);
    final dob = DateTime(
      int.parse(_selectedYear!),
      monthInt,
      int.parse(_selectedDay!),
    );

    final catToSave = _newPendingCategory ?? _selectedCategoryName;
    String? finalImagePath;

    if (catToSave == "My Self") {
      finalImagePath = _userProfileUrl;
    } else {
      if (_newPatientImage != null && _newPatientImage!.existsSync()) {
        try {
          final userId = _profileRepo.currentUserId;
          if (userId != null) {
            final uploadedUrl = await _profileRepo.uploadPatientPicture(
              userId,
              catToSave,
              _newPatientImage!,
            );
            finalImagePath = uploadedUrl;
          }
        } catch (e) {
          debugPrint("Failed to upload category picture: $e");
        }
      } else {
        final existingPatient = _savedPatients.where((p) => p['relation'] == catToSave).firstOrNull;
        finalImagePath = existingPatient?['image_path'];

        if (finalImagePath == null || finalImagePath.isEmpty) {
          try {
            final userId = _profileRepo.currentUserId;
            if (userId != null) {
              final freshPatients = await _profileRepo.getSavedPatients(userId, forceRefresh: true);
              final freshMatch = freshPatients.where((p) => p['relation'] == catToSave).firstOrNull;
              finalImagePath = freshMatch?['image_path'];
            }
          } catch (_) {}
        }
      }

      final monthInt = _monthStringToInt(_selectedMonth!);
      final dobString = DateTime(
        int.parse(_selectedYear!),
        monthInt,
        int.parse(_selectedDay!),
      ).toIso8601String().split('T')[0];
      
      unawaited(
        _profileRepo
            .savePatientDetails({
              'relation': catToSave,
              'full_name': _nameController.text,
              'gender': _selectedGender,
              'date_of_birth': dobString,
              'image_path': finalImagePath,
            })
            .then(
              (_) => _profileRepo.getSavedPatients(
                _profileRepo.currentUserId ?? '',
                forceRefresh: true,
              ),
            ),
      );
    }

    unawaited(_clearDraft());

    if (!mounted) return;
    context.push(
      AppRoutes.paymentMethod,
      extra: PaymentMethodArgs(
        doctor: widget.doctor,
        clinic: widget.clinic,
        appointmentDate: widget.initialDate,
        timeSlot: widget.timeSlot,
        idempotencyKey: widget.idempotencyKey,
        patientDetails: {
          'name': _nameController.text,
          'phone': _phoneController.text,
          'email': _emailController.text,
          'gender': _selectedGender,
          'dob': dob.toIso8601String(),
          'imagePath': finalImagePath, 
          'patientType': _selectedCategoryName,
          'newCategoryToSave': _newPendingCategory,
          'attachedRecords': _selectedRecords.map((r) => {
            'id': r.id,
            'recordFor': r.recordFor,
            'recordType': r.recordType,
            'fileUrls': r.fileUrls,
          }).toList(),
        },
      ),
    );
  }

  int _monthStringToInt(String month) {
    switch (month) {
      case 'January': return 1;
      case 'February': return 2;
      case 'March': return 3;
      case 'April': return 4;
      case 'May': return 5;
      case 'June': return 6;
      case 'July': return 7;
      case 'August': return 8;
      case 'September': return 9;
      case 'October': return 10;
      case 'November': return 11;
      case 'December': return 12;
      default: return 1;
    }
  }

  void _showMedicalRecordsBottomSheet() async {
    final currentFocus = FocusManager.instance.primaryFocus;
    final bool isKeyboardOpen = currentFocus != null && currentFocus.hasFocus;

    if (isKeyboardOpen) {
      currentFocus.unfocus();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (!mounted) return;

    List<MedicalRecord> tempSelected = List.from(_selectedRecords);
    
    // Track loading state locally for the bottom sheet
    bool isFetching = true; 
    List<MedicalRecord> sheetAvailableRecords = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            
            // 1. Fetch data AFTER sheet opens to prevent UI freeze
            if (isFetching && sheetAvailableRecords.isEmpty) {
              _medicalRecordRepo.fetchRecords().then((allRecords) {
                if (mounted) {
                  final currentPatient = _newPendingCategory ?? _selectedCategoryName;
                  setSheetState(() {
                    sheetAvailableRecords = allRecords.where((r) => r.recordFor == currentPatient).toList();
                    isFetching = false;
                    // Also update the parent state so the outer UI knows we fetched
                    setState(() {
                      _availableRecords = sheetAvailableRecords;
                      _recordsFetched = true;
                    });
                  });
                }
              }).catchError((e) {
                if (mounted) {
                  setSheetState(() => isFetching = false);
                  CustomSnackbar.showError(context, "Failed to load records from vault.");
                  Navigator.pop(ctx);
                }
              });
            }

            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.75, 
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min, 
                  children: [
                    Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text("Your Medical Vault", style: AppTextStyles.h3(context).copyWith(fontSize: 20)),
                    const SizedBox(height: 8),
                    const Text(
                      "Select past records or lab reports to attach.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),

                    // 2. Show Loader while fetching
                    if (isFetching)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: AppLoader()), // Uses your existing AppLoader widget
                      )
                    else if (sheetAvailableRecords.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text("No records found in your vault.", style: TextStyle(color: Colors.grey)),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true, 
                          itemCount: sheetAvailableRecords.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final record = sheetAvailableRecords[index];
                            final isSelected = tempSelected.any((r) => r.id == record.id);
                            
                            return _VaultRecordTile(
                              record: record,
                              isSelected: isSelected,
                              onToggle: () {
                                setSheetState(() {
                                  if (isSelected) {
                                    tempSelected.removeWhere((r) => r.id == record.id);
                                  } else {
                                    tempSelected.add(record);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                    
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: PrimaryButton(
                        label: "Done",
                        height: 54, 
                        borderRadius: 16,
                        onTap: () {
                          setState(() {
                            _selectedRecords = tempSelected;
                          });
                          _scheduleDraftSave();
                          Navigator.pop(ctx);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  Widget _buildMedicalRecordsSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildLabel("Medical Records (Optional)"),
        ),
        const SizedBox(height: 10),
        if (_selectedRecords.isNotEmpty) ...[
          SizedBox(
            height: 106,
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.transparent,
                    Colors.white,
                    Colors.white,
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.08, 0.92, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.hardEdge,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                itemCount: _selectedRecords.length + 1,
                itemBuilder: (context, index) {
                  if (index == _selectedRecords.length) {
                    return GestureDetector(
                      onTap: _showMedicalRecordsBottomSheet,
                      child: Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primaryGreen.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Icon(Icons.add, color: AppColors.primaryGreen),
                      ),
                    );
                  }
                  final record = _selectedRecords[index];

                  return Container(
                    width: 180,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : Colors.black.withValues(alpha: 0.04),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
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
                          child: Icon(
                            record.recordType == 'Prescription'
                                ? Icons.medical_services_rounded
                                : Icons.analytics_rounded,
                            size: 16,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                record.recordType,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: textDark,
                                ),
                              ),
                              Text(
                                DateFormat('dd MMM yyyy').format(record.recordDate),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            setState(() => _selectedRecords.removeAt(index));
                            _scheduleDraftSave();
                          },
                          behavior: HitTestBehavior.opaque,
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
                },
              ),
            ),
          ),
        ] else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: _showMedicalRecordsBottomSheet,
              child: Container(
                height: 54,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? AppColors.primaryGreen.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.03),
                    width: 1,
                  ),
                  color: isDark
                      ? AppColors.primaryGreen.withValues(alpha: 0.1)
                      : const Color(0xFFF8F9FA),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(
                      Icons.folder_shared_outlined,
                      color: AppColors.primaryGreen,
                    ),
                    SizedBox(width: 8),
                    Text(
                      "Attach from Vault",
                      style: TextStyle(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false, 
        extendBodyBehindAppBar: true,
        appBar: _buildAppBar(),
        body: Container(
          decoration: BoxDecoration(gradient: AppStyles.pageGradient(context)),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      MediaQuery.paddingOf(context).top + kToolbarHeight + 20,
                      24,
                      120 + MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // PRO FIX: 100% synchronized with Confirmation layout!
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center, // Synced
                            children: [
                              Text(
                                "Step 1/2",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700, // Synced
                                  color: textDark,
                                ),
                              ),
                              const SizedBox(width: 16), // Synced
                              Expanded(
                              child: Container(
                                height: 6, 
                                decoration: BoxDecoration(
                                  color: primaryGreen.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Builder(
                                  builder: (context) {
                                    // PRO FIX: Slave the physical width to the native page transition!
                                    final route = ModalRoute.of(context);
                                    final animation = route?.animation ?? const AlwaysStoppedAnimation(1.0);
                                    
                                    return AnimatedBuilder(
                                      animation: animation,
                                      builder: (context, child) {
                                        // Premium Apple-style momentum curve
                                        final curve = Curves.fastOutSlowIn.transform(animation.value);
                                        return FractionallySizedBox(
                                          alignment: Alignment.centerLeft,
                                          // As the page slides in, it goes 0.0 -> 0.5. As it slides out, it goes 0.5 -> 0.0!
                                          widthFactor: 0.5 * curve, 
                                          child: child,
                                        );
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: primaryGreen,
                                          borderRadius: BorderRadius.circular(4),
                                          boxShadow: [
                                            BoxShadow(
                                              color: primaryGreen.withValues(alpha: 0.3),
                                              blurRadius: 4, 
                                              offset: const Offset(0, 2),
                                            )
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                ),
                              ),
                            ),
                            ],
                          ),
                        const SizedBox(height: 24),

                        _buildLabel("Who is this patient?"),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 100,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            clipBehavior: Clip.none,
                            children: [
                              _DynamicAvatarPill(
                                name: "My Self",
                                imageUrl: _userProfileUrl,
                                isSelected: _selectedCategoryName == "My Self",
                                isAddButton: false,
                                isManaging: false,
                                profileRepository: _profileRepo,
                                onTap: () {
                                  if (_managingCategory != null) {
                                    setState(() => _managingCategory = null);
                                  }
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    _selectedCategoryName = "My Self";
                                    _newPatientImage = null;
                                    _nameController.clear();
                                  });
                                  _fetchUserProfile();
                                  _scheduleDraftSave();
                                },
                              ),
                              ..._savedPatients.map((patientMap) {
                                final category = patientMap['relation'] as String;
                                final isManaging = _managingCategory == category;

                                return _DynamicAvatarPill(
                                  name: category,
                                  imageUrl: patientMap['image_path']?.toString(),
                                  isSelected: _selectedCategoryName == category,
                                  isAddButton: false,
                                  isManaging: isManaging,
                                  profileRepository: _profileRepo,
                                  onTap: () {
                                    if (_managingCategory != null) {
                                      setState(() => _managingCategory = null);
                                    } else {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        _selectedCategoryName = category;
                                        _nameController.text =
                                            patientMap['full_name'] ?? '';
                                        _selectedGender =
                                            patientMap['gender'] ?? 'Male';

                                        if (patientMap['date_of_birth'] !=
                                            null) {
                                          final dob = DateTime.parse(
                                            patientMap['date_of_birth'],
                                          );
                                          _selectedDay = dob.day.toString();
                                          _selectedMonth = DateFormat(
                                            'MMMM',
                                          ).format(dob);
                                          _selectedYear = dob.year.toString();
                                        } else {
                                          _selectedDay = null;
                                          _selectedMonth = null;
                                          _selectedYear = null;
                                        }

                                        final savedImagePath =
                                            patientMap['image_path']
                                                as String?;
                                        if (savedImagePath != null &&
                                            savedImagePath.isNotEmpty &&
                                            !savedImagePath.startsWith(
                                              'http',
                                            )) {
                                          _newPatientImage =
                                              File(savedImagePath);
                                        } else {
                                          _newPatientImage = null;
                                        }
                                      });
                                      _updateDobText();
                                      _scheduleDraftSave();
                                    }
                                  },
                                  onLongPress: () {
                                    HapticFeedback.heavyImpact();
                                    setState(() {
                                      _managingCategory =
                                          isManaging ? null : category;
                                      _selectedCategoryName = category;
                                    });
                                  },
                                  onDeleteTap: () => _deleteCategory(category),
                                );
                              }),
                              if (_newPendingCategory != null)
                                _DynamicAvatarPill(
                                  name: _newPendingCategory!,
                                  imageUrl: _newPatientImage?.path,
                                  isSelected:
                                      _selectedCategoryName ==
                                      _newPendingCategory,
                                  isAddButton: false,
                                  isManaging:
                                      _managingCategory == _newPendingCategory,
                                  profileRepository: _profileRepo,
                                  onTap: () {
                                    if (_managingCategory != null) {
                                      setState(() => _managingCategory = null);
                                    } else {
                                      HapticFeedback.selectionClick();
                                      setState(
                                        () => _selectedCategoryName =
                                            _newPendingCategory!,
                                      );
                                    }
                                  },
                                  onLongPress: () {
                                    HapticFeedback.heavyImpact();
                                    setState(() {
                                      _managingCategory =
                                          _managingCategory ==
                                                  _newPendingCategory
                                              ? null
                                              : _newPendingCategory;
                                      _selectedCategoryName =
                                          _newPendingCategory!;
                                    });
                                  },
                                  onDeleteTap: () {
                                    setState(() {
                                      _newPendingCategory = null;
                                      _managingCategory = null;
                                      _selectedCategoryName = "My Self";
                                      _nameController.clear();
                                    });
                                    _fetchUserProfile();
                                  },
                                ),
                              _DynamicAvatarPill(
                                name: "Add",
                                imageUrl: null,
                                isSelected: false,
                                isAddButton: true,
                                isManaging: false,
                                profileRepository: _profileRepo,
                                onTap: () {
                                  if (_managingCategory != null) {
                                    setState(() => _managingCategory = null);
                                  }
                                  HapticFeedback.lightImpact();
                                  _showAddCategoryDialog();
                                },
                              ),
                            ],
                          ),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.fastOutSlowIn,
                          child:
                              (_savedPatients.isNotEmpty ||
                                      _newPendingCategory != null)
                                  ? Padding(
                                    padding: const EdgeInsets.only(
                                      top: 4,
                                      bottom: 12,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.touch_app_rounded,
                                          size: 13,
                                          color: textGrey.withValues(alpha: 0.6),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          "Long press a profile to manage",
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: textGrey.withValues(
                                              alpha: 0.8,
                                            ),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                  : const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 16),

                        // 3. Form Fields
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
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? AppColors.darkBorder
                                  : Colors.black.withValues(alpha: 0.05),
                              width: 1.0,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(31.0),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    child: AppTextField(
                                      controller: _nameController,
                                      hintText: "Enter full name",
                                      label: "Patient's Name",
                                      prefix: Icon(
                                        Icons.person_outline_rounded,
                                        color: textGrey.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    child: AppTextField(
                                      controller: _dobController,
                                      label: "Date of Birth",
                                      hintText: "Select Date of Birth",
                                      readOnly: true,
                                      prefix: Icon(
                                        Icons.calendar_month_rounded,
                                        color: textGrey.withValues(alpha: 0.6),
                                      ),
                                      onTap: () async {
                                        FocusScope.of(context).unfocus();

                                        final initialDate =
                                            (_selectedYear != null &&
                                                    _selectedMonth != null &&
                                                    _selectedDay != null)
                                                ? DateTime(
                                                  int.parse(_selectedYear!),
                                                  _monthStringToInt(
                                                    _selectedMonth!,
                                                  ),
                                                  int.parse(_selectedDay!),
                                                )
                                                : DateTime.now().subtract(
                                                  const Duration(
                                                    days: 365 * 25,
                                                  ),
                                                );

                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate: initialDate,
                                          firstDate: DateTime(1900),
                                          lastDate: DateTime.now(),
                                          builder: (context, child) {
                                            final isDark =
                                                Theme.of(context).brightness ==
                                                Brightness.dark;
                                            final baseFont =
                                                AppTextStyles.body(
                                                  context,
                                                ).fontFamily;

                                            return Theme(
                                              data: Theme.of(context).copyWith(
                                                textTheme: Theme.of(context)
                                                    .textTheme
                                                    .apply(
                                                      fontFamily: baseFont,
                                                    ),
                                                colorScheme: Theme.of(context)
                                                    .colorScheme
                                                    .copyWith(
                                                      primary: primaryGreen,
                                                      onPrimary: Colors.white,
                                                      onSurface:
                                                          isDark
                                                              ? Colors.white
                                                              : textDark,
                                                    ),
                                                dialogBackgroundColor:
                                                    Theme.of(context)
                                                        .colorScheme
                                                        .surface,
                                                dialogTheme: DialogTheme(
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          24,
                                                        ),
                                                  ),
                                                ),
                                                textButtonTheme:
                                                    TextButtonThemeData(
                                                      style:
                                                          TextButton.styleFrom(
                                                            foregroundColor:
                                                                primaryGreen,
                                                            textStyle: TextStyle(
                                                              fontFamily:
                                                                  baseFont,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w400,
                                                              fontSize: 15,
                                                            ),
                                                          ),
                                                    ),
                                              ),
                                              child: child!,
                                            );
                                          },
                                        );

                                        if (picked != null) {
                                          setState(() {
                                            _selectedDay = picked.day
                                                .toString();
                                            _selectedMonth = DateFormat(
                                              'MMMM',
                                            ).format(picked);
                                            _selectedYear = picked.year
                                                .toString();
                                          });
                                          _updateDobText();
                                          _scheduleDraftSave();
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    child: _buildLabel("Gender"),
                                  ),
                                  const SizedBox(height: 10),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color:
                                            Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? AppColors.darkSurface
                                                : const Color(0xFFF5F6F8),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        children:
                                            ["Male", "Female", "Others"].map((
                                              option,
                                            ) {
                                              final isSelected =
                                                  _selectedGender == option;
                                              return Expanded(
                                                child: GestureDetector(
                                                  onTap: () {
                                                    HapticFeedback
                                                        .selectionClick();
                                                    setState(
                                                      () => _selectedGender =
                                                          option,
                                                    );
                                                    _scheduleDraftSave();
                                                  },
                                                  behavior:
                                                      HitTestBehavior.opaque,
                                                  child: AnimatedContainer(
                                                    duration: const Duration(
                                                      milliseconds: 250,
                                                    ),
                                                    curve:
                                                        Curves.fastOutSlowIn,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 14,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: primaryGreen
                                                          .withValues(
                                                            alpha:
                                                                isSelected
                                                                    ? 1.0
                                                                    : 0.0,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: primaryGreen
                                                              .withValues(
                                                                alpha:
                                                                    isSelected
                                                                        ? 0.3
                                                                        : 0.0,
                                                              ),
                                                          blurRadius:
                                                              isSelected
                                                                  ? 8
                                                                  : 0,
                                                          offset:
                                                              isSelected
                                                                  ? const Offset(
                                                                    0,
                                                                    2,
                                                                  )
                                                                  : Offset.zero,
                                                        ),
                                                      ],
                                                    ),
                                                    alignment: Alignment.center,
                                                    child: FittedBox(
                                                      fit: BoxFit.scaleDown,
                                                      child:
                                                          AnimatedDefaultTextStyle(
                                                            duration:
                                                                const Duration(
                                                                  milliseconds:
                                                                      250,
                                                                ),
                                                            curve: Curves
                                                                .fastOutSlowIn,
                                                            style: TextStyle(
                                                              fontFamily:
                                                                  AppTextStyles.body(
                                                                    context,
                                                                  ).fontFamily,
                                                              fontSize: 14,
                                                              color:
                                                                  isSelected
                                                                      ? Colors
                                                                          .white
                                                                      : textGrey,
                                                              fontWeight:
                                                                  isSelected
                                                                      ? FontWeight
                                                                          .bold
                                                                      : FontWeight
                                                                          .w600,
                                                            ),
                                                            child: Text(option),
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    child: AppTextField(
                                      controller: _phoneController,
                                      hintText: "+8801000000000",
                                      isPhone: true,
                                      label: "Mobile Number",
                                      prefix: Icon(
                                        Icons.phone_outlined,
                                        color: textGrey.withValues(alpha: 0.6),
                                      ),
                                      readOnly:
                                          _selectedCategoryName != "My Self",
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    child: AppTextField(
                                      controller: _emailController,
                                      hintText: "email@example.com",
                                      label: "Email",
                                      prefix: Icon(
                                        Icons.email_outlined,
                                        color: textGrey.withValues(alpha: 0.6),
                                      ),
                                      readOnly:
                                          _selectedCategoryName != "My Self",
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  _buildMedicalRecordsSection(),
                                  if (_newPendingCategory != null ||
                                      (_selectedCategoryName != "My Self" &&
                                          _savedPatients.isNotEmpty)) ...[
                                    const SizedBox(height: 24),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                      ),
                                      child: SizedBox(
                                        height: 54,
                                        width: double.infinity,
                                        child: GestureDetector(
                                          onTap:
                                              _isSavingCategory
                                                  ? null
                                                  : _saveCategoryLocally,
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 200,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryGreen
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color: AppColors.primaryGreen
                                                    .withValues(alpha: 0.3),
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                if (_isSavingCategory)
                                                  const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child: AppLoader(size: 20),
                                                  )
                                                else
                                                  const Icon(
                                                    Icons.save_rounded,
                                                    color:
                                                        AppColors.primaryGreen,
                                                    size: 20,
                                                  ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  _isSavingCategory
                                                      ? "Saving..."
                                                      : "Save Patient Profile",
                                                  style: const TextStyle(
                                                    color: AppColors.primaryGreen,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
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
          ),
        ),
        bottomNavigationBar: AppBottomTray(
          child: PrimaryButton(
            label: "Continue",
            onTap: _handleContinue,
            borderRadius: 16,
            height: 54,
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return CustomAppBar(
      title: "Patient Details",
      onBackPressed: () => context.pop(),
      actions: const [SizedBox(width: 72)],
    );
  }

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
    if (widget.isManaging && !oldWidget.isManaging) _checkBackendLock();
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
      setState(() => _backendLockState = isLocked ? 'locked' : 'clear');
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
            ? (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05))
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
                                        widget.isSelected && !widget.isManaging
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
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.fastOutSlowIn,
                          top: 0,
                          bottom: 0,
                          right: widget.isManaging ? 54 : -size,
                          width: 54,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 250),
                            opacity: widget.isManaging ? 1.0 : 0.0,
                            child: GestureDetector(
                              onTap: () {
                                if (_backendLockState == 'clear') {
                                  HapticFeedback.mediumImpact();
                                  setState(
                                    () => _isUnlocked = !_isUnlocked,
                                  );
                                } else if (_backendLockState == 'locked') {
                                  _triggerShake();
                                }
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Center(
                                child: AnimatedBuilder(
                                  animation: _shakeAnimation,
                                  builder:
                                      (context, child) => Transform.translate(
                                        offset: Offset(
                                          _shakeAnimation.value,
                                          0,
                                        ),
                                        child: child,
                                      ),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    transitionBuilder:
                                        (child, animation) => ScaleTransition(
                                          scale: animation,
                                          child: child,
                                        ),
                                    child:
                                        _backendLockState == 'checking'
                                            ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child:
                                                  CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.grey,
                                                  ),
                                            )
                                            : Icon(
                                              _isUnlocked
                                                  ? Icons.lock_open_rounded
                                                  : Icons.lock_rounded,
                                              key: ValueKey(_isUnlocked),
                                              color:
                                                  _isUnlocked
                                                      ? AppColors.dangerRed
                                                      : context.colorTextLight
                                                          .withValues(
                                                            alpha: 0.6,
                                                          ),
                                              size: 24,
                                            ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.fastOutSlowIn,
                          top: 0,
                          bottom: 0,
                          right: widget.isManaging ? 0 : -size,
                          width: 54,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 250),
                            opacity: widget.isManaging ? 1.0 : 0.0,
                            child: GestureDetector(
                              onTap: _isUnlocked
                                  ? widget.onDeleteTap
                                  : _triggerShake,
                              behavior: HitTestBehavior.opaque,
                              child: Center(
                                child: Icon(
                                  Icons.delete_sweep_rounded,
                                  color:
                                      _isUnlocked
                                          ? AppColors.dangerRed
                                          : context.colorTextLight.withValues(
                                            alpha: 0.3,
                                          ),
                                  size: 26,
                                ),
                              ),
                            ),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.fastOutSlowIn,
                          width: size,
                          height: size,
                          padding: EdgeInsets.all(widget.isManaging ? 4.0 : 0.0),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primaryGreen.withValues(
                                alpha:
                                    widget.isSelected && !widget.isManaging
                                        ? 1.0
                                        : 0.0,
                              ),
                              width: 3,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: ClipOval(
                            child: widget.isAddButton
                                ? Icon(
                                  Icons.add_rounded,
                                  color: isDark ? Colors.white : Colors.black,
                                  size: 28,
                                )
                                : (widget.imageUrl != null &&
                                        widget.imageUrl!.isNotEmpty
                                    ? (_isLocalImagePath(widget.imageUrl!)
                                        ? Image.file(
                                          File(widget.imageUrl!),
                                          fit: BoxFit.cover,
                                        )
                                        : AppNetworkImage(
                                          imageUrl: widget.imageUrl!,
                                          fit: BoxFit.cover,
                                        ))
                                    : Icon(
                                      Icons.person,
                                      color: AppColors.primaryGreen,
                                      size: 28,
                                    )),
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

class _VaultRecordTile extends StatefulWidget {
  final MedicalRecord record;
  final bool isSelected;
  final VoidCallback onToggle;

  const _VaultRecordTile({
    required this.record,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  State<_VaultRecordTile> createState() => _VaultRecordTileState();
}

class _VaultRecordTileState extends State<_VaultRecordTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  Timer? _unlockTimer;

  bool get _isLocked {
    final lockedUntil = widget.record.lockedUntil;
    return lockedUntil != null && lockedUntil.isAfter(DateTime.now());
  }

  @override
  void initState() {
    super.initState();
    _setupUnlockTimer();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -6.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 1),
    ]).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void didUpdateWidget(_VaultRecordTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.record.lockedUntil != oldWidget.record.lockedUntil) {
      _setupUnlockTimer();
    }
  }

  void _setupUnlockTimer() {
    _unlockTimer?.cancel();
    if (_isLocked) {
      final remaining = widget.record.lockedUntil!.difference(DateTime.now());
      if (remaining.inMilliseconds > 0) {
        _unlockTimer = Timer(remaining, () {
          if (mounted) setState(() {});
        });
      }
    }
  }

  @override
  void dispose() {
    _unlockTimer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (_isLocked) {
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0.0);
    } else {
      HapticFeedback.selectionClick();
      widget.onToggle();
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _handleTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.isSelected
              ? AppColors.primaryGreen.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isSelected
                ? AppColors.primaryGreen
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
            width: widget.isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.record.recordType == 'Prescription'
                    ? Icons.medical_services_outlined
                    : Icons.analytics_outlined,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.record.recordType,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'For: ${widget.record.recordFor} • ${DateFormat('dd MMM yyyy').format(widget.record.recordDate)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (_isLocked)
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) => Transform.translate(
                  offset: Offset(_shakeAnimation.value, 0),
                  child: child,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_rounded,
                        size: 12,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Locked',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (widget.isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primaryGreen,
                size: 28,
              )
            else
              Icon(Icons.radio_button_unchecked, color: Colors.grey[400], size: 28),
          ],
        ),
      ),
    );
  }
}
