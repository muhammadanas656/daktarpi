import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:country_code_picker/country_code_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = false;
  bool _isInitialLoad = true;

  // Form Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();

  DateTime? _selectedDate;
  String _countryCode = "+880";

  File? _imageFile;
  String? _avatarUrl;

  final _picker = ImagePicker();
  OverlayEntry? _errorOverlay;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _errorOverlay?.remove();
    super.dispose();
  }

  void _showTopError(String message) {
    if (!mounted) return;
    _errorOverlay?.remove();
    _errorOverlay = OverlayEntry(
      builder:
          (context) => Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            right: 20,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935),
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );

    Overlay.of(context).insert(_errorOverlay!);
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        _errorOverlay?.remove();
        _errorOverlay = null;
      }
    });
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final response =
            await Supabase.instance.client
                .from('profiles')
                .select()
                .eq('id', user.id)
                .maybeSingle();

        if (response != null) {
          setState(() {
            _nameController.text = response['full_name'] ?? '';
            _locationController.text = response['location'] ?? '';
            _avatarUrl = response['profile_picture_url'];

            if (response['date_of_birth'] != null) {
              _selectedDate = DateTime.tryParse(response['date_of_birth']);
            }

            String fullPhone = response['phone_number'] ?? '';
            if (fullPhone.isNotEmpty) {
              if (fullPhone.startsWith(_countryCode)) {
                _phoneController.text = fullPhone.substring(
                  _countryCode.length,
                );
              } else {
                _phoneController.text = fullPhone;
              }
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
    } finally {
      if (mounted) setState(() => _isInitialLoad = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      _showTopError("Failed to pick image");
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF00C689),
              onPrimary: Colors.white,
              onSurface: Colors.black,
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

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      return _showTopError("Name is required.");
    }
    if (_phoneController.text.trim().isEmpty) {
      return _showTopError("Contact Number is required.");
    }
    if (_selectedDate == null) {
      return _showTopError("Date of Birth is required.");
    }

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw "No active session.";

      final userId = user.id;
      String? finalAvatarUrl = _avatarUrl;

      if (_imageFile != null) {
        final fileExt = _imageFile!.path.split('.').last;
        final fileName = '$userId/avatar.$fileExt';

        try {
          await Supabase.instance.client.storage
              .from('profile_pictures')
              .upload(
                fileName,
                _imageFile!,
                fileOptions: const FileOptions(upsert: true),
              );

          finalAvatarUrl = Supabase.instance.client.storage
              .from('profile_pictures')
              .getPublicUrl(fileName);

          finalAvatarUrl =
              Uri.parse(finalAvatarUrl)
                  .replace(
                    queryParameters: {
                      't': DateTime.now().millisecondsSinceEpoch.toString(),
                    },
                  )
                  .toString();
        } on StorageException catch (e) {
          throw "Storage Error: ${e.message}";
        }
      }

      String fullPhoneNumber = "$_countryCode${_phoneController.text.trim()}";

      try {
        await Supabase.instance.client.from('profiles').upsert({
          'id': userId,
          'full_name': _nameController.text.trim(),
          'phone_number': fullPhoneNumber,
          'date_of_birth': _selectedDate?.toIso8601String(),
          'location': _locationController.text.trim(),
          'profile_picture_url': finalAvatarUrl,
          'updated_at': DateTime.now().toIso8601String(),
        });

        await Supabase.instance.client.auth.updateUser(
          UserAttributes(
            data: {
              'full_name': _nameController.text.trim(),
              'dob': _selectedDate?.toIso8601String(),
            },
          ),
        );
      } on PostgrestException catch (e) {
        throw "Database Error: ${e.message}";
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 12),
                const Flexible(
                  child: Text(
                    "Profile saved!",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF00C689),
            behavior: SnackBarBehavior.floating,
            elevation: 6,
            margin: const EdgeInsets.only(bottom: 40, left: 20, right: 20),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50),
            ),
          ),
        );

        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        _showTopError(e.toString().replaceAll("Exception: ", ""));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onBackPress() async {
    final isNameMissing = _nameController.text.trim().isEmpty;
    final isPhoneMissing = _phoneController.text.trim().isEmpty;
    final isDobMissing = _selectedDate == null;

    if (isNameMissing || isPhoneMissing || isDobMissing) {
      setState(() => _isLoading = true);
      try {
        await Supabase.instance.client.auth.signOut();
        if (mounted) {
          context.go('/login');
        }
      } catch (e) {
        if (mounted) context.go('/login');
      }
    } else {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF00C689);
    const hintTextColor = Color(0xFFC4C4C4);

    if (_isInitialLoad) {
      return const Scaffold(
        backgroundColor: Color(0xFFFBFBFB),
        body: Center(child: CircularProgressIndicator(color: primaryGreen)),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onBackPress();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFBFBFB),
        body: SingleChildScrollView(
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(
                  bottom: 40,
                  left: 20,
                  right: 20,
                  top: 60,
                ),
                decoration: const BoxDecoration(
                  color: primaryGreen,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left Button (Back)
                        InkWell(
                          onTap: _onBackPress,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new,
                              size: 18,
                              color: primaryGreen,
                            ),
                          ),
                        ),
                        // Center Title
                        const Text(
                          "Profile",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        // Right Spacer (Invisible) to balance the layout
                        const SizedBox(width: 40),
                      ],
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      "Set up your profile",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Update your profile to connect your doctor with\nbetter impression.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          child: CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.white,
                            backgroundImage:
                                _imageFile != null
                                    ? FileImage(_imageFile!) as ImageProvider
                                    : (_avatarUrl != null &&
                                            _avatarUrl!.isNotEmpty
                                        ? NetworkImage(_avatarUrl!)
                                        : null),
                            child:
                                (_imageFile == null &&
                                        (_avatarUrl == null ||
                                            _avatarUrl!.isEmpty))
                                    ? const Icon(
                                      Icons.person,
                                      size: 60,
                                      color: Colors.grey,
                                    )
                                    : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: InkWell(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFF6C757D),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // Inputs
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Personal information",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Name
                    _ProfileInputCard(
                      label: "Name *",
                      child: TextField(
                        controller: _nameController,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF555555),
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: "Enter your name",
                          hintStyle: TextStyle(color: hintTextColor),
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Contact
                    _ProfileInputCard(
                      label: "Contact Number *",
                      child: Row(
                        children: [
                          CountryCodePicker(
                            onChanged: (CountryCode country) {
                              setState(() {
                                _countryCode = country.dialCode ?? "+880";
                              });
                            },
                            initialSelection: 'BD',
                            favorite: const ['PK', 'BD', 'IN', 'US'],
                            showCountryOnly: false,
                            showOnlyCountryWhenClosed: false,
                            alignLeft: false,
                            padding: EdgeInsets.zero,
                            textStyle: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF555555),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Container(
                            height: 24,
                            width: 1,
                            color: Colors.grey[300],
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF555555),
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: "1712345678",
                                hintStyle: TextStyle(color: hintTextColor),
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // DOB
                    GestureDetector(
                      onTap: _selectDate,
                      child: _ProfileInputCard(
                        label: "Date of birth *",
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _selectedDate != null
                                    ? DateFormat(
                                      'dd MMM yyyy',
                                    ).format(_selectedDate!)
                                    : "DD MM YYYY",
                                style: TextStyle(
                                  fontSize: 16,
                                  color:
                                      _selectedDate != null
                                          ? const Color(0xFF555555)
                                          : hintTextColor,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.calendar_today_rounded,
                              size: 18,
                              color: Color(0xFF555555),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Location
                    _ProfileInputCard(
                      label: "Location",
                      child: TextField(
                        controller: _locationController,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF555555),
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: "Add Details",
                          hintStyle: TextStyle(color: hintTextColor),
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          foregroundColor: Colors.white,
                          elevation: 5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child:
                            _isLoading
                                ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Text(
                                  "Continue",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileInputCard extends StatelessWidget {
  final String label;
  final Widget child;
  const _ProfileInputCard({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              text: label.replaceAll('*', ''),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF00C689),
                fontWeight: FontWeight.w500,
              ),
              children: [
                if (label.contains('*'))
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
