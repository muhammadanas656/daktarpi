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
  // --- COLORS (aliased from AppColors) ---
  static const Color primaryGreen = AppColors.primaryGreen;
  static const Color textDark = AppColors.textDark;
  static const Color textLight = AppColors.textLight;
  static const Color textGrey = AppColors.textGrey;
  static const Color borderColor = AppColors.borderColor;
  static const Color lightGreenBg = AppColors.lightGreenBg;

  final _profileRepo = ProfileRepository();
  final _draftRepo = BookingDraftRepository();
  Timer? _draftDebounce;
  bool _restoringDraft = false;

  // --- TYPOGRAPHY ---
  final TextStyle _labelStyle = const TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: textDark,
  );

  final TextStyle _inputStyle = const TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: textDark,
    height: 1.1,
  );

  final TextStyle _hintStyle = const TextStyle(
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
        final profile = await _profileRepo.getProfile(userId);
        final userEmail = _profileRepo.currentUserEmail;
        final patients = await _profileRepo.getSavedPatients(userId);

        if (mounted && profile != null) {
          _userProfileUrl = profile.profilePictureUrl;

          setState(() {
            _savedPatients = patients;

            if (_selectedCategoryName == "My Self") {
              _nameController.text = profile.fullName;
              _phoneController.text =
                  (profile.countryCode != null && profile.phoneNumber != null)
                      ? '${profile.countryCode} ${profile.phoneNumber}'
                      : (profile.phoneNumber ?? "");
              _emailController.text = userEmail ?? "";

              if (profile.dateOfBirth != null) {
                _selectedDay = profile.dateOfBirth!.day.toString();
                _selectedMonth = DateFormat('MMMM').format(profile.dateOfBirth!);
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
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Add Profile Category",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Who is this patient? (e.g. Brother, Wife)",
                      style: TextStyle(fontSize: 14, color: textLight),
                    ),
                    const SizedBox(height: 24),

                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F6F8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Center(
                        child: TextField(
                          controller: categoryController,
                          autofocus: true,
                          style: _inputStyle,
                          decoration: const InputDecoration(
                            hintText: "Category Name",
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            "Cancel",
                            style: TextStyle(
                              color: textLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
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
          ),
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
            title: const Text("Delete Category?"),
            content: Text("Are you sure you want to remove '$category'?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
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

  Future<void> _handleContinue() async {
    if (_nameController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _selectedDay == null ||
        _selectedMonth == null ||
        _selectedYear == null) {
      CustomSnackbar.showError(context, "Please fill all fields");
      return;
    }



    final monthInt = _monthStringToInt(_selectedMonth!);
    final dob = DateTime(int.parse(_selectedYear!), monthInt, int.parse(_selectedDay!));
    String? imagePath = _selectedCategoryName == "My Self" ? _userProfileUrl : _newPatientImage?.path;

    // Preserve relational patient caching logic natively
    final catToSave = _newPendingCategory ?? _selectedCategoryName;
    if (catToSave != "My Self") {
      final dobString = dob.toIso8601String().split('T')[0];
      _profileRepo.savePatientDetails({
        'relation': catToSave,
        'full_name': _nameController.text,
        'gender': _selectedGender,
        'date_of_birth': dobString,
        'image_path': _newPatientImage?.path,
      });
    }

    // Bundle the data for Step 2
    final patientDetails = {
      'name': _nameController.text,
      'phone': _phoneController.text,
      'email': _emailController.text,
      'gender': _selectedGender,
      'dob': dob.toIso8601String().split('T')[0],
      'image_url': imagePath,
    };

    unawaited(_clearDraft());

    // Navigate to the Confirmation Screen!
    if (mounted) {
      context.push(
        AppRoutes.paymentMethod, // This routes to your AppointmentConfirmationScreen
        extra: PaymentMethodArgs(
          doctor: widget.doctor,
          clinic: widget.clinic,
          patientDetails: patientDetails,
          appointmentDate: widget.initialDate,
          timeSlot: widget.timeSlot,
          idempotencyKey: widget.idempotencyKey,
        ),
      );
    }
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
        decoration: const BoxDecoration(gradient: AppStyles.pageGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 160),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Progress Bar
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
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  primaryGreen,
                                ),
                                minHeight: 6,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // 2. Patient Selector
                      const Text(
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
                            const SizedBox(width: 16),

                            // --- SAVED CATEGORIES (From new DB table) ---
                            ..._savedPatients.map((patientMap) {
                              final category = patientMap['relation'] as String;
                              final savedImagePath = patientMap['image_path'] as String?;
                              final hasValidImage = savedImagePath != null && savedImagePath.isNotEmpty && File(savedImagePath).existsSync();

                              return Padding(
                                padding: const EdgeInsets.only(right: 16),
                                child: Draggable<String>(
                                  data: category,
                                  feedback: Material(
                                    color: Colors.transparent,
                                    child: Opacity(
                                      opacity: 0.8,
                                      child: _buildOptionItem(
                                        isSelected: _selectedCategoryName == category,
                                        label: category,
                                        content: hasValidImage
                                            ? Image.file(File(savedImagePath as String), fit: BoxFit.cover)
                                            : Icon(Icons.person_outline, color: Colors.grey[400], size: 30),
                                        onTap: () {}, 
                                      ),
                                    ),
                                  ),
                                  childWhenDragging: Opacity(
                                    opacity: 0.3,
                                    child: _buildOptionItem(
                                      isSelected: _selectedCategoryName == category,
                                      label: category,
                                      content: hasValidImage
                                          ? Image.file(File(savedImagePath as String), fit: BoxFit.cover)
                                          : Icon(Icons.person_outline, color: Colors.grey[400], size: 30),
                                      onTap: () {},
                                    ),
                                  ),
                                  child: _buildOptionItem(
                                    isSelected: _selectedCategoryName == category,
                                    label: category,
                                    content: hasValidImage
                                        ? Image.file(File(savedImagePath as String), fit: BoxFit.cover)
                                        : Icon(Icons.person_outline, color: Colors.grey[400], size: 30),
                                    onTap: () {
                                      setState(() {
                                        _selectedCategoryName = category;
                                        
                                        // Auto-Fill the fields from DB
                                        _nameController.text = patientMap['full_name'] ?? '';
                                        _selectedGender = patientMap['gender'] ?? 'Male';
                                        
                                        if (patientMap['date_of_birth'] != null) {
                                          final dob = DateTime.parse(patientMap['date_of_birth']);
                                          _selectedDay = dob.day.toString();
                                          _selectedMonth = DateFormat('MMMM').format(dob);
                                          _selectedYear = dob.year.toString();
                                        }

                                        if (hasValidImage) {
                                          _newPatientImage = File(savedImagePath as String);
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
                                        : const Icon(
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
                              const SizedBox(width: 16),
                            ],

                            // --- ADD BUTTON ---
                            _buildOptionItem(
                              isSelected: false,
                              label: "Add",
                              content: const Icon(
                                Icons.add,
                                color: textDark,
                                size: 30,
                              ),
                              bgColor: const Color(0xFFF5F6F8),
                              onTap: _showAddCategoryDialog,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // --- DRAG TO DELETE BUCKET ---
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
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
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(bottom: 16),
                                      padding: const EdgeInsets.symmetric(
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
                                          const SizedBox(height: 8),
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
                                : const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 16),
                      // 3. Form Fields
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: AppStyles.surfaceCard(
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
                                const SizedBox(width: 12),
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
                                const SizedBox(width: 12),
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
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
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
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderColor),
                boxShadow: AppStyles.cardShadow,
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                size: 18,
                color: textDark,
              ),
            ),
          ),
          Text(
            "Patient Details",
            style: AppTextStyles.h3.copyWith(fontSize: 20),
          ),
          const SizedBox(width: 44),
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
                  color: bgColor ?? Colors.white,
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
                    padding: const EdgeInsets.all(5),
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
                    child: const Icon(
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
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
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
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: textGrey,
        size: 22,
      ),
      style: _inputStyle,
      menuMaxHeight: 240,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: _hintStyle,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primaryGreen),
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
            child:
                isSelected
                    ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
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
