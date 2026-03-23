import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../presentation/widgets/custom_search_bar.dart';
import '../../../../presentation/widgets/doctor_list_card.dart';
import '../../../../presentation/widgets/app_network_image.dart';

import '../favorites_notifier.dart';
import '../doctors_notifier.dart'; 
import '../models/doctors_route_args.dart';
import '../../../profile/presentation/profile_notifier.dart';
import '../../../notifications/presentation/notification_notifier.dart';
import '../../../../core/widgets/app_loader.dart';

class DoctorsScreen extends StatefulWidget {
  final bool isBackgroundLayer; 

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
      forceRefresh: true, 
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
                          ), 
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
        readOnly: widget.isBackgroundLayer, 
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 54, 
      margin: const EdgeInsets.only(top: 16, bottom: 12),
      child: ListView.separated(
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
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? AppColors.primaryGreen
                        : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border:
                    isSelected
                        ? null
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
                            blurRadius: 14, 
                            offset: const Offset(0, 6), 
                          ),
                        ]
                        : [], 
              ),
              child: Text(
                filter,
                style: TextStyle(
                  color: isSelected ? Colors.white : context.colorTextLight,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                  letterSpacing: 0.3, 
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
    final doctors = _docsNotifier.doctors; 
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

  Widget _buildHospitalGrid() => _buildFacilityGrid(_docsNotifier.hospitals, isHospital: true);
  Widget _buildClinicGrid() => _buildFacilityGrid(_docsNotifier.clinics, isHospital: false);

  Widget _buildFacilityGrid(List<Map<String, dynamic>> items, {required bool isHospital}) {
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.72, 
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildFacilityCard(items[index], isHospital),
    );
  }

  Widget _buildFacilityCard(Map<String, dynamic> facility, bool isHospital) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasImage = facility['image_url'] != null && facility['image_url'].toString().isNotEmpty;

    // --- PRO FIX: Safe Fallback Icon ---
    // If there is no image OR if the image URL is a broken 404 link, it safely drops back to this!
    final fallbackIcon = Icon(
      isHospital ? Icons.local_hospital_rounded : Icons.medical_services_rounded,
      size: 40,
      color: AppColors.primaryGreen.withValues(alpha: 0.4),
    );

    return InkWell(
      onTap: () => context.push(
        AppRoutes.clinicDoctorsById('${facility['id']}'),
        extra: ClinicRouteArgs(
          name: facility['name'],
          logoUrl: facility['logo_url']?.toString(),
        ),
      ),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: AppStyles.surfaceCard(
          context,
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias, 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Image Cover
            Expanded(
              flex: 5,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBorder : const Color(0xFFE8F1F2),
                ),
                child: hasImage
                    ? AppNetworkImage(
                        imageUrl: facility['image_url'],
                        fit: BoxFit.cover,
                        cacheKey: 'facility_${facility['id']}',
                      )
                    : fallbackIcon,
              ),
            ),
            // 2. Info Section
            Expanded(
              flex: 5, 
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      facility['name'] ?? 'Unknown',
                      maxLines: 2, 
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyBold(context).copyWith(
                        fontSize: 13, 
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4), 
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.location_on_rounded, 
                          size: 14, 
                          color: context.colorTextLight,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            facility['address'] ?? 'Tap to view doctors',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.3,
                              color: context.colorTextLight,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}