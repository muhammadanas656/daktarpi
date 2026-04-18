import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/widgets/background_sync_indicator.dart';
import '../../../../presentation/widgets/custom_search_bar.dart';
import '../../../../presentation/widgets/doctor_list_card.dart';
import '../../../profile/presentation/profile_notifier.dart';
import '../doctors_notifier.dart';
import '../favorites_notifier.dart';
import '../widgets/smart_filter_bar.dart';

class FeaturedDoctorsScreen extends StatefulWidget {
  const FeaturedDoctorsScreen({super.key});

  @override
  State<FeaturedDoctorsScreen> createState() => _FeaturedDoctorsScreenState();
}

class _FeaturedDoctorsScreenState extends State<FeaturedDoctorsScreen> {
  final _searchController = TextEditingController();
  final _favNotifier = FavoritesNotifier.instance;
  final _profileNotifier = ProfileNotifier.instance;
  final _docsNotifier = DoctorsNotifier.instance; // PRO FIX: Singleton Vault
  Timer? _debounce;

  // Data State
  bool _isLoading = true; // Only block UI if the vault is completely empty
  bool _showClearIcon = false;
  String _selectedFilter = 'All';
  double? _activeRadiusKm;

  @override
  void initState() {
    super.initState();
    _favNotifier.addListener(_onStateChanged);
    _profileNotifier.addListener(_onStateChanged);
    _fetchData();

    _searchController.addListener(() {
      setState(() {
        _showClearIcon = _searchController.text.isNotEmpty;
      });
      _onSearchChanged();
    });
  }

