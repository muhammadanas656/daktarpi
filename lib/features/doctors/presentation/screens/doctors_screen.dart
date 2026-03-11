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
import '../../../profile/presentation/profile_notifier.dart';
import '../../../notifications/presentation/notification_notifier.dart';

class DoctorsScreen extends StatefulWidget {
  final bool isBackgroundLayer; // PRO FIX: Flag for 3D Drawer background mode

  const DoctorsScreen({super.key, this.isBackgroundLayer = false});

  @override
  State<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends State<DoctorsScreen> {
  final _doctorRepo = DoctorRepository();
  final _favNotifier = FavoritesNotifier.instance;
  final _profileNotifier = ProfileNotifier.instance;

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
    // PRO FIX: Instantly ready if background layer to prevent "wavy" shimmers
    if (!widget.isBackgroundLayer) {
      _fetchDoctors();
    } else {
      _isLoading = false;
    }
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

  void _onFavoritesChanged() => mounted ? setState(() {}) : null;
  void _onProfileChanged() => mounted ? setState(() {}) : null;

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted && !widget.isBackgroundLayer) {
        setState(() => _isLoading = true);
        _fetchDoctors();
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    FocusScope.of(context).unfocus();
  }

  Future<void> _fetchDoctors() async {
    final query = _searchController.text.trim();
    try {
      double? userLat;
      double? userLng;

      if (_selectedFilter == 'Nearest') {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
        );
        userLat = position.latitude;
        userLng = position.longitude;
      }

      final userLocation = _profileNotifier.profile?.location;
      final countryIso = _profileNotifier.profile?.countryIso;

      final doctors = await _doctorRepo.fetchAllDoctors(
        query: query,
        userLat: userLat,
        userLng: userLng,
        userLocation: userLocation,
        countryIso: countryIso,
      );

      final hospitals = await _doctorRepo.fetchHospitals(query: query);
      final clinics = await _doctorRepo.fetchClinicsList(query: query);

      // PRO FIX: The Match Guard
      // This ensures that if the user cleared the search bar while the network
      // was downloading, the app throws away the old search results instead of showing them.
      if (mounted && _searchController.text.trim() == query) {
        setState(() {
          _doctors = doctors;
          _hospitals = hospitals;
          _clinics = clinics;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && _searchController.text.trim() == query) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // PRO FIX: If this is the 3D drawer background, render the text-free skeleton
    // This entirely prevents the TextField overlay from glitching into "random characters"
    if (widget.isBackgroundLayer) {
      return _buildBackgroundSkeleton(context);
    }

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
                    widget.isBackgroundLayer
                        ? _buildDummyBackgroundList() // PRO FIX: Clean UI structure for the 3D drawer
                        : _isLoading
                        ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryGreen,
                          ),
                        )
                        : RefreshIndicator(
                          onRefresh: _fetchDoctors,
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

  Widget _buildDummyBackgroundList() {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder:
          (context, index) => Container(
            height: 110,
            decoration: AppStyles.surfaceCard(
              context,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
    );
  }

  // --- PRO FIX: Signature Surface Header for Doctors ---
  // --- PRO FIX: Premium Editorial Glass Header ---
  // --- PRO FIX: Clean Typographic Header ---
  // --- PRO FIX: Clean Typographic Header with Reactive Inbox Badge ---
  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "Find a Doctor",
            style: AppTextStyles.h1(
              context,
            ).copyWith(fontSize: 26, letterSpacing: -0.5),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? AppColors.darkBorder : context.colorBorder,
              ),
              boxShadow: AppStyles.cardShadow(context),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.notifications_none_rounded,
                    color: context.colorTextDark,
                    size: 22,
                  ),
                  onPressed: () => context.push(AppRoutes.notifications),
                ),

