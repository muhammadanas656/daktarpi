import 'dart:async';
import 'dart:ui'; // REQUIRED FOR BLUR
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../presentation/widgets/animations/premium_list_animator.dart';
import '../../../../presentation/widgets/custom_search_bar.dart';
import '../../../../presentation/widgets/doctor_list_card.dart';
import '../../../../presentation/widgets/doctor_list_card_skeleton.dart';
import '../../../../presentation/widgets/app_network_image.dart';

import '../favorites_notifier.dart';
import '../doctors_notifier.dart';
import '../widgets/smart_filter_bar.dart';
import '../models/doctors_route_args.dart';

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
  bool _hasEverLoaded = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isBackgroundLayer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          _runDoctorsFetch(
            query: '',
            filter: _selectedFilter,
            maxRadiusKm: _activeRadiusKm,
          ),
        );
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
        unawaited(
          _runDoctorsFetch(
            query: _searchController.text.trim(),
            filter: _selectedFilter,
            maxRadiusKm: _activeRadiusKm,
          ),
        );
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    FocusScope.of(context).unfocus();
  }

  Future<void> _runDoctorsFetch({
    required String query,
    required String filter,
    required double? maxRadiusKm,
    bool forceRefresh = false,
  }) async {
    await _docsNotifier.fetchDoctors(
      query: query,
      filter: filter,
      maxRadiusKm: maxRadiusKm,
      forceRefresh: forceRefresh,
    );

    if (mounted && !_hasEverLoaded) {
      setState(() => _hasEverLoaded = true);
    }
  }

  Future<void> _fetchDoctors() async {
    await _runDoctorsFetch(
      query: _searchController.text.trim(),
      filter: _selectedFilter,
      maxRadiusKm: _activeRadiusKm,
      forceRefresh: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final topPadding = MediaQuery.paddingOf(context).top;
    return Scaffold(
      // THE FIX: Extend body so it slides elegantly under the glass header
      extendBodyBehindAppBar: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: ListenableBuilder(
        listenable: _docsNotifier,
        builder: (context, _) {
          bool isEmpty = false;
          if (_selectedFilter == 'Hospital') {
            isEmpty = _docsNotifier.hospitals.isEmpty;
          } else if (_selectedFilter == 'Clinic') {
            isEmpty = _docsNotifier.clinics.isEmpty;
          } else {
            isEmpty = _docsNotifier.doctors.isEmpty;
          }

          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: _fetchDoctors,
                color: AppColors.primaryGreen,
                edgeOffset:
                    topPadding + (142.0 * MediaQuery.textScaleFactorOf(context)),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // 1. THE STICKY HEADER (Search + Filters wrapped in Frosted Glass)
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _DoctorsGlassCapsuleDelegate(
                        paddingTop: topPadding,
                        isSyncing: _docsNotifier.isLoading && !isEmpty,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildSearchBar(),
                            _buildFilterChips(),
                          ],
                        ),
                      ),
                    ),

                    // 2. THE CONTENT (Guaranteed to slide UNDER the header)
                    if ((_docsNotifier.isLoading || !_hasEverLoaded) && isEmpty)
                      DoctorListSkeletonSliver(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          20,
                          24,
                          MediaQuery.paddingOf(context).bottom + 20,
                        ),
                      )
                    else if (isEmpty && _hasEverLoaded)
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 300,
                          child: Center(
                            child: Text(
                              "No facilities found",
                              style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.paddingOf(context).bottom + 20),
                        sliver: _selectedFilter == 'Hospital'
                            ? _buildHospitalGrid()
                            : _selectedFilter == 'Clinic'
                                ? _buildClinicGrid()
                                : _buildDoctorList(),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
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

  Widget _buildFilterChips() {
    return SmartFilterBar(
      filters: FilterConfig.withFacilities,
      initialFilter: _selectedFilter,
      isBackgroundLayer: widget.isBackgroundLayer,
      onFilterChanged: (filter, radius) {
        if (widget.isBackgroundLayer) return;
        setState(() {
          _selectedFilter = filter;
          _activeRadiusKm = radius;
        });
        unawaited(
          _runDoctorsFetch(
            query: _searchController.text.trim(),
            filter: filter,
            maxRadiusKm: radius,
          ),
        );
      },
    );
  }

  // UPGRADED TO SLIVER
  Widget _buildDoctorList() {
    final doctors = _docsNotifier.doctors;
    return SliverList(
      // THE FIX: Includes the filter ('All', 'Nearest', etc.) and the search query!
      key: ValueKey('tab_doctors_${_selectedFilter}_${_searchController.text}'),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final doctor = doctors[index];
          return PremiumListAnimator(
            index: index,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16), // Maintains the exact spacing you had before
              child: DoctorListCard(
                id: doctor['id'],
                name: doctor['full_name'] ?? 'Unknown',
                specialty: doctor['specialties']?['name'] ?? 'Specialist',
                rating: doctor['rating']?.toString() ?? '0.0',
                views: (doctor['views_count'] ?? 0).toString(),
                imageUrl: doctor['profile_picture_url'],
                isFavorite: _favNotifier.isFavorite(doctor['id']),
                onFavoriteTap: () => _favNotifier.toggle(doctor),
                onCardTap: () => context.push(
                  AppRoutes.doctorDetailsById('${doctor['id']}'),
                  extra: doctor,
                ),
              ),
            ),
          );
        },
        childCount: doctors.length,
      ),
    );
  }

  Widget _buildHospitalGrid() => _buildFacilityGrid(_docsNotifier.hospitals, isHospital: true);
  Widget _buildClinicGrid() => _buildFacilityGrid(_docsNotifier.clinics, isHospital: false);

  // UPGRADED TO SLIVER
  Widget _buildFacilityGrid(List<Map<String, dynamic>> items, {required bool isHospital}) {
    return SliverGrid(
      // THE FIX: Includes the facility type ('Hospital' vs 'Clinic')
      key: ValueKey(
        'tab_facilities_${isHospital ? 'hospital' : 'clinic'}_${_searchController.text}',
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.80, 
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) => PremiumListAnimator(
          index: index,
          child: _buildFacilityCard(items[index], isHospital),
        ),
        childCount: items.length,
      ),
    );
  }

  Widget _buildFacilityCard(Map<String, dynamic> facility, bool isHospital) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final String? resolvedImage = (facility['image_url'] != null && facility['image_url'].toString().isNotEmpty)
        ? facility['image_url'].toString()
        : facility['logo_url']?.toString();
    
    final hasImage = resolvedImage != null && resolvedImage.isNotEmpty;

    final fallbackIcon = Icon(
      isHospital ? Icons.local_hospital_rounded : Icons.medical_services_rounded,
      size: 40,
      color: Colors.white.withOpacity(0.9),
    );

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact(); 
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
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19), 
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasImage)
                AppNetworkImage(
                  imageUrl: resolvedImage,
                  fit: BoxFit.cover,
                  cacheKey: 'facility_${facility['id']}',
                )
              else
                Container(
                  color: AppColors.primaryGreen.withOpacity(0.85),
                  child: Center(child: fallbackIcon),
                ),
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