  @override
  void dispose() {
    _favNotifier.removeListener(_onStateChanged);
    _profileNotifier.removeListener(_onStateChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchData(query: _searchController.text);
    });
  }

  Widget _buildFilterChips() {
    return SmartFilterBar(
      filters: FilterConfig.standard,
      initialFilter: _selectedFilter,
      onFilterChanged: (filter, radius) {
        setState(() {
          _selectedFilter = filter;
          _activeRadiusKm = radius;
        });
        _fetchData(
          query: _searchController.text,
          forceRefresh: true,
        );
      },
    );
  }

  void _clearSearch() {
    _searchController.clear();
    FocusScope.of(context).unfocus();
  }

  Future<void> _fetchData({String? query, bool forceRefresh = false}) async {
    if (mounted) setState(() => _isLoading = true);

    // PRO FIX: Ensure favorites are loaded into RAM before showing the list
    if (!_favNotifier.isLoaded) {
      await _favNotifier.loadFavorites();
    }
    
    try {
      await _docsNotifier.fetchFeaturedDoctors(
        query: query ?? '',
        filter: _selectedFilter,
        maxRadiusKm: _activeRadiusKm,
        forceRefresh: forceRefresh,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateToDoctorDetails(int doctorId, Map<String, dynamic> doctorData) async {
    await context.push(AppRoutes.doctorDetailsById('$doctorId'), extra: doctorData);
    if (mounted) {
      _fetchData(query: _searchController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: AppStyles.pageGradient(context)),
        child: ListenableBuilder(
          listenable: _docsNotifier,
          builder: (context, _) {
            final doctors = _docsNotifier.exploreFeaturedDoctors;

            return Stack(
              children: [
                RefreshIndicator(
                  onRefresh: () => _fetchData(forceRefresh: true),
                  color: AppColors.primaryGreen,
                  edgeOffset:
                      MediaQuery.paddingOf(context).top +
                      kToolbarHeight +
                      138.0,
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      SliverAppBar(
                        pinned: true,
                        // THE FIX: 56px (Toolbar) + 112px (Search/Chips) = 168.0 Total Height
                        expandedHeight: kToolbarHeight + 12,
                        collapsedHeight: kToolbarHeight+12,
                        toolbarHeight: kToolbarHeight, // Native 56px locks the button/title alignment
                        elevation: 0,
                        backgroundColor: Colors.transparent,
                        surfaceTintColor: Colors.transparent,
                        leadingWidth: 72,
                        leading: Container(
                          padding: const EdgeInsets.only(left: 24),
                          alignment: Alignment.centerLeft,
                          // UnconstrainedBox prevents the back button from stretching!
                          child: UnconstrainedBox(
                            child: Material(
                              color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  context.pop();
                                },
                                child: Container(
                                  width: 40, height: 40, alignment: Alignment.center,
                                  child: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : const Color(0xFF1D1D1F), size: 18),
                                ),
                              ),
                            ),
                          ),
                        ),
                        centerTitle: true,
                        title: Text(
                          // NOTE: Use `title` for Popular screen, and `'Featured Doctors'` for Featured screen!
                          'Featured Doctors', 
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF1D1D1F),
                            fontSize: 18,
                            fontWeight: FontWeight.w800, // Premium tightened typography
                            letterSpacing: -0.3,
                          ),
                        ),
                        // 1. Natively attach the Search & Chips to the glass pane!
                        bottom: PreferredSize(
                          preferredSize: const Size.fromHeight(112.0),
                          child: Container(
                            padding: const EdgeInsets.only(top: 12, bottom: 4),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  child: CustomSearchBar(
                                    controller: _searchController,
                                    hintText: "Search",
                                    showClearIcon: _showClearIcon,
                                    onClear: _clearSearch,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildFilterChips(),
                              ],
                            ),
                          ),
                        ),
                        // 2. The Unified Glass Pane (Covers the toolbar AND the bottom widget)
                        flexibleSpace: ClipRRect(
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 24.0, sigmaY: 24.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.70),
                                border: Border(
                                  bottom: BorderSide(
                                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                                    width: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_isLoading && doctors.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        )
                      else if (doctors.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Text("No featured doctors found"),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((context, index) {
                              final doctor = doctors[index];
                              final docId = doctor['id'] as int;
                              final specialtyName =
                                  doctor['specialties'] != null
                                      ? doctor['specialties']['name']
                                      : 'Specialist';
                              final isFavorite = _favNotifier.isFavorite(docId);

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: DoctorListCard(
                                  id: docId,
                                  name: doctor['full_name'] ?? 'Unknown',
                                  specialty: " $specialtyName",
                                  rating: doctor['rating']?.toString() ?? '0.0',
                                  views: doctor['views_count']?.toString() ?? '0',
                                  imageUrl: doctor['profile_picture_url'],
                                  isFavorite: isFavorite,
                                  heroTagPrefix: 'featured-',
                                  onFavoriteTap: () {
                                    HapticFeedback.selectionClick();
                                    _favNotifier.toggle(doctor);
                                  },
                                  onCardTap: () {
                                    HapticFeedback.lightImpact();
                                    _navigateToDoctorDetails(docId, doctor);
                                  },
                                ),
                              );
                            }, childCount: doctors.length),
                          ),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  top: MediaQuery.paddingOf(context).top,
                  left: 0,
                  right: 0,
                  child: BackgroundSyncIndicator(isSyncing: _isLoading && doctors.isNotEmpty),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ListGlassCapsuleDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _ListGlassCapsuleDelegate({required this.child});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: maxExtent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. The Blur Layer (Bleeding up by 2px to seal the seam)
          Positioned(
            top: -2.0,
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 24.0, sigmaY: 24.0),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          // 2. The Color Layer (Bleeding up by 2px to seal the seam)
          Positioned(
            top: -2.0,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.85),
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.05),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
          // 3. The Content Layer (Stays exactly in place)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(),
              clipBehavior: Clip.hardEdge,
              child: OverflowBox(
                maxHeight: double.infinity,
                alignment: Alignment.topCenter,
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 138.0;

  @override
  double get minExtent => 138.0;

  @override
  bool shouldRebuild(covariant _ListGlassCapsuleDelegate oldDelegate) => true;
}
