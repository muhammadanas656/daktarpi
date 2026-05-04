import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../presentation/widgets/animations/premium_list_animator.dart';
import '../../../../presentation/widgets/custom_search_bar.dart';
import '../../../../presentation/widgets/doctor_list_card.dart';
import '../../../../presentation/widgets/doctor_list_card_skeleton.dart';
import '../../../profile/presentation/profile_notifier.dart';
import '../doctors_notifier.dart';
import '../favorites_notifier.dart';
import '../widgets/smart_filter_bar.dart';

class PopularDoctorsScreen extends StatefulWidget {
  const PopularDoctorsScreen({super.key});

  @override
  State<PopularDoctorsScreen> createState() => _PopularDoctorsScreenState();
}

class _PopularDoctorsScreenState extends State<PopularDoctorsScreen> {
  final _searchController = TextEditingController();
  final _favNotifier = FavoritesNotifier.instance;
  final _profileNotifier = ProfileNotifier.instance;
  final _docsNotifier = DoctorsNotifier.instance;
  Timer? _debounce;

  bool _isLoading = true;
  bool _hasEverLoaded = false;
  bool _showClearIcon = false;
  String _selectedFilter = 'All';
  double? _activeRadiusKm;
  double _popularHighlightRangeKm = 25.0;
  double _popularThreshold = 3.0;
  double? _userLat;
  double? _userLng;

