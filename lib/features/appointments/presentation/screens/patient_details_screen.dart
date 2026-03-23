import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
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

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  String _selectedGender = "Male";
  String? _selectedDay;
  String? _selectedMonth;
  String? _selectedYear;

  List<Map<String, dynamic>> _savedPatients = [];
  String? _newPendingCategory;
  String _selectedCategoryName = "My Self";

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
    super.dispose();
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

            if (_selectedCategoryName == "My Self" && _nameController.text.isEmpty) {
              _nameController.text = profile.fullName;
              _phoneController.text = notifier.phoneNumber ?? "";
              _emailController.text = _profileRepo.currentUserEmail ?? "";

              if (profile.dateOfBirth != null) {
                _selectedDay = profile.dateOfBirth!.day.toString();
                _selectedMonth = DateFormat('MMMM').format(profile.dateOfBirth!);
                _selectedYear = profile.dateOfBirth!.year.toString();
              }
            }
          });
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

    final String? category = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dialogCtx) {
        return AppFloatingDialog(
          headerIcon: Icons.person_add_alt_1_rounded,
          iconColor: AppColors.primaryGreen,
          title: "Add Profile Category",
          description: "Who is this patient? (e.g. Brother, Wife)",
          isUpdating: false,
          content: AppTextField(
            controller: categoryController,
            autofocus: true,
            hintText: "Category Name",
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
                  height: 54, // PRO FIX: Coherent Button
                  borderRadius: 16,
                  onTap: () {
                    if (categoryController.text.trim().isNotEmpty) {
                      Navigator.pop(dialogCtx, categoryController.text.trim());
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (category != null && category.isNotEmpty) {
      setState(() {
        _newPendingCategory = category;
        _selectedCategoryName = category;
        _nameController.clear();
        _phoneController.clear();
        _emailController.clear();
        _selectedDay = null;
        _selectedMonth = null;
        _selectedYear = null;
        _selectedGender = "Male";
        _newPatientImage = null;
      });
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
              title: "Delete Category?",
              description: "Are you sure you want to remove '$category'?",
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
                      height: 54, // PRO FIX: Coherent Button
                      borderRadius: 16,
                      backgroundColor: AppColors.dangerRed,
                      onTap: isDeleting 
                          ? () {} 
                          : () async {
                              setDialogState(() => isDeleting = true);
                              await Future.delayed(const Duration(milliseconds: 150));
                              
                              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                              
                              final backupPatients = List<Map<String, dynamic>>.from(_savedPatients);
                              final backupSelected = _selectedCategoryName;

                              setState(() {
                                _savedPatients.removeWhere((p) => p['relation'] == category);
                                if (_selectedCategoryName == category) {
                                  _selectedCategoryName = "My Self";
                                  _nameController.clear();
                                  _fetchUserProfile();
                                }
                              });

                              try {
                                await _profileRepo.removePatientCategory(category);
                                if (mounted) CustomSnackbar.showSuccess(context, "Category removed");
                              } catch (e) {
                                if (mounted) {
                                  setState(() {
                                    _savedPatients = backupPatients;
                                    _selectedCategoryName = backupSelected;
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
    FocusScope.of(context).unfocus();

    if (!_recordsFetched) {
      setState(() => _isSavingCategory = true); 
      try {
        _availableRecords = await _medicalRecordRepo.fetchRecords();
        _recordsFetched = true;
      } catch (e) {
        if (mounted) CustomSnackbar.showError(context, "Failed to load records from vault.");
        setState(() => _isSavingCategory = false);
        return;
      }
      setState(() => _isSavingCategory = false);
    }

    List<MedicalRecord> tempSelected = List.from(_selectedRecords);

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

                    if (_availableRecords.isEmpty)
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
                          itemCount: _availableRecords.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final record = _availableRecords[index];
                            final isSelected = tempSelected.any((r) => r.id == record.id);
                            
                            return InkWell(
                              onTap: () {
                                setSheetState(() {
                                  if (isSelected) {
                                    tempSelected.removeWhere((r) => r.id == record.id);
                                  } else {
                                    tempSelected.add(record);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primaryGreen.withValues(alpha: 0.1) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected ? AppColors.primaryGreen : context.colorBorder,
                                    width: isSelected ? 2 : 1,
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
                                        record.recordType == 'Prescription' ? Icons.medical_services_outlined : Icons.analytics_outlined,
                                        color: AppColors.primaryGreen,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            record.recordType,
                                            maxLines: 2, // PRO FIX: Let vault titles wrap beautifully
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          Text(
                                            "For: ${record.recordFor} • ${DateFormat('dd MMM yyyy').format(record.recordDate)}",
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(Icons.check_circle_rounded, color: AppColors.primaryGreen, size: 28)
                                    else
                                      Icon(Icons.radio_button_unchecked, color: Colors.grey[400], size: 28),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: PrimaryButton(
                        label: "Done",
                        height: 54, // PRO FIX: Coherent Button
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
        Text("Medical Records (Optional)", style: _labelStyle),
        const SizedBox(height: 10),
        if (_selectedRecords.isNotEmpty) ...[
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: _selectedRecords.length + 1,
              itemBuilder: (context, index) {
                if (index == _selectedRecords.length) {
                  return GestureDetector(
                    onTap: _showMedicalRecordsBottomSheet,
                    child: Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.add, color: AppColors.primaryGreen),
                    ),
                  );
                }
                final record = _selectedRecords[index];
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        record.recordType == 'Prescription' ? Icons.medical_services_outlined : Icons.analytics_outlined,
                        size: 18,
                        color: AppColors.primaryGreen,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(record.recordType, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textDark)),
                          Text(DateFormat('dd MMM yyyy').format(record.recordDate), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () {
                          setState(() => _selectedRecords.removeAt(index));
                          _scheduleDraftSave();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.close, size: 14, color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ] else ...[
          // --- PRO FIX: Standardized Vault Button Height & Radius ---
          GestureDetector(
            onTap: _showMedicalRecordsBottomSheet,
            child: Container(
              height: 54, 
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(
                  color: isDark
                      ? AppColors.primaryGreen.withValues(alpha: 0.5)
                      : AppColors.primaryGreen,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(16), 
                color: isDark
                    ? AppColors.primaryGreen.withValues(alpha: 0.1)
                    : context.colorLightGreenBg.withValues(alpha: 0.3),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.folder_shared_outlined, color: AppColors.primaryGreen),
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
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final int currentYear = DateTime.now().year;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false, 
        body: Container(
          decoration: BoxDecoration(gradient: AppStyles.pageGradient(context)),
          child: SafeArea(
            child: Column(
              children: [
                _buildAppBar(),

                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(24, 10, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text("Step 1/2", style: _labelStyle),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: 0.5,
                                  backgroundColor: primaryGreen.withValues(
                                    alpha: 0.1,
                                  ),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    primaryGreen,
                                  ),
                                  minHeight: 6,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        Text(
                          "Who is this patient?",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.none,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // --- MY SELF OPTION ---
                              _buildOptionItem(
                                isSelected: _selectedCategoryName == "My Self",
                                label: "My Self",
                                content:
                                    _userProfileUrl != null
                                        ? AppNetworkImage(
                                            imageUrl: _userProfileUrl!,
                                            fit: BoxFit.cover,
                                          )
                                        : Icon(
                                          Icons.person,
                                          color: Colors.grey[400],
                                          size: 30,
                                        ),
                                onTap: () {
                                  setState(() {
                                    _selectedCategoryName = "My Self";
                                    _newPatientImage = null;
                                    _nameController.clear();
                                  });
                                  _fetchUserProfile();
                                  _scheduleDraftSave();
                                },
                              ),
                              const SizedBox(width: 16),

                              ..._savedPatients.map((patientMap) {
                                final category = patientMap['relation'] as String;
                                final savedImagePath = patientMap['image_path'] as String?;

                                Widget renderCategoryAvatar() {
                                  if (savedImagePath != null && savedImagePath.isNotEmpty) {
                                    return AppNetworkImage(
                                      imageUrl: savedImagePath,
                                      fit: BoxFit.cover,
                                    );
                                  } else {
                                    return Icon(
                                      Icons.person_outline,
                                      color: Colors.grey[400],
                                      size: 30,
                                    );
                                  }
                                }

                                return Padding(
                                  padding: const EdgeInsets.only(right: 16),
                                  child: LongPressDraggable<String>(
                                    data: category,
                                    delay: const Duration(milliseconds: 200),
                                    dragAnchorStrategy: childDragAnchorStrategy, 
                                    feedback: Material(
                                      color: Colors.transparent,
                                      child: Opacity(
                                        opacity: 0.9,
                                        child: SizedBox(
                                          width: 80,
                                          child: _buildOptionItem(
                                            isSelected: true,
                                            label: category,
                                            content: renderCategoryAvatar(),
                                            onTap: () {},
                                          ),
                                        ),
                                      ),
                                    ),
                                    childWhenDragging: Opacity(
                                      opacity: 0.3,
                                      child: _buildOptionItem(
                                        isSelected: _selectedCategoryName == category,
                                        label: category,
                                        content: renderCategoryAvatar(),
                                        onTap: () {},
                                      ),
                                    ),
                                    child: _buildOptionItem(
                                      isSelected: _selectedCategoryName == category,
                                      label: category,
                                      content: renderCategoryAvatar(),
                                      onTap: () {
                                        setState(() {
                                          _selectedCategoryName = category;
                                          _nameController.text = patientMap['full_name'] ?? '';
                                          _selectedGender = patientMap['gender'] ?? 'Male';

                                          if (patientMap['date_of_birth'] != null) {
                                            final dob = DateTime.parse(patientMap['date_of_birth']);
                                            _selectedDay = dob.day.toString();
                                            _selectedMonth = DateFormat('MMMM').format(dob);
                                            _selectedYear = dob.year.toString();
                                          }

                                          if (savedImagePath != null && savedImagePath.isNotEmpty && !savedImagePath.startsWith('http')) {
                                            _newPatientImage = File(savedImagePath);
                                          } else {
                                            _newPatientImage = null;
                                          }
                                        });
                                        _scheduleDraftSave();
                                      },
                                    ),
                                  ),
                                );
                              }),

                              // --- NEW PENDING CATEGORY ---
                              if (_newPendingCategory != null) ...[
                                _buildOptionItem(
                                  isSelected: _selectedCategoryName == _newPendingCategory,
                                  label: _newPendingCategory!,
                                  content: _newPatientImage != null
                                      ? AppNetworkImage(imageUrl: _newPatientImage!.path, fit: BoxFit.cover)
                                      : Container(
                                          color: Theme.of(context).brightness == Brightness.dark 
                                              ? AppColors.darkSurface 
                                              : const Color(0xFFEAF2F8),
                                          child: Icon(
                                            Icons.add_a_photo_rounded, 
                                            color: AppColors.primaryGreen.withValues(alpha: 0.6), 
                                            size: 28,
                                          ),
                                        ),
                                  bgColor: lightGreenBg,
                                  showDeleteIcon: true, 
                                  onDeleteTap: () {
                                    setState(() {
                                      _newPendingCategory = null;
                                      _selectedCategoryName = "My Self";
                                      _nameController.clear();
                                    });
                                    _fetchUserProfile();
                                  },
                                  onTap: () => setState(() => _selectedCategoryName = _newPendingCategory!),
                                  onAvatarTap: _pickImage,
                                  showEditIcon: _selectedCategoryName == _newPendingCategory,
                                ),
                                const SizedBox(width: 16),
                              ],

                              // --- ADD BUTTON ---
                              _buildOptionItem(
                                isSelected: false,
                                label: "Add",
                                content: Icon(Icons.add, color: textDark, size: 30),
                                bgColor: Theme.of(context).brightness == Brightness.dark
                                        ? AppColors.darkSurface
                                        : const Color(0xFFF5F6F8),
                                onTap: _showAddCategoryDialog,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          child:
                              _savedPatients.isNotEmpty
                                  ? DragTarget<String>(
                                    onAcceptWithDetails: (details) {
                                      _deleteCategory(details.data);
                                    },
                                    builder: (context, candidateData, rejectedData) {
                                      final isHovering = candidateData.isNotEmpty;
                                      return AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        width: double.infinity,
                                        margin: const EdgeInsets.only(bottom: 16),
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        decoration: BoxDecoration(
                                          color: isHovering
                                                  ? Colors.red.withValues(alpha: 0.1)
                                                  : Colors.grey.withValues(alpha: 0.03),
                                          border: Border.all(
                                            color: isHovering
                                                    ? Colors.red
                                                    : Colors.grey.withValues(alpha: 0.3),
                                            width: isHovering ? 2 : 1,
                                          ),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Column(
                                          children: [
                                            Icon(
                                              isHovering ? Icons.delete_forever : Icons.delete_outline,
                                              color: isHovering ? Colors.red : Colors.grey,
                                              size: 28,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              isHovering
                                                  ? "Drop to Delete '${candidateData.first}'!"
                                                  : "Hold & drag a category here to delete",
                                              style: TextStyle(
                                                color: isHovering ? Colors.red : Colors.grey,
                                                fontSize: 13,
                                                fontWeight: isHovering ? FontWeight.bold : FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  )
                                  : const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 16),

                        // 3. Form Fields
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: AppStyles.surfaceCard(
                            context,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppTextField(
                                controller: _nameController,
                                hintText: "Name",
                                label: "Patient's Name",
                              ),
                              const SizedBox(height: 16),

                              Text("Age", style: _labelStyle),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: _buildDropdown(
                                      "Day",
                                      List.generate(31, (i) => (i + 1).toString()),
                                      _selectedDay,
                                      (val) {
                                        setState(() => _selectedDay = val);
                                        _scheduleDraftSave();
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 4,
                                    child: _buildDropdown(
                                      "Month",
                                      [
                                        'January', 'February', 'March', 'April', 'May', 'June',
                                        'July', 'August', 'September', 'October', 'November', 'December',
                                      ],
                                      _selectedMonth,
                                      (val) {
                                        setState(() => _selectedMonth = val);
                                        _scheduleDraftSave();
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 3,
                                    child: _buildDropdown(
                                      "Year",
                                      List.generate(100, (i) => (currentYear - i).toString()),
                                      _selectedYear,
                                      (val) {
                                        setState(() => _selectedYear = val);
                                        _scheduleDraftSave();
                                      },
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),
                              Text("Gender", style: _labelStyle),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _buildRadio("Male"),
                                  const SizedBox(width: 24),
                                  _buildRadio("Female"),
                                  const SizedBox(width: 24),
                                  _buildRadio("Others"),
                                ],
                              ),
                              const SizedBox(height: 16),

                              AppTextField(
                                controller: _phoneController,
                                hintText: "+8801000000000",
                                isPhone: true,
                                label: "Mobile Number",
                              ),
                              const SizedBox(height: 16),

                              AppTextField(
                                controller: _emailController,
                                hintText: "email@example.com",
                                label: "Email",
                              ),
                              
                              const SizedBox(height: 24),
                              _buildMedicalRecordsSection(),

                              if (_newPendingCategory != null || (_selectedCategoryName != "My Self" && _savedPatients.isNotEmpty)) ...[
                                const SizedBox(height: 24),
                                // --- PRO FIX: Standardized Outlined Button ---
                                SizedBox(
                                  height: 54, // Match PrimaryButton height
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: _isSavingCategory ? null : _saveCategoryLocally,
                                    icon: _isSavingCategory
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: AppLoader(
                                              size: 20,
                                            ),
                                          )
                                        : const Icon(Icons.save_rounded, color: AppColors.primaryGreen),
                                    label: Text(
                                      _isSavingCategory ? "Saving..." : "Save Patient Profile",
                                      style: const TextStyle(
                                        color: AppColors.primaryGreen,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16), // Match PrimaryButton radius
                                      ),
                                    ),
                                  ),
                                ),
                              ]
                            ],
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
        bottomNavigationBar: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkBorder
                        : const Color(0xFFF0F0F0),
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: PrimaryButton(
              label: "Continue",
              onTap: _handleContinue,
              borderRadius: 16,
              height: 54,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () => context.pop(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 44,
              height: 44,
              decoration: AppStyles.surfaceCard(
                context,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.arrow_back_ios_new, size: 18, color: textDark),
            ),
          ),
          Text(
            "Patient Details",
            style: AppTextStyles.h3(context).copyWith(fontSize: 20),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  // --- PRO FIX: Enabled 2-line Text Wrapping for Long Custom Categories ---
  Widget _buildOptionItem({
    required bool isSelected,
    required String label,
    required Widget content,
    Color? bgColor,
    required VoidCallback onTap,
    VoidCallback? onAvatarTap,
    bool showEditIcon = false,
    bool showDeleteIcon = false,
    VoidCallback? onDeleteTap,
  }) {
    return SizedBox(
      width: 88, // Expand slightly to comfortably fit long names wrapping
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: () {
                  onTap();
                  if (isSelected &&
                      onAvatarTap != null &&
                      _newPatientImage == null) {
                    onAvatarTap();
                  }
                },
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: bgColor ?? Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? primaryGreen : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: content,
                  ),
                ),
              ),
              if (showEditIcon)
                Positioned(
                  bottom: -4,
                  right: -4,
                  child: GestureDetector(
                    onTap: () {
                      onTap();
                      onAvatarTap?.call();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: primaryGreen,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.surface,
                          width: 2.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              if (showDeleteIcon)
                Positioned(
                  top: -6,
                  right: -6,
                  child: GestureDetector(
                    onTap: onDeleteTap,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppColors.dangerRed,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.surface,
                          width: 2.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.close_rounded, 
                        size: 12, 
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2, // Allow "Brother in law" to wrap!
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isSelected ? primaryGreen : textLight,
              fontSize: 13, // Scaled down to fit two lines elegantly
              height: 1.2,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(
    String hint,
    List<String> items,
    String? value,
    ValueChanged<String?> onChanged,
  ) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus(); 
        _showBottomSheetSelection(hint, items, value, onChanged);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.colorBorder,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                value ?? hint,
                style: value == null ? _hintStyle : _inputStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: textGrey, size: 22),
          ],
        ),
      ),
    );
  }

  void _showBottomSheetSelection(String title, List<String> items, String? currentValue, ValueChanged<String?> onChanged) {
    showModalBottomSheet(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4), 
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 24),
              Text(title, style: AppTextStyles.h3(context).copyWith(fontSize: 18)),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isSelected = item == currentValue;
                    
                    return InkWell(
                      onTap: () {
                        onChanged(item);
                        Navigator.pop(ctx);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primaryGreen.withValues(alpha: 0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? AppColors.primaryGreen.withValues(alpha: 0.5) : context.colorBorder.withValues(alpha: 0.3),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item,
                              style: TextStyle(
                                color: isSelected ? AppColors.primaryGreen : context.colorTextDark,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                fontSize: 16,
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle_rounded, color: AppColors.primaryGreen, size: 22),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRadio(String value) {
    final isSelected = _selectedGender == value;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedGender = value);
        _scheduleDraftSave();
      },
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? primaryGreen : Colors.grey[400]!,
                width: 2,
              ),
            ),
            child: isSelected
                    ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: primaryGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                    : null,
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              color: isSelected ? textDark : Colors.grey[600],
              fontSize: 15,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}