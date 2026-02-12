import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

class PatientDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> doctor;
  final Map<String, dynamic> clinic;
  final DateTime initialDate;

  const PatientDetailsScreen({
    super.key,
    required this.doctor,
    required this.clinic,
    required this.initialDate,
  });

  @override
  State<PatientDetailsScreen> createState() => _PatientDetailsScreenState();
}

class _PatientDetailsScreenState extends State<PatientDetailsScreen> {
  // --- COLORS ---
  static const Color primaryGreen = Color(0xFF00C689);
  static const Color textDark = Color(0xFF1A1A1A);
  static const Color textLight = Color(0xFF626F8D);
  static const Color textGrey = Color(0xFF9E9E9E);
  static const Color borderColor = Color(0xFFE0E0E0);
  static const Color lightGreenBg = Color(0xFFE0F7FA);

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

  // 0 = Custom/Add, 1 = My Self, 2 = My Child
  int _selectedProfileIndex = 1;
  String _customCategoryLabel = "Add";

  // Images
  String? _userProfileUrl;
  File? _newPatientImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // --- LOGIC ---
  Future<void> _fetchUserProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final data =
            await Supabase.instance.client
                .from('profiles')
                .select()
                .eq('id', user.id)
                .maybeSingle();

        if (mounted && data != null) {
          _userProfileUrl = data['profile_picture_url'];

          if (_selectedProfileIndex == 1) {
            setState(() {
              _nameController.text = data['full_name'] ?? "";
              _phoneController.text = data['phone_number'] ?? "";
              _emailController.text = user.email ?? "";

              if (data['date_of_birth'] != null) {
                final dob = DateTime.parse(data['date_of_birth']);
                _selectedDay = dob.day.toString();
                _selectedMonth = DateFormat('MMMM').format(dob);
                _selectedYear = dob.year.toString();
              }
            });
          }
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
        _customCategoryLabel = category;
        _selectedProfileIndex = 0;
        _nameController.clear();
        _phoneController.clear();
        _emailController.clear();
        _selectedDay = null;
        _selectedMonth = null;
        _selectedYear = null;
        _selectedGender = "Male";
        _newPatientImage = null;
      });
    }
  }

  void _switchToMode(int index) {
    if (index == 0) {
      if (_customCategoryLabel == "Add") {
        _showAddCategoryDialog();
      } else {
        setState(() => _selectedProfileIndex = 0);
      }
      return;
    }

    setState(() {
      _selectedProfileIndex = index;
      if (index == 1) {
        // My Self
        _newPatientImage = null;
        _fetchUserProfile();
      } else if (index == 2) {
        // Child: Clear form
        _nameController.clear();
        _phoneController.clear();
        _emailController.clear();
        _selectedDay = null;
        _selectedMonth = null;
        _selectedYear = null;
        _selectedGender = "Male";
        _newPatientImage = null;
      }
    });
  }

  void _handleContinue() {
    if (_nameController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _selectedDay == null ||
        _selectedMonth == null ||
        _selectedYear == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    final monthInt = _monthStringToInt(_selectedMonth!);
    final dob = DateTime(
      int.parse(_selectedYear!),
      monthInt,
      int.parse(_selectedDay!),
    );

    String? imagePath;
    if (_selectedProfileIndex == 1) {
      imagePath = _userProfileUrl;
    } else {
      imagePath = _newPatientImage?.path;
    }

    String patientType = 'other';
    if (_selectedProfileIndex == 1) patientType = 'self';
    if (_selectedProfileIndex == 2) patientType = 'child';
    if (_selectedProfileIndex == 0) patientType = _customCategoryLabel;

    context.push(
      '/payment_method',
      extra: {
        'doctor': widget.doctor,
        'clinic': widget.clinic,
        'appointmentDate': widget.initialDate,
        'patientDetails': {
          'name': _nameController.text,
          'phone': _phoneController.text,
          'email': _emailController.text,
          'gender': _selectedGender,
          'dob': dob.toIso8601String(),
          'imagePath': imagePath,
          'patientType': patientType,
        },
      },
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

  // --- HELPER: Consistent Box Decoration ---
  BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: borderColor),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 5,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    final int currentYear = DateTime.now().year;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              lightGreenBg,
              Colors.white,
              Colors.white,
              Color(0xFFE8F5E9),
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),

              Expanded(
                child: SingleChildScrollView(
                  // FIX: Increased bottom padding to 160 to clear bottom sheet + keyboard
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
                      Text(
                        "Who is this patient?",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textDark,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- ADD / CUSTOM OPTION ---
                          _buildOptionItem(
                            index: 0,
                            label: _customCategoryLabel,
                            content:
                                (_selectedProfileIndex == 0 &&
                                        _newPatientImage != null)
                                    ? Image.file(
                                      _newPatientImage!,
                                      fit: BoxFit.cover,
                                    )
                                    : Icon(
                                      _customCategoryLabel == "Add"
                                          ? Icons.add
                                          : Icons.person_add,
                                      color: primaryGreen,
                                      size: 30,
                                    ),
                            bgColor: lightGreenBg,
                            onTap: () => _switchToMode(0),
                            onAvatarTap: _pickImage,
                            showEditIcon: _selectedProfileIndex == 0,
                          ),
                          const SizedBox(width: 16),

                          // --- SELF OPTION ---
                          _buildOptionItem(
                            index: 1,
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
                            onTap: () => _switchToMode(1),
                          ),
                          const SizedBox(width: 16),

                          // --- CHILD OPTION ---
                          _buildOptionItem(
                            index: 2,
                            label: "My child",
                            content:
                                (_selectedProfileIndex == 2 &&
                                        _newPatientImage != null)
                                    ? Image.file(
                                      _newPatientImage!,
                                      fit: BoxFit.cover,
                                    )
                                    : Icon(
                                      Icons.child_care,
                                      color: Colors.grey[400],
                                      size: 32,
                                    ),
                            onTap: () => _switchToMode(2),
                            onAvatarTap: _pickImage,
                            showEditIcon: _selectedProfileIndex == 2,
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // 3. Form Fields
                      _buildLabel("Patient's Name"),
                      _buildTextField(_nameController, "Name"),

                      _buildLabel("Age"),
                      Row(
                        children: [
                          // DAY
                          Expanded(
                            flex: 3,
                            child: _buildDropdown(
                              "Day",
                              List.generate(31, (i) => (i + 1).toString()),
                              _selectedDay,
                              (val) => setState(() => _selectedDay = val),
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
                              (val) => setState(() => _selectedMonth = val),
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
                              (val) => setState(() => _selectedYear = val),
                            ),
                          ),
                        ],
                      ),

                      _buildLabel("Gender"),
                      Row(
                        children: [
                          _buildRadio("Male"),
                          const SizedBox(width: 24),
                          _buildRadio("Female"),
                          const SizedBox(width: 24),
                          _buildRadio("Others"),
                        ],
                      ),

                      _buildLabel("Mobile Number"),
                      _buildTextField(
                        _phoneController,
                        "+8801000000000",
                        isPhone: true,
                      ),

                      _buildLabel("Email"),
                      _buildTextField(_emailController, "email@example.com"),
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
        // Fix: Wrapped in SafeArea to prevent cut-off on modern phones
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _handleContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  "Continue",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
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
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildOptionItem({
    required int index,
    required String label,
    required Widget content,
    Color? bgColor,
    required VoidCallback onTap,
    VoidCallback? onAvatarTap,
    bool showEditIcon = false,
  }) {
    final isSelected = _selectedProfileIndex == index;

    return Column(
      children: [
        GestureDetector(
          onTap: () {
            onTap();
            if (isSelected && onAvatarTap != null && _newPatientImage == null) {
              onAvatarTap();
            }
          },
          child: Stack(
            children: [
              Container(
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
            ],
          ),
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

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 10),
      child: Text(text, style: _labelStyle),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    bool isPhone = false,
  }) {
    return Container(
      height: 54,
      decoration: _boxDecoration(),
      child: Center(
        child: TextField(
          controller: controller,
          keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
          style: _inputStyle,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: _hintStyle,
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(
    String hint,
    List<String> items,
    String? value,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      height: 54,
      decoration: _boxDecoration(),
      child: DropdownButtonHideUnderline(
        child: ButtonTheme(
          alignedDropdown: true,
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            isDense: true,
            itemHeight: 48,
            hint: Text(
              hint,
              style: _hintStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            icon: const Icon(
              Icons.keyboard_arrow_down,
              color: textGrey,
              size: 24,
            ),
            style: _inputStyle,
            elevation: 4,
            menuMaxHeight: 200,
            borderRadius: BorderRadius.circular(12),
            dropdownColor: Colors.white,
            items:
                items
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          e,
                          style: _inputStyle,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  Widget _buildRadio(String value) {
    final isSelected = _selectedGender == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedGender = value),
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
