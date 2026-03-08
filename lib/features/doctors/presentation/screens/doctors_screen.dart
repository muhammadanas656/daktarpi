import 'dart:async';
import '../../../../core/constants/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../favorites_notifier.dart';
import '../../data/doctor_repository.dart';
import '../models/doctors_route_args.dart';
import '../../../../presentation/widgets/custom_search_bar.dart';
import '../../../../presentation/widgets/doctor_list_card.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';
import '../../../profile/presentation/profile_notifier.dart';

class DoctorsScreen extends StatefulWidget {
  const DoctorsScreen({super.key});

  @override
  State<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends State<DoctorsScreen> {
  final _doctorRepo = DoctorRepository();
  final _favNotifier = FavoritesNotifier.instance;
  final _profileNotifier = ProfileNotifier.instance;

  // --- STATE ---
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _doctors = [];
  List<Map<String, dynamic>> _hospitals = [];
  List<Map<String, dynamic>> _clinics = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';
  Timer? _debounce;

  final List<String> _filters = [
    'All',
    'Nearest',
    'Hospital',
    'Clinic',
    'Best Rated',
  ];

  @override
  void initState() {
    super.initState();
    _fetchDoctors();
    _searchController.addListener(_onSearchChanged);
    _favNotifier.addListener(_onFavoritesChanged);
    _profileNotifier.addListener(_onProfileChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _favNotifier.removeListener(_onFavoritesChanged);
    _profileNotifier.removeListener(_onProfileChanged);
    super.dispose();
  }

  void _onFavoritesChanged() {
    if (mounted) setState(() {});
  }

  void _onProfileChanged() {
    if (mounted) setState(() {});
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(Duration(milliseconds: 500), () {
      // Trigger refresh with search query
      setState(() => _isLoading = true);
      _fetchDoctors();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    FocusScope.of(context).unfocus();
  }

  // --- DATA FETCHING ---
  Future<void> _fetchDoctors() async {
    final query = _searchController.text.trim();

    try {
      // Apply sorting based on filter
      String sortBy = 'rating'; // Default sort
      bool ascending = false;
      double? userLat;
      double? userLng;

      if (_selectedFilter == 'Best Rated') {
        sortBy = 'rating';
        ascending = false;
      } else if (_selectedFilter == 'Nearest') {
        // --- LOCATION LOGIC ---
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          if (mounted) {
            CustomSnackbar.showError(
              context,
              "Location services are disabled.",
            );
          }
          // Fallback to default sort
        } else {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
            if (permission == LocationPermission.denied) {
              if (mounted) {
                CustomSnackbar.showError(context, "Location permission denied");
              }
            }
          }

          if (permission == LocationPermission.deniedForever) {
            if (mounted) {
              CustomSnackbar.showError(
                context,
                "Location permissions are permanently denied",
              );
            }
          }

          if (permission == LocationPermission.whileInUse ||
              permission == LocationPermission.always) {
            try {
              final position = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.medium,
              );
              userLat = position.latitude;
              userLng = position.longitude;
            } catch (e) {
              debugPrint("Error getting location: $e");
            }
          }
        }
      }
      // Extract user location from profile
      final userLocation = _profileNotifier.profile?.location;
      final countryIso = _profileNotifier.profile?.countryIso;

      final doctors = await _doctorRepo.fetchAllDoctors(
        query: query,
        sortBy: sortBy,
        ascending: ascending,
        userLat: userLat,
        userLng: userLng,
        userLocation: userLocation,
        countryIso: countryIso,
      );

      debugPrint(
        "DoctorsScreen: Found ${doctors.length} doctors for ISO $countryIso",
      );

      // Fetch hospitals
      final hospitals = await _doctorRepo.fetchHospitals(query: query);

      // Fetch clinics
      final clinics = await _doctorRepo.fetchClinicsList(query: query);

      // Ensure favorites are loaded
      if (!_favNotifier.isLoaded) {
        await _favNotifier.loadFavorites();
      }

      if (mounted) {
        setState(() {
          _doctors = doctors;

          // Client-side filtering for 'Hospital' - REMOVED as we now have dedicated fetch
          // if (_selectedFilter == 'Hospital') { ... }

          _doctors = doctors;
          _hospitals = hospitals;
          _clinics = clinics;

          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching doctors/hospitals: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- NAVIGATION ---
  Future<void> _navigateToDoctorDetails(int doctorId) async {
    await context.push(AppRoutes.doctorDetailsById('$doctorId'));
  }

  void _onFilterTap(String filter) {
    setState(() {
      _selectedFilter = filter;
      _isLoading = true;
    });
    _fetchDoctors();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppStyles.pageGradient(context)),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildSearchBar(),
              _buildFilterChips(),
              Expanded(
                child:
                    _isLoading
                        ? Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryGreen,
                          ),
                        )
                        : RefreshIndicator(
                          onRefresh: () async => _fetchDoctors(),
                          color: AppColors.primaryGreen,
                          child:
                              _selectedFilter == 'Hospital'
                                  ? _buildHospitalGrid()
                                  : _selectedFilter == 'Clinic'
                                  ? _buildClinicGrid()
                                  : _buildDoctorList(),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Doctors", style: AppTextStyles.h1(context)),
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              // PRO FIX: Dynamic surface color for the bell
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
              boxShadow: AppStyles.cardShadow(context), // PRO FIX: Dynamic shadow
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              color: context.colorTextDark,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: CustomSearchBar(
        controller: _searchController,
        hintText: "Search doctor, specialty...",
        showClearIcon: _searchController.text.isNotEmpty,
        onClear: _clearSearch,
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 40,
      margin: EdgeInsets.only(top: 24, bottom: 16),
      child: ListView.separated(
        clipBehavior: Clip.none, // PRO FIX: Prevent clipping of active shadow
        padding: EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => SizedBox(width: 12),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilter == filter;

          return GestureDetector(
            onTap: () => _onFilterTap(filter),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                // PRO FIX: Dynamic background for unselected chips
                color: isSelected 
                    ? AppColors.primaryGreen 
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20), // Premium Radius
                border: isSelected
                    ? null
                    : Border.all(
                        // PRO FIX: Deep slate border in Dark Mode
                        color: Theme.of(context).brightness == Brightness.dark 
                            ? AppColors.darkBorder 
                            : context.colorBorder.withValues(alpha: 0.5),
                      ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primaryGreen.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ]
                    // PRO FIX: Removes glowing white shadow in dark mode
                    : AppStyles.cardShadow(context), 
              ),
              alignment: Alignment.center,
              child: Text(
                filter,
                style: TextStyle(
                  color: isSelected ? Colors.white : context.colorTextGrey,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDoctorList() {
    if (_doctors.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded, 
              size: 64, 
              // PRO FIX: Dimmer icon in dark mode
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.grey[300],
            ),
            SizedBox(height: 16),
            Text(
              "No doctors found",
              style: TextStyle(
                color: context.colorTextLight,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
      itemCount: _doctors.length,
      separatorBuilder: (_, __) => SizedBox(height: 16),
      itemBuilder: (context, index) {
        final doctor = _doctors[index];
        final docId = doctor['id'] as int;
        final specialtyName =
            doctor['specialties'] != null
                ? doctor['specialties']['name']
                : 'Specialist';
        final isFavorite = _favNotifier.isFavorite(docId);

        return DoctorListCard(
          id: docId,
          name: doctor['full_name'] ?? 'Unknown',
          specialty: specialtyName,
          rating: doctor['rating']?.toString() ?? '0.0',
          // Use 'views_count' if available, otherwise 0
          views: (doctor['views_count'] ?? 0).toString(),
          imageUrl: doctor['profile_picture_url'],
          isFavorite: isFavorite,
          onFavoriteTap: () => _favNotifier.toggle(docId),
          onCardTap: () => _navigateToDoctorDetails(docId),
        );
      },
    );
  }

  Widget _buildHospitalGrid() {
    if (_hospitals.isEmpty) {
      return Center(
        child: Text(
          "No hospitals found.",
          style: AppTextStyles.body(
            context,
          ).copyWith(color: context.colorTextGrey),
        ),
      );
    }
    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: _hospitals.length,
      itemBuilder: (context, index) {
        final hospital = _hospitals[index];
        return _buildFacilityCard(hospital);
      },
    );
  }

  Widget _buildClinicGrid() {
    if (_clinics.isEmpty) {
      return Center(
        child: Text(
          "No clinics found.",
          style: AppTextStyles.body(
            context,
          ).copyWith(color: context.colorTextGrey),
        ),
      );
    }
    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: _clinics.length,
      itemBuilder: (context, index) {
        final clinic = _clinics[index];
        return _buildFacilityCard(clinic);
      },
    );
  }

  Widget _buildFacilityCard(Map<String, dynamic> facility) {
    final id = facility['id'];
    final name = facility['name'] ?? 'Unknown';
    final imageUrl = facility['image_url'];

    return InkWell(
      onTap: () {
        if (id != null) {
          context.push(
            AppRoutes.clinicDoctorsById('$id'),
            extra: ClinicRouteArgs(name: name),
          );
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        // PRO FIX: Perfectly adapts the facility grids to Dark Mode surface
        decoration: AppStyles.surfaceCard(context, borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryGreen.withValues(alpha: 0.1),
                image:
                    imageUrl != null
                        ? DecorationImage(
                          image: NetworkImage(imageUrl),
                          fit: BoxFit.cover,
                        )
                        : null,
              ),
              child:
                  imageUrl == null
                      ? Icon(
                        Icons.local_hospital,
                        color: AppColors.primaryGreen,
                        size: 40,
                      )
                      : null,
            ),
            SizedBox(height: 12),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                name,
                style: AppTextStyles.bodyBold(context).copyWith(fontSize: 14),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