                // Reactive Unread Badge!
                AnimatedBuilder(
                  animation: NotificationNotifier.instance,
                  builder: (context, child) {
                    if (NotificationNotifier.instance.unreadCount == 0) {
                      return const SizedBox.shrink();
                    }
                    return Positioned(
                      right: 10,
                      top: 10,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.dangerRed,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.surface,
                            width: 1.5,
                          ), // Cutout effect
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
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
      height: 54, // PRO FIX: Perfect professional height (not overexpanded)
      margin: const EdgeInsets.only(top: 16, bottom: 12),
      child: ListView.separated(
        // PRO FIX: The magic bullet. This prevents shadows from EVER being cut off!
        clipBehavior: Clip.none,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilter == filter;

          return GestureDetector(
            onTap: () => _onFilterTap(filter),
            child: AnimatedContainer(
              // PRO FIX: Smooth animation when switching tabs
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? AppColors.primaryGreen
                        : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(
                  24,
                ), // Perfectly round pills
                border:
                    isSelected
                        ? null
                        // Clean, professional outline for unselected state
                        : Border.all(
                          color: context.colorBorder.withValues(alpha: 0.6),
                        ),
                boxShadow:
                    isSelected
                        ? [
                          BoxShadow(
                            color: AppColors.primaryGreen.withValues(
                              alpha: 0.35,
                            ),
                            blurRadius: 14, // Lush, wide glow
                            offset: const Offset(
                              0,
                              6,
                            ), // Dropped slightly lower
                          ),
                        ]
                        : [], // No shadow on unselected for a cleaner hierarchy
              ),
              child: Text(
                filter,
                style: TextStyle(
                  color: isSelected ? Colors.white : context.colorTextLight,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                  letterSpacing: 0.3, // Adds a touch of elegance to the text
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _onFilterTap(String filter) {
    if (widget.isBackgroundLayer) return;
    setState(() {
      _selectedFilter = filter;
      _isLoading = true;
    });
    _fetchDoctors();
  }

  Widget _buildDoctorList() {
    if (_doctors.isEmpty) {
      return Center(
        child: Text(
          "No doctors found",
          style: TextStyle(color: context.colorTextLight),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      itemCount: _doctors.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final doctor = _doctors[index];
        return DoctorListCard(
          id: doctor['id'],
          name: doctor['full_name'] ?? 'Unknown',
          specialty: doctor['specialties']?['name'] ?? 'Specialist',
          rating: doctor['rating']?.toString() ?? '0.0',
          views: (doctor['views_count'] ?? 0).toString(),
          imageUrl: doctor['profile_picture_url'],
          isFavorite: _favNotifier.isFavorite(doctor['id']),
          onFavoriteTap: () => _favNotifier.toggle(doctor),
          onCardTap:
              () => context.push(
                AppRoutes.doctorDetailsById('${doctor['id']}'),
                extra: doctor,
              ),
        );
      },
    );
  }

  // Facility Grid Builders
  Widget _buildHospitalGrid() => _buildFacilityGrid(_hospitals);
  Widget _buildClinicGrid() => _buildFacilityGrid(_clinics);

  Widget _buildFacilityGrid(List<Map<String, dynamic>> items) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildFacilityCard(items[index]),
    );
  }

  Widget _buildFacilityCard(Map<String, dynamic> facility) {
    return InkWell(
      onTap:
          () => context.push(
            AppRoutes.clinicDoctorsById('${facility['id']}'),
            extra: ClinicRouteArgs(name: facility['name']),
          ),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: AppStyles.surfaceCard(
          context,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage:
                  facility['image_url'] != null
                      ? NetworkImage(facility['image_url'])
                      : null,
              child:
                  facility['image_url'] == null
                      ? const Icon(
                        Icons.local_hospital,
                        color: AppColors.primaryGreen,
                      )
                      : null,
            ),
            const SizedBox(height: 12),
            Text(
              facility['name'] ?? 'Unknown',
              style: AppTextStyles.bodyBold(context),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // --- PRO FIX: The Glitch-Free Background Skeleton ---
  Widget _buildBackgroundSkeleton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final skeletonColor =
        isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.04);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: AppStyles.pageGradient(context)),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Dummy Clean Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 160,
                      height: 30,
                      decoration: BoxDecoration(
                        color: skeletonColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: skeletonColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
              // 2. Dummy Search Bar (Eliminates the "random white text" bug!)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                height: 54,
                decoration: BoxDecoration(
                  color: skeletonColor,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),

              // 3. Dummy Filter Chips
              Container(
                height: 40,
                margin: const EdgeInsets.only(top: 16, bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: List.generate(
                    4,
                    (index) => Container(
                      width: index == 0 ? 60 : 90,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: skeletonColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ),

              // 4. Dummy Cards
              Expanded(
                child: ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  itemCount: 4,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder:
                      (context, index) => Container(
                        height: 110,
                        decoration: AppStyles.surfaceCard(
                          context,
                          borderRadius: BorderRadius.circular(20),
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
