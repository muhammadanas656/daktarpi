import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../widgets/smart_filter_bar.dart';
import '../models/doctors_route_args.dart';
import '../../../../core/widgets/app_loader.dart';

class DoctorsScreen extends StatefulWidget {
  final bool isBackgroundLayer;

  const DoctorsScreen({super.key, this.isBackgroundLayer = false});

  @override
  State<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends State<DoctorsScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final _favNotifier = FavoritesNotifier.instance;
  final _docsNotifier = DoctorsNotifier.instance;
  final TextEditingController _searchController = TextEditingController();

  String _selectedFilter = 'All';
  double? _activeRadiusKm;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (!widget.isBackgroundLayer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_docsNotifier.fetchDoctors());
      });
    }
    _searchController.addListener(_onSearchChanged);
    _favNotifier.addListener(_onFavoritesChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _favNotifier.removeListener(_onFavoritesChanged);
    super.dispose();
  }

  void _onFavoritesChanged() => mounted ? setState(() {}) : null;

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted && !widget.isBackgroundLayer) {
        _docsNotifier.fetchDoctors(
          query: _searchController.text.trim(),
          filter: _selectedFilter,
          maxRadiusKm: _activeRadiusKm,
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
    super.build(context);
    return Scaffold(
      // THE FIX: Pure, solid background. No more cyan gradients!
backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildSearchBar(),
            _buildFilterChips(),
            Expanded(
              child: ListenableBuilder(
                listenable: _docsNotifier,
                builder: (context, _) {
                  if (_docsNotifier.isLoading &&
                      _docsNotifier.doctors.isEmpty) {
                    return const Center(
                      child: AppLoader(color: AppColors.primaryGreen),
                    );
                  }

                  return Stack(
                    children: [
                      RefreshIndicator(
                        onRefresh: _fetchDoctors,
                        color: AppColors.primaryGreen,
                        child:
                            _selectedFilter == 'Hospital'
                                ? _buildHospitalGrid()
                                : _selectedFilter == 'Clinic'
                                ? _buildClinicGrid()
                                : _buildDoctorList(),
                      ),
                      if (_docsNotifier.isLoading &&
                          _docsNotifier.doctors.isNotEmpty)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: LinearProgressIndicator(
                            color: AppColors.primaryGreen,
                            backgroundColor: AppColors.primaryGreen
                                .withOpacity(0.1),
                            minHeight: 2,
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
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: CustomSearchBar(
        controller: _searchController,
        hintText: "Search doctor, specialty...",
        showClearIcon: _searchController.text.isNotEmpty,
        onClear: _clearSearch,
        readOnly: widget.isBackgroundLayer,
      ),
    );
  }

  // THE FIX: Intelligent Boundary Filter integration
  Widget _buildFilterChips() {
    return SmartFilterBar(
      filters: const ['All', 'Nearest', 'Hospital', 'Clinic', 'Top Rated'],
      initialFilter: _selectedFilter,
      isBackgroundLayer: widget.isBackgroundLayer,
      onFilterChanged: (filter, radius) {
        if (widget.isBackgroundLayer) return;
        setState(() {
          _selectedFilter = filter;
          _activeRadiusKm = radius;
        });
        _docsNotifier.fetchDoctors(
          query: _searchController.text.trim(),
          filter: filter,
          maxRadiusKm: radius,
        );
      },
    );
  }

  Widget _buildDoctorList() {
    final doctors = _docsNotifier.doctors;
    if (doctors.isEmpty) {
      return Center(
        child: Text(
          "No doctors found",
          style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
        ),
      );
    }

    final dynamicBottomPadding = MediaQuery.paddingOf(context).bottom + 20;

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(24, 4, 24, dynamicBottomPadding),
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

  Widget _buildHospitalGrid() =>
      _buildFacilityGrid(_docsNotifier.hospitals, isHospital: true);
  Widget _buildClinicGrid() =>
      _buildFacilityGrid(_docsNotifier.clinics, isHospital: false);

  Widget _buildFacilityGrid(
    List<Map<String, dynamic>> items, {
    required bool isHospital,
  }) {
    final dynamicBottomPadding = MediaQuery.paddingOf(context).bottom + 20;

    return GridView.builder(
      clipBehavior: Clip.none, // Allows the grid card shadows to render properly
      padding: EdgeInsets.fromLTRB(24, 4, 24, dynamicBottomPadding),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.80, // Optimized ratio for the new split card
      ),
      itemCount: items.length,
      itemBuilder:
          (context, index) => _buildFacilityCard(items[index], isHospital),
    );
  }

  // --- REVERTED: The Premium Full-Bleed Cinematic Card ---
  Widget _buildFacilityCard(Map<String, dynamic> facility, bool isHospital) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasImage = facility['image_url'] != null && facility['image_url'].toString().isNotEmpty;

    final fallbackIcon = Icon(
      isHospital ? Icons.local_hospital_rounded : Icons.medical_services_rounded,
      size: 40,
      color: Colors.white.withOpacity(0.9),
    );

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact(); // Kept the premium tactile feel
        context.push(
          AppRoutes.clinicDoctorsById('${facility['id']}'),
          extra: ClinicRouteArgs(
            name: facility['name'],
            logoUrl: facility['logo_url']?.toString(),
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : Colors.black.withOpacity(0.05),
            width: 1.0, 
          ),
          boxShadow: isDark ? [] : [
            BoxShadow(
              color: Colors.black.withOpacity(0.04), // Soft shadow for floating effect
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19), // Perfectly nested inside the 20px border
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Full-Bleed Image Background
              if (hasImage)
                AppNetworkImage(
                  imageUrl: facility['image_url'],
                  fit: BoxFit.cover,
                  cacheKey: 'facility_${facility['id']}',
                )
              else
                Container(
                  color: AppColors.primaryGreen.withOpacity(0.85),
                  child: Center(child: fallbackIcon),
                ),

              // 2. The Dark Cinematic Gradient (Restored)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.0), 
                      Colors.black.withOpacity(0.5), 
                      Colors.black.withOpacity(0.9), 
                    ],
                    stops: const [0.0, 0.45, 0.75, 1.0], 
                  ),
                ),
              ),

              // 3. Bold White Typography over Gradient (Restored)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      facility['name'] ?? 'Unknown',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        letterSpacing: -0.2,
                        shadows: [
                          Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)), 
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 13,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            facility['address'] ?? 'Tap to view doctors',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w500,
                              shadows: const [
                                Shadow(color: Colors.black45, blurRadius: 3, offset: Offset(0, 1)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
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
