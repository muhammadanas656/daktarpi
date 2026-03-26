import 'dart:io';
import '../../../../core/constants/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';
import '../../../../presentation/widgets/app_network_image.dart';
import '../../../../presentation/widgets/app_text_field.dart';
import '../../../../presentation/widgets/primary_button.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_loader.dart';
import '../profile_notifier.dart';
import '../../data/profile_repository.dart';
import '../../data/user_profile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = false;
  bool _isInitialLoad = true;
  bool _isEditing = false;

  // Form Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _dobController = TextEditingController();

  DateTime? _selectedDate;
  String _countryCode = "+92"; // Default for region

  // NEW: Added to hold the ISO code for database filtering
  String? _selectedCountryIso;
  String? _calculatedUtcOffset;

  File? _imageFile;
  String? _avatarUrl;

  final _picker = ImagePicker();
  final _profileRepository = ProfileRepository();

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
    _dobController.dispose();
    super.dispose();
  }

  // --- GPS LOCATION LOGIC ---
  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        final result = await context.push<bool>('/location_permission');

        if (result != true) {
          serviceEnabled = await Geolocator.isLocationServiceEnabled();
          if (!serviceEnabled) {
            throw 'Location services are disabled. Please enable them.';
          }
        }
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied.';
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final offset = DateTime.now().timeZoneOffset;
      final hours = offset.inHours.abs().toString().padLeft(2, '0');
      final minutes = (offset.inMinutes.remainder(
        60,
      )).abs().toString().padLeft(2, '0');
      final sign = offset.isNegative ? '-' : '+';
      _calculatedUtcOffset = "$sign$hours:$minutes";

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String formattedAddress = [
          place.subLocality,
          place.locality,
          place.country,
        ].where((e) => e != null && e.isNotEmpty).join(', ');

        setState(() {
          _locationController.text = formattedAddress;
          // NEW: Capture the ISO code from GPS
          _selectedCountryIso = place.isoCountryCode;
        });

        if (mounted) {
          CustomSnackbar.showSuccess(
            context,
            "Location updated to $formattedAddress",
          );
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- LOAD PROFILE ---
  Future<void> _loadUserProfile() async {
    try {
      final userId = _profileRepository.currentUserId;
      if (userId != null) {
        final profile = await _profileRepository.getProfile(userId);

        if (profile != null) {
          setState(() {
            _nameController.text = profile.fullName;
            _locationController.text = profile.location ?? '';
            _avatarUrl = profile.profilePictureUrl;

            _selectedDate = profile.dateOfBirth;
            if (_selectedDate != null) {
              _dobController.text = DateFormat(
                'dd MMM yyyy',
              ).format(_selectedDate!);
            }

            _countryCode = profile.countryCode ?? "+92";
            _phoneController.text = profile.phoneNumber ?? '';

            // NEW: Load existing ISO code if they have one saved
            _selectedCountryIso = profile.countryIso;

            if (_nameController.text.trim().isNotEmpty) {
              _isEditing = true;
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
    } finally {
      if (mounted) {
        setState(() => _isInitialLoad = false);
      }
    }
  }

  // --- IMAGE PICKER ---
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
      if (mounted) {
        CustomSnackbar.showError(context, "Failed to pick image");
      }
    }
  }

  // --- DATE PICKER ---
  Future<void> _selectDate() async {
    try {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate ?? DateTime(2000),
        firstDate: DateTime(1900),
        lastDate: DateTime.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: AppColors.primaryGreen,
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
          _dobController.text = DateFormat('dd MMM yyyy').format(picked);
        });
      }
    } catch (e) {
      if (mounted) CustomSnackbar.showError(context, "Start date error: $e");
    }
  }

  Future<void> _deleteOldProfilePic(String userId) async {
    await _profileRepository.deleteOldProfilePic(userId, _avatarUrl);
  }

  // --- SAVE PROFILE ---
  Future<void> _saveProfile() async {
    List<String> missingFields = [];
    if (_nameController.text.trim().isEmpty) missingFields.add("Name");
    if (_phoneController.text.trim().isEmpty) {
      missingFields.add("Contact Number");
    }
    if (_selectedDate == null) missingFields.add("Date of Birth");
    if (_locationController.text.trim().isEmpty) missingFields.add("Location");

    if (missingFields.isNotEmpty) {
      if (missingFields.length == 4) {
        return CustomSnackbar.showError(
          context,
          "Please complete your profile to continue.",
        );
      } else {
        return CustomSnackbar.showError(
          context,
          "${missingFields.join(', ')} required.",
        );
      }
    }

    setState(() => _isLoading = true);

    try {
      final userId = _profileRepository.currentUserId;
      if (userId == null) throw "No active session.";

      String? finalAvatarUrl = _avatarUrl;

      if (_imageFile != null) {
        await _deleteOldProfilePic(userId);
        finalAvatarUrl = await _profileRepository.uploadProfilePicture(
          userId,
          _imageFile!,
        );
      }

      await _profileRepository.updateProfile(
        UserProfile(
          id: userId,
          fullName: _nameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          countryCode: _countryCode,
          countryIso: _selectedCountryIso, // NEW: Save the ISO code
          dateOfBirth: _selectedDate,
          location: _locationController.text.trim(),
          profilePictureUrl: finalAvatarUrl,
          updatedAt: DateTime.now(),
        ),
        utcOffset: _calculatedUtcOffset,
      );

      if (mounted) {
        setState(() => _isEditing = true);
        CustomSnackbar.showSuccess(
          context,
          _isEditing ? "Changes saved!" : "Profile created!",
        );

        await Future.delayed(Duration(milliseconds: 500));
        await ProfileNotifier.instance.loadProfile(forceRefresh: true);

        if (mounted) {
          if (_isEditing && context.canPop()) {
            context.pop(true);
          } else {
            context.go(AppRoutes.home);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(
          context,
          e.toString().replaceAll("Exception: ", ""),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onBackPress() async {
    if (_isEditing) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.home);
      }
      return;
    }

    final isNameMissing = _nameController.text.trim().isEmpty;
    final isPhoneMissing = _phoneController.text.trim().isEmpty;
    final isDobMissing = _selectedDate == null;
    final isLocationMissing = _locationController.text.trim().isEmpty;

    if (isNameMissing || isPhoneMissing || isDobMissing || isLocationMissing) {
      setState(() => _isLoading = true);
      try {
        await _profileRepository.signOut();
        if (mounted) context.go(AppRoutes.login);
      } catch (e) {
        if (mounted) context.go(AppRoutes.login);
      }
    } else {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.home);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark; // PRO FIX

    if (_isInitialLoad) {
      return Scaffold(
        backgroundColor: context.colorScaffoldBackground,
        body: const AppLoader(),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onBackPress();
      },
      child: Scaffold(
        backgroundColor: context.colorScaffoldBackground,
        body: Container(
          decoration: BoxDecoration(gradient: AppStyles.pageGradient(context)),
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                children: [
                // --- HEADER ---
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.only(
                    bottom: 40,
                    left: 20,
                    right: 20,
                    top: 60,
                  ),
                  decoration: BoxDecoration(
                    // PRO FIX: Deep Slate Medical Gradient for Dark Mode
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark 
                          ? const [Color(0xFF009668), Color(0xFF006B78)] 
                          : const [Color(0xFF00C689), Color(0xFF008FA0)], 
                    ),
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
                          InkWell(
                            onTap: _onBackPress,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                // PRO FIX: Adaptive back button on the green header
                                color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurface : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.arrow_back_ios_new,
                                size: 18,
                                // PRO FIX: Ensure icon contrasts with its dynamic background
                                color: isDark ? Colors.white : AppColors.primaryGreen,
                              ),
                            ),
                          ),
                          SizedBox(width: 40),
                        ],
                      ),
                      SizedBox(height: 30),
                      Text(
                        _isEditing ? "Edit Profile" : "Set up your profile",
                        style: AppTextStyles.h1(
                          context,
                        ).copyWith(color: Colors.white),
                      ),
                      SizedBox(height: 10),
                      Text(
                        _isEditing
                            ? "Make changes to your information below."
                            : "Update your profile to connect with your doctor.",
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body(context).copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: 35),
                      // --- AVATAR ---
                      Stack(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              // PRO FIX: Softer, glassmorphic border with a floating shadow
                              border: Border.all(
                                color: isDark 
                                    ? Colors.white.withValues(alpha: 0.15) 
                                    : Colors.white, 
                                width: 3,
                              ),
                              boxShadow: AppStyles.cardShadow(context),
                              color: isDark ? AppColors.darkSurface : Colors.grey[200],
                            ),
                            // PRO FIX: Replaced Image.network with offline-ready AppNetworkImage
                            child: ClipOval(
                              child: _imageFile != null
                                  ? Image.file(
                                      _imageFile!,
                                      fit: BoxFit.cover,
                                      width: 120,
                                      height: 120,
                                    )
                                  : (_avatarUrl != null && _avatarUrl!.isNotEmpty
                                      ? AppNetworkImage(
                                          imageUrl: _avatarUrl,
                                          width: 120,
                                          height: 120,
                                          circular: true,
                                          fallbackIconSize: 60,
                                        )
                                      : const Icon(
                                          Icons.person,
                                          size: 60,
                                          color: Colors.grey,
                                        )),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: InkWell(
                              onTap: _pickImage,
                              child: Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Color(0xFF6C757D),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
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
                SizedBox(height: 20),

                // --- FORM ---
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: EdgeInsets.all(20),
                    decoration: AppStyles.surfaceCard(
                      context,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Personal information",
                          style: AppTextStyles.h3(context),
                        ),
                        SizedBox(height: 20),
                        AppTextField(
                          controller: _nameController,
                          hintText: "Enter full name",
                          label: "Full Name *",
                        ),
                        SizedBox(height: 16),
                        AppTextField(
                          controller: _phoneController,
                          hintText: "Enter phone number",
                          label: "Contact Number *",
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          prefix: CountryCodePicker(
                            onChanged: (CountryCode country) {
                              setState(() {
                                _countryCode = country.dialCode ?? "+92";
                              });
                            },
                            initialSelection: _countryCode,
                            favorite: const ['PK', 'BD', 'IN', 'US'],
                            showCountryOnly: false,
                            showOnlyCountryWhenClosed: false,
                            alignLeft: false,
                            padding: EdgeInsets.zero,
                            textStyle: AppTextStyles.bodyBold(context),
                          ),
                        ),
                        SizedBox(height: 16),
                        AppTextField(
                          controller: _dobController,
                          hintText: "DD MM YYYY",
                          label: "Date of birth *",
                          readOnly: true,
                          onTap: _selectDate,
                        ),
                        SizedBox(height: 16),
                        AppTextField(
                          controller: _locationController,
                          hintText: "Use GPS to set location",
                          label: "Location *",
                          readOnly: true,
                          suffixIcon: InkWell(
                            onTap: _isLoading ? null : _getCurrentLocation,
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: EdgeInsets.all(12.0),
                              child:
                                  _isLoading
                                      ? SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: const AppLoader(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : Icon(
                                        Icons.my_location,
                                        color: AppColors.primaryGreen,
                                      ),
                            ),
                          ),
                        ),
                        SizedBox(height: 28),
                        PrimaryButton(
                          label: _isEditing ? "Save Changes" : "Continue",
                          onTap: _saveProfile,
                          isLoading: _isLoading,
                          height: 56,
                          borderRadius: 16,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 40),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }
}