  @override
  void initState() {
    super.initState();
    _favNotifier.addListener(_onStateChanged);
    _profileNotifier.addListener(_onStateChanged);

    _searchController.addListener(() {
      setState(() {
        _showClearIcon = _searchController.text.isNotEmpty;
      });
      _onSearchChanged();
    });

    Future.delayed(const Duration(milliseconds: 300), () async {
      if (!mounted) return;

      final rangeThreshold = await _docsNotifier.fetchPopularHighlightRange();
      final thresholdLimit = await _docsNotifier.fetchPopularThreshold();
      final pos = await _docsNotifier.getUserPosition();

      if (mounted) {
        setState(() {
          _popularHighlightRangeKm = rangeThreshold;
          _popularThreshold = thresholdLimit;
          if (pos != null) {
            _userLat = pos.latitude;
            _userLng = pos.longitude;
          }
        });
      }

      if (mounted) _fetchData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _favNotifier.removeListener(_onStateChanged);
    _profileNotifier.removeListener(_onStateChanged);
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

  Widget _buildTopRatedBadge(
    bool isDark, {
    required String tagText,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(22),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: AppColors.primaryGreen,
            size: 9,
          ),
          const SizedBox(width: 3),
          Text(
            tagText.toUpperCase(),
            style: const TextStyle(
              color: AppColors.primaryGreen,
              fontSize: 8.0,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchData({String? query, bool forceRefresh = false}) async {
    if (mounted) setState(() => _isLoading = true);

    try {
      if (!_favNotifier.isLoaded) {
        await _favNotifier.loadFavorites();
      }

      await _docsNotifier.fetchPopularDoctors(
        query: query ?? '',
        filter: _selectedFilter,
        maxRadiusKm: _activeRadiusKm,
        forceRefresh: forceRefresh,
        limit: await _docsNotifier.fetchExplorePopularLimit(),
      );

    } catch (e) {
      debugPrint('Error fetching data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasEverLoaded = true;
        });
      }
    }
  }

  Future<void> _navigateToDoctorDetails(int doctorId, Map<String, dynamic> doctorData) async {
    await context.push(AppRoutes.doctorDetailsById('$doctorId'), extra: doctorData);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title =
        (_activeRadiusKm ?? 500.0) <= _popularHighlightRangeKm
            ? 'Popular Doctors'
            : 'Recommended Specialists';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: AppStyles.pageGradient(context)),
        child: ListenableBuilder(
          listenable: _docsNotifier,
          builder: (context, _) {
            final rawList = _docsNotifier.explorePopularDoctors;

            final finalDisplayList = _docsNotifier.getStrictPopularList(
              rawDoctors: rawList,
              activeRadius: _activeRadiusKm,
              highlightRange: _popularHighlightRangeKm,
              threshold: _popularThreshold,
            );

            final sortedDisplayList = _docsNotifier.sortDoctorsByHighlight(
              finalDisplayList,
              _userLat,
              _userLng,
              _popularHighlightRangeKm,
            );

            return Stack(
              children: [
                RefreshIndicator(
                  onRefresh: () => _fetchData(forceRefresh: true),
                  color: AppColors.primaryGreen,
                  edgeOffset:
                      MediaQuery.paddingOf(context).top +
                      kToolbarHeight +
                      125.0,
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
                          title, 
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
                        // THE FIX: Wrapped in a Stack to permanently fuse the loader
                        flexibleSpace: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
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
                            if (_isLoading && sortedDisplayList.isNotEmpty)
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
                      ),

                      if (_isLoading && !_hasEverLoaded && sortedDisplayList.isEmpty)
                        const DoctorListSkeletonSliver()
                      else if (sortedDisplayList.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: Text("No popular doctors found")),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                          sliver: SliverList(
                            // THE FIX: The Intent Hash!
                            // It only remounts the list if the user changes the filter or search text.
                            // GPS updates will now just silently slide the cards around!
                            key: ValueKey(
                              'popular_${_selectedFilter}_${_searchController.text}',
                            ),
                            delegate: SliverChildBuilderDelegate((context, index) {
                              final doctor = sortedDisplayList[index];
                              final docId = doctor['id'] as int;
                              final specialtyName =
                                  doctor['specialties'] != null
                                      ? doctor['specialties']['name']
                                      : 'Specialist';
                              final views = doctor['views_count']?.toString() ?? '0';
                              final isFavorite = _favNotifier.isFavorite(docId);
                              final ratingVal =
                                  double.tryParse(
                                    doctor['rating']?.toString() ?? '0',
                                  ) ??
                                  0.0;
                              final isPopularFlag = doctor['is_popular'] == true;

                              final distance =
                                  _docsNotifier.calculateDoctorDistance(
                                    doctor,
                                    _userLat,
                                    _userLng,
                                  );
                              final isWithinHighlightRange =
                                  distance <= _popularHighlightRangeKm;

                              final shouldHighlight =
                                  isWithinHighlightRange &&
                                  (ratingVal > 0 || isPopularFlag);

                              var smartTag = "NEARBY";
                              var smartIcon = Icons.location_on_rounded;

                              if (isPopularFlag) {
                                smartTag = "TRENDING";
                                smartIcon = Icons.local_fire_department_rounded;
                              } else if (ratingVal >= 4.8) {
                                smartTag = "TOP RATED";
                                smartIcon = Icons.star_rounded;
                              }

                              return PremiumListAnimator(
                                index: index,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: DoctorListCard(
                                    id: docId,
                                    name: doctor['full_name'] ?? 'Unknown',
                                    specialty: " $specialtyName",
                                    rating: doctor['rating']?.toString() ?? '0.0',
                                    views: views,
                                    imageUrl: doctor['profile_picture_url'],
                                    isFavorite: isFavorite,
                                    heroTagPrefix: 'popular-$docId-$index-',
                                    onFavoriteTap: () {
                                      _favNotifier.toggle(doctor);
                                    },
                                    onCardTap: () {
                                      _navigateToDoctorDetails(docId, doctor);
                                    },
                                    customBorderColor:
                                        shouldHighlight
                                            ? AppColors.primaryGreen
                                            : null,
                                    customBadgeOverlay:
                                        shouldHighlight
                                            ? _buildTopRatedBadge(
                                              isDark,
                                              tagText: smartTag,
                                              icon: smartIcon,
                                            )
                                            : null,
                                  ),
                                ),
                              );
                            }, childCount: sortedDisplayList.length),
                          ),
                        ),
                    ],
                  ),
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
