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
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_routes.dart';
import '../models/booking_route_args.dart';

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
  Timer? _draftDebounce;
  bool _restoringDraft = false;

  // --- TYPOGRAPHY ---
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

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // State
  String _selectedGender = "Male";
  String? _selectedDay;
  String? _selectedMonth;
  String? _selectedYear;

  // Dynamic Category State
  List<Map<String, dynamic>> _savedPatients = [];
  String? _newPendingCategory;
  String _selectedCategoryName = "My Self";

  // Images
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

  // --- LOGIC ---
  Future<void> _bootstrapForm() async {
    await _fetchUserProfile();
    await _restoreDraftIfMatchingContext();
  }

  void _onFormFieldChanged() {
    if (_restoringDraft) return;
    _scheduleDraftSave();
  }

  void _scheduleDraftSave() {
    _draftDebounce?.cancel();
    _draftDebounce = Timer(Duration(milliseconds: 350), _persistDraftNow);
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
      });
    } catch (_) {
      // Draft save should never block booking flow.
    }
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
    } catch (_) {
      // Ignore draft restore failures and continue with live profile defaults.
    } finally {
      _restoringDraft = false;
    }
  }

  Future<void> _clearDraft() async {
    try {
      await _draftRepo.clearDraft();
    } catch (_) {
      // Ignore clear failures.
    }
  }

  Future<void> _fetchUserProfile() async {
    final userId = _profileRepo.currentUserId;
    if (userId != null) {
      try {
        // 1. Fetch patients FIRST (this will be instant thanks to cache)
        final patients = await _profileRepo.getSavedPatients(userId);

        if (mounted) {
          setState(() {
            _savedPatients = patients;
          });
        }

        // 2. Fetch profile in the background
        final profile = await _profileRepo.getProfile(userId);
        final userEmail = _profileRepo.currentUserEmail;

        if (mounted && profile != null) {
          _userProfileUrl = profile.profilePictureUrl;

          setState(() {
            if (_selectedCategoryName == "My Self") {
              _nameController.text = profile.fullName;
              _phoneController.text =
                  (profile.countryCode != null && profile.phoneNumber != null)
                      ? '${profile.countryCode} ${profile.phoneNumber}'
                      : (profile.phoneNumber ?? "");
              _emailController.text = userEmail ?? "";

              if (profile.dateOfBirth != null) {
                _selectedDay = profile.dateOfBirth!.day.toString();
                _selectedMonth = DateFormat(
                  'MMMM',
                ).format(profile.dateOfBirth!);
                _selectedYear = profile.dateOfBirth!.year.toString();
              }
            }
          });
        }
      } catch (e) {
        debugPrint("Error loading profile: $e");
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

  // --- CUSTOM DIALOG: Add Category ---
  Future<void> _showAddCategoryDialog() async {
    final TextEditingController categoryController = TextEditingController();

    final String? category = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          // PRO FIX: Dialog background
          backgroundColor: Theme.of(dialogCtx).colorScheme.surface,
          elevation: 0,
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Add Profile Category",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Who is this patient? (e.g. Brother, Wife)",
                    style: TextStyle(fontSize: 14, color: textLight),
                  ),
                  SizedBox(height: 24),

                  AppTextField(
                    controller: categoryController,
                    autofocus: true,
                    hintText: "Category Name",
                  ),
                  SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          "Cancel",
                          style: TextStyle(
                            color: textLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (categoryController.text.trim().isNotEmpty) {
                            Navigator.pop(
                              context,
                              categoryController.text.trim(),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          "Add",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
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

  Future<void> _deleteCategory(String category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text("Delete Category?"),
            content: Text("Are you sure you want to remove '$category'?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text("Delete", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        await _profileRepo.removePatientCategory(category);
        setState(() {
          _savedPatients.removeWhere((p) => p['relation'] == category);
          if (_selectedCategoryName == category) {
            _selectedCategoryName = "My Self";
            _fetchUserProfile();
          }
        });
        if (mounted) CustomSnackbar.showSuccess(context, "Category removed");
      } catch (e) {
        if (mounted) CustomSnackbar.showError(context, e.toString());
      }
    }
  }

  void _handleContinue() {
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

    String? imagePath =
        _selectedCategoryName == "My Self"
            ? _userProfileUrl
            : _newPatientImage?.path;

    // --- SAVE TO NEW DATABASE TABLE ---
    final catToSave = _newPendingCategory ?? _selectedCategoryName;
    if (catToSave != "My Self") {
      final monthInt = _monthStringToInt(_selectedMonth!);
      final dobString =
          DateTime(
            int.parse(_selectedYear!),
            monthInt,
            int.parse(_selectedDay!),
          ).toIso8601String().split('T')[0];

      _profileRepo.savePatientDetails({
        'relation': catToSave,
        'full_name': _nameController.text,
        'gender': _selectedGender,
        'date_of_birth': dobString,
        'image_path': _newPatientImage?.path,
      });
    }
    // ----------------------------------

    unawaited(_clearDraft());
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
          'imagePath': imagePath,
          'patientType': _selectedCategoryName,
          'newCategoryToSave': _newPendingCategory,
        },
      ),
    );
  }

  int _monthStringToInt(String month) {
    switch (month) {
      case 'January':
        return 1;
      case 'February':
        return 2;
      case 'March':
        return 3;
      case 'April':
        return 4;
      case 'May':
        return 5;
      case 'June':
        return 6;
      case 'July':
        return 7;
      case 'August':
        return 8;
      case 'September':
        return 9;
      case 'October':
        return 10;
      case 'November':
        return 11;
      case 'December':
        return 12;
      default:
        return 1;
    }
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    final int currentYear = DateTime.now().year;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppStyles.pageGradient(context)),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),

              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24, 10, 24, 160),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Progress Bar
                      Row(
                        children: [
                          Text("Step 1/2", style: _labelStyle),
                          SizedBox(width: 12),
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
                      SizedBox(height: 32),

                      // 2. Patient Selector
                      Text(
                        "Who is this patient?",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textDark,
                        ),
                      ),
                      SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // --- MY SELF OPTION (Always present, not draggable) ---
                            _buildOptionItem(
                              isSelected: _selectedCategoryName == "My Self",
                              label: "My Self",
                              content:
                                  _userProfileUrl != null
                                      ? Image.network(
                                        _userProfileUrl!,
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
                                });
                                _fetchUserProfile();
                                _scheduleDraftSave();
                              },
                            ),
                            SizedBox(width: 16),

                            // --- SAVED CATEGORIES (From new DB table) ---
                            ..._savedPatients.map((patientMap) {
                              final category = patientMap['relation'] as String;
                              final savedImagePath =
                                  patientMap['image_path'] as String?;
                              final hasValidImage =
                                  savedImagePath != null &&
                                  savedImagePath.isNotEmpty &&
                                  File(savedImagePath).existsSync();

                              return Padding(
                                padding: EdgeInsets.only(right: 16),
                                child: Draggable<String>(
                                  data: category,
                                  feedback: Material(
                                    color: Colors.transparent,
                                    child: Opacity(
                                      opacity: 0.8,
                                      child: _buildOptionItem(
                                        isSelected:
                                            _selectedCategoryName == category,
                                        label: category,
                                        content:
                                            hasValidImage
                                                ? Image.file(
                                                  File(savedImagePath),
                                                  fit: BoxFit.cover,
                                                )
                                                : Icon(
                                                  Icons.person_outline,
                                                  color: Colors.grey[400],
                                                  size: 30,
                                                ),
                                        onTap: () {},
                                      ),
                                    ),
                                  ),
                                  childWhenDragging: Opacity(
                                    opacity: 0.3,
                                    child: _buildOptionItem(
                                      isSelected:
                                          _selectedCategoryName == category,
                                      label: category,
                                      content:
                                          hasValidImage
                                              ? Image.file(
                                                File(savedImagePath),
                                                fit: BoxFit.cover,
                                              )
                                              : Icon(
                                                Icons.person_outline,
                                                color: Colors.grey[400],
                                                size: 30,
                                              ),
                                      onTap: () {},
                                    ),
                                  ),
                                  child: _buildOptionItem(
                                    isSelected:
                                        _selectedCategoryName == category,
                                    label: category,
                                    content:
                                        hasValidImage
                                            ? Image.file(
                                              File(savedImagePath),
                                              fit: BoxFit.cover,
                                            )
                                            : Icon(
                                              Icons.person_outline,
                                              color: Colors.grey[400],
                                              size: 30,
                                            ),
                                    onTap: () {
                                      setState(() {
                                        _selectedCategoryName = category;

                                        // Auto-Fill the fields from DB
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
                                        }

                                        if (hasValidImage) {
                                          _newPatientImage = File(
                                            savedImagePath,
                                          );
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
                                isSelected:
                                    _selectedCategoryName ==
                                    _newPendingCategory,
                                label: _newPendingCategory!,
                                content:
                                    _newPatientImage != null
                                        ? Image.file(
                                          _newPatientImage!,
                                          fit: BoxFit.cover,
                                        )
                                        : Icon(
                                          Icons.person_add,
                                          color: primaryGreen,
                                          size: 30,
                                        ),
                                bgColor: lightGreenBg,
                                showDeleteIcon:
                                    true, // Keep standard delete for un-saved pending item
                                onDeleteTap: () {
                                  setState(() {
                                    _newPendingCategory = null;
                                    _selectedCategoryName = "My Self";
                                  });
                                  _fetchUserProfile();
                                },
                                onTap:
                                    () => setState(
                                      () =>
                                          _selectedCategoryName =
                                              _newPendingCategory!,
                                    ),
                                onAvatarTap: _pickImage,
                                showEditIcon:
                                    _selectedCategoryName ==
                                    _newPendingCategory,
                              ),
                              SizedBox(width: 16),
                            ],

                            // --- ADD BUTTON ---
                            // --- ADD BUTTON ---
                            _buildOptionItem(
                              isSelected: false,
                              label: "Add",
                              content: Icon(
                                Icons.add,
                                color: textDark,
                                size: 30,
                              ),
                              // PRO FIX: Dynamic background for the Add category button
                              bgColor:
                                  Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppColors.darkSurface
                                      : const Color(0xFFF5F6F8),
                              onTap: _showAddCategoryDialog,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),

                      // --- DRAG TO DELETE BUCKET ---
                      AnimatedSize(
                        duration: Duration(milliseconds: 300),
                        child:
                            _savedPatients.isNotEmpty
                                ? DragTarget<String>(
                                  onAcceptWithDetails: (details) {
                                    // Triggers the exact same delete function when dropped!
                                    _deleteCategory(details.data);
                                  },
                                  builder: (
                                    context,
                                    candidateData,
                                    rejectedData,
                                  ) {
                                    // candidateData contains the category name when hovered over the bucket
                                    final isHovering = candidateData.isNotEmpty;

                                    return AnimatedContainer(
                                      duration: Duration(milliseconds: 200),
                                      width: double.infinity,
                                      margin: EdgeInsets.only(bottom: 16),
                                      padding: EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            isHovering
                                                ? Colors.red.withValues(
                                                  alpha: 0.1,
                                                )
                                                : Colors.grey.withValues(
                                                  alpha: 0.03,
                                                ),
                                        border: Border.all(
                                          color:
                                              isHovering
                                                  ? Colors.red
                                                  : Colors.grey.withValues(
                                                    alpha: 0.3,
                                                  ),
                                          width: isHovering ? 2 : 1,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            isHovering
                                                ? Icons.delete_forever
                                                : Icons.delete_outline,
                                            color:
                                                isHovering
                                                    ? Colors.red
                                                    : Colors.grey,
                                            size: 28,
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            isHovering
                                                ? "Drop to Delete '${candidateData.first}'!"
                                                : "Drag a category here to delete",
                                            style: TextStyle(
                                              color:
                                                  isHovering
                                                      ? Colors.red
                                                      : Colors.grey,
                                              fontSize: 13,
                                              fontWeight:
                                                  isHovering
                                                      ? FontWeight.bold
                                                      : FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                )
                                : SizedBox.shrink(),
                      ),
                      SizedBox(height: 16),
                      // 3. Form Fields
                      Container(
                        padding: EdgeInsets.all(20),
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
                            SizedBox(height: 16),

                            Text("Age", style: _labelStyle),
                            SizedBox(height: 10),
                            Row(
                              children: [
                                // DAY
                                Expanded(
                                  flex: 3,
                                  child: _buildDropdown(
                                    "Day",
                                    List.generate(
                                      31,
                                      (i) => (i + 1).toString(),
                                    ),
                                    _selectedDay,
                                    (val) {
                                      setState(() => _selectedDay = val);
                                      _scheduleDraftSave();
                                    },
                                  ),
                                ),
                                SizedBox(width: 12),
                                // MONTH
                                Expanded(
                                  flex: 4,
                                  child: _buildDropdown(
                                    "Month",
                                    [
                                      'January',
                                      'February',
                                      'March',
                                      'April',
                                      'May',
                                      'June',
                                      'July',
                                      'August',
                                      'September',
                                      'October',
                                      'November',
                                      'December',
                                    ],
                                    _selectedMonth,
                                    (val) {
                                      setState(() => _selectedMonth = val);
                                      _scheduleDraftSave();
                                    },
                                  ),
                                ),
                                SizedBox(width: 12),
                                // YEAR
                                Expanded(
                                  flex: 3,
                                  child: _buildDropdown(
                                    "Year",
                                    List.generate(
                                      100,
                                      (i) => (currentYear - i).toString(),
                                    ),
                                    _selectedYear,
                                    (val) {
                                      setState(() => _selectedYear = val);
                                      _scheduleDraftSave();
                                    },
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 16),
                            Text("Gender", style: _labelStyle),
                            SizedBox(height: 10),
                            Row(
                              children: [
                                _buildRadio("Male"),
                                SizedBox(width: 24),
                                _buildRadio("Female"),
                                SizedBox(width: 24),
                                _buildRadio("Others"),
                              ],
                            ),
                            SizedBox(height: 16),

                            AppTextField(
                              controller: _phoneController,
                              hintText: "+8801000000000",
                              isPhone: true,
                              label: "Mobile Number",
                            ),
                            SizedBox(height: 16),

                            AppTextField(
                              controller: _emailController,
                              hintText: "email@example.com",
                              label: "Email",
                            ),
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
      bottomSheet: Container(
        decoration: BoxDecoration(
          // PRO FIX: Dynamic surface and border
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color:
                  Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkBorder
                      : const Color(0xFFF0F0F0),
            ),
          ),
        ),
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: PrimaryButton(
                label: "Continue",
                onTap: _handleContinue,
                borderRadius: 16,
                height: 54,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildAppBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () => context.pop(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 44,
              height: 44,
              // PRO FIX: Dynamic surface and adaptive shadow
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
          SizedBox(width: 44),
        ],
      ),
    );
  }

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
    return Column(
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
                  // PRO FIX: Dynamic background for unselected options
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
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: content,
                ),
              ),
            ),

            // Edit Icon
            if (showEditIcon)
              Positioned(
                bottom: -2,
                right: -2,
                child: GestureDetector(
                  onTap: () {
                    onTap();
                    onAvatarTap?.call();
                  },
                  child: Container(
                    padding: EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.add_a_photo,
                      size: 14,
                      color: primaryGreen,
                    ),
                  ),
                ),
              ),

            // Delete Icon
            if (showDeleteIcon)
              Positioned(
                top: -6,
                right: -6,
                child: GestureDetector(
                  onTap: onDeleteTap,
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, size: 12, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: isSelected ? primaryGreen : textLight,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(
    String hint,
    List<String> items,
    String? value,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: textGrey, size: 22),
      style: _inputStyle,
      menuMaxHeight: 240,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: _hintStyle,
        filled: true,
        // PRO FIX: Dynamic dropdown fill
        fillColor: Theme.of(context).colorScheme.surface,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: context.colorBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: context.colorBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.primaryGreen),
        ),
      ),
      dropdownColor: Colors.white,
      items:
          items
              .map(
                (e) => DropdownMenuItem<String>(
                  value: e,
                  child: Text(
                    e,
                    style: _inputStyle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
      onChanged: onChanged,
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
            duration: Duration(milliseconds: 200),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? primaryGreen : Colors.grey[400]!,
                width: 2,
              ),
            ),
            child:
                isSelected
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
          SizedBox(width: 8),
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
