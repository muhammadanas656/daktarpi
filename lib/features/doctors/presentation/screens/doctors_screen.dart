import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../presentation/widgets/custom_search_bar.dart';
import '../../../../presentation/widgets/doctor_list_card.dart';

import '../favorites_notifier.dart';
import '../doctors_notifier.dart'; // PRO FIX: Imported the new central Notifier!
import '../models/doctors_route_args.dart';
import '../../../profile/presentation/profile_notifier.dart';
import '../../../notifications/presentation/notification_notifier.dart';
import '../../../../core/widgets/app_loader.dart';

class DoctorsScreen extends StatefulWidget {
  final bool isBackgroundLayer; // PRO FIX: Flag for 3D Drawer background mode

  const DoctorsScreen({super.key, this.isBackgroundLayer = false});

  @override
  State<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends State<DoctorsScreen> {
  final _favNotifier = FavoritesNotifier.instance;
  final _profileNotifier = ProfileNotifier.instance;
  final _docsNotifier = DoctorsNotifier.instance;

  final TextEditingController _searchController = TextEditingController();
  
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
    // PRO FIX: We tell the notifier to load. If it already has data in RAM, 
    // it skips the network call instantly! The Drawer background can just piggyback.
    _docsNotifier.fetchDoctors();

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
        _docsNotifier.fetchDoctors(
          query: _searchController.text.trim(),
          filter: _selectedFilter,
        );
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    FocusScope.of(context).unfocus();
  }

  Future<void> _fetchDoctors() async {
    await _docsNotifier.fetchDoctors(
      query: _searchController.text.trim(),
      filter: _selectedFilter,
      forceRefresh: true, // Pull-to-refresh forces a true global network fetch
    );
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
                child: ListenableBuilder(
                  listenable: _docsNotifier,
                  builder: (context, _) {
                    if (_docsNotifier.isLoading && _docsNotifier.doctors.isEmpty) {
                      return const Center(
                        child: AppLoader(
                          color: AppColors.primaryGreen,
                        ),
                      );
                    }
                    
                    return Stack(
                      children: [
                        RefreshIndicator(
                          onRefresh: _fetchDoctors,
                          color: AppColors.primaryGreen,
                          child: _selectedFilter == 'Hospital'
                              ? _buildHospitalGrid()
                              : _selectedFilter == 'Clinic'
                                  ? _buildClinicGrid()
                                  : _buildDoctorList(),
                        ),
                        if (_docsNotifier.isLoading && _docsNotifier.doctors.isNotEmpty)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: LinearProgressIndicator(
                              color: AppColors.primaryGreen,
                              backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.1),
                              minHeight: 3,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
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
        readOnly: widget.isBackgroundLayer, // PRO FIX: Read-only prevents TextField rendering glitches on overlaid repainted canvases
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
    });
    _docsNotifier.fetchDoctors(
      query: _searchController.text.trim(),
      filter: filter,
    );
  }

  Widget _buildDoctorList() {
    final doctors = _docsNotifier.doctors; // Read mapped data from the Singleton Vault
    if (doctors.isEmpty) {
      return Center(
        child: Text(
          "No doctors found",
          style: TextStyle(color: context.colorTextLight),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      itemCount: doctors.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final doctor = doctors[index];
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
  Widget _buildHospitalGrid() => _buildFacilityGrid(_docsNotifier.hospitals);
  Widget _buildClinicGrid() => _buildFacilityGrid(_docsNotifier.clinics);

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


}