// --- THE NEW DYNAMIC GLASS DELEGATE ---
class _DoctorsGlassCapsuleDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double paddingTop;
  final bool isSyncing;

  _DoctorsGlassCapsuleDelegate({
    required this.child,
    required this.paddingTop,
    this.isSyncing = false,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final isPinned = shrinkOffset > 0 || overlapsContent;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: maxExtent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (isPinned)
            ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                child: Container(color: Colors.transparent),
              ),
            ),
          Container(
            padding: EdgeInsets.only(top: paddingTop),
            decoration: BoxDecoration(
              color:
                  isPinned
                      ? Theme.of(context).scaffoldBackgroundColor.withOpacity(0.85)
                      : Colors.transparent,
              boxShadow:
                  isPinned
                      ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ]
                      : [],
            ),
            child: child,
          ),
          if (isSyncing)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LinearProgressIndicator(
                color: AppColors.primaryGreen,
                minHeight: 2.0,
                backgroundColor: Colors.transparent,
              ),
            ),
        ],
      ),
    );
  }

  double _calculateDynamicHeight(BuildContext context) {
    final textScale = MediaQuery.textScaleFactorOf(context);
    return paddingTop + (142.0 * textScale);
  }

  @override
  double get maxExtent =>
      paddingTop + (142.0 * WidgetsBinding.instance.window.textScaleFactor);

  @override
  double get minExtent =>
      paddingTop + (142.0 * WidgetsBinding.instance.window.textScaleFactor);

  @override
  bool shouldRebuild(covariant _DoctorsGlassCapsuleDelegate oldDelegate) => true;
}
