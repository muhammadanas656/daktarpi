import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/premium_app_loader.dart';
import '../../../doctors/presentation/favorites_notifier.dart';
import '../../../profile/presentation/profile_notifier.dart';
import '../../../doctors/presentation/doctors_notifier.dart';
import '../../../home/data/home_repository.dart';
import '../../../doctors/presentation/models/doctors_route_args.dart';
import '../../../../core/network/network_notifier.dart';

import '../../../../presentation/widgets/home_popular_doctor_card.dart';
import '../../../../presentation/widgets/home_featured_doctor_card.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../widgets/home_header.dart';
import '../widgets/home_banner.dart';
import '../widgets/home_specialties_row.dart';
import '../widgets/home_section_header.dart';
import '../../../../core/widgets/background_sync_indicator.dart';

class HomeScreen extends StatefulWidget {
  final bool isBackgroundLayer;
  
  const HomeScreen({super.key, this.isBackgroundLayer = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _homeRepo = HomeRepository();
  final _favNotifier = FavoritesNotifier.instance;
  final _profileNotifier = ProfileNotifier.instance;
  final _docsNotifier = DoctorsNotifier.instance;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();

  late AnimationController _headerController;
  late AnimationController _contentController;
  List<Map<String, dynamic>> _banners = HomeRepository.currentBanners;
  double _popularHighlightRangeKm = 25.0;
  double _organicClusterRadius = 500.0;
  double? _userLat;
  double? _userLng;

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    if (!widget.isBackgroundLayer) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) _headerController.forward(from: 0.0);
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _refreshIndicatorKey.currentState?.show();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _headerController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    await _fetchAllData(forceRefresh: true);
  }

  Future<void> _fetchAllData({bool forceRefresh = false}) async {
    if (!mounted) return;
    await _docsNotifier.prehydrateHomeFeed();
    
    final tempIso = _profileNotifier.profile?.countryIso ?? 'US';
    _homeRepo.fetchBanners(tempIso, forceRefresh: false).then((b) {
      if (mounted && _banners.isEmpty) setState(() => _banners = b);
    });

    try {
      if (forceRefresh || !_profileNotifier.isLoaded) {
        await Future.wait([
          _profileNotifier.loadProfile(),
          _favNotifier.loadFavorites(),
        ]).timeout(const Duration(seconds: 10));
      }

      final countryIso = _profileNotifier.profile?.countryIso;

      _popularHighlightRangeKm =
          await _docsNotifier.fetchPopularHighlightRange();
      _organicClusterRadius = 500.0;
      _userLat = null;
      _userLng = null;
      double featuredRadius = 30.0; // Failsafe

      if (forceRefresh) {
        _docsNotifier.prepareForRadiusFetch(isHomeFeed: true);
      }

      final pos = await _docsNotifier.getUserPosition();
      if (pos != null && countryIso != null) {
        if (mounted) {
          _userLat = pos.latitude;
          _userLng = pos.longitude;
        }
        _organicClusterRadius = await _docsNotifier.fetchSmartClusterRadius(
          userLat: pos.latitude,
          userLng: pos.longitude,
          countryIso: countryIso,
        );
        featuredRadius = await _docsNotifier.fetchFeaturedPlatformRadius();
      }

      final homePopularLimit = await _docsNotifier.fetchHomePopularLimit();
      final homeFeaturedLimit = await _docsNotifier.fetchHomeFeaturedLimit();

      final results = await Future.wait([
        _docsNotifier.fetchSpecialties(forceRefresh: forceRefresh),

        _docsNotifier.fetchPopularDoctors(
          limit: homePopularLimit,
          forceRefresh: forceRefresh,
          isHomeFeed: true,
          maxRadiusKm: _organicClusterRadius,
        ),

        _docsNotifier.fetchFeaturedDoctors(
          limit: homeFeaturedLimit,
          forceRefresh: forceRefresh,
          isHomeFeed: true,
          maxRadiusKm: featuredRadius,
        ),

        _homeRepo.fetchBanners(
              countryIso,
              forceRefresh: forceRefresh,
              onFreshData: (fresh) {
                if (mounted) setState(() => _banners = fresh);
              },
            )
            .catchError((_) => <Map<String, dynamic>>[]),
      ]).timeout(const Duration(seconds: 12));

      if (mounted) {
        setState(() {
          _banners = results[3] as List<Map<String, dynamic>>;
        });

        if (!_contentController.isAnimating &&
            !_contentController.isCompleted) {
          _contentController.forward(from: 0.0);
        }
      }
    } catch (e) {
      debugPrint("Error loading home data: $e");
      // removed staggered network delay
    }
  }

  Widget _buildStaggered({
    required AnimationController controller,
    required Widget child,
    required double start,
    required double end,
    bool slideDown = false,
  }) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        if (controller.isCompleted || widget.isBackgroundLayer) return child!;

        final slideOffset =
            slideDown ? const Offset(0, -0.3) : const Offset(0, 0.15);
        final slide = Tween<Offset>(begin: slideOffset, end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: controller,
                curve: Interval(start, end, curve: Curves.easeOutQuart),
              ),
            )
            .value;

        final opacity = Tween<double>(begin: 0.0, end: 1.0)
            .animate(
              CurvedAnimation(
                parent: controller,
                curve: Interval(start, end, curve: Curves.easeOut),
              ),
            )
            .value;

        return Opacity(
          opacity: opacity,
          child: FractionalTranslation(translation: slide, child: child),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafeArea = MediaQuery.paddingOf(context).bottom;
    final dynamicBottomPadding = bottomSafeArea +17;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          RefreshIndicator(
            key: _refreshIndicatorKey,
            onRefresh: _refreshData,
            color: AppColors.primaryGreen,
            backgroundColor: Theme.of(context).colorScheme.surface,
            displacement: MediaQuery.paddingOf(context).top + 40,
            edgeOffset: 0, 
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
                padding: EdgeInsets.only(bottom: dynamicBottomPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListenableBuilder(
                      listenable: _docsNotifier,
                      builder: (context, _) {
                        final isColdLoading =
                            _docsNotifier.isLoading &&
                            _banners.isEmpty &&
                            _docsNotifier.specialties.isEmpty &&
                            _docsNotifier.homePopularDoctors.isEmpty &&
                            _docsNotifier.homeFeaturedDoctors.isEmpty;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildStaggered(
                              controller: _headerController,
                              start: 0.0,
                              end: 1.0,
                              slideDown: true,
                              child: _buildHeader(),
                            ),
                            if (isColdLoading)
                              SizedBox(
                                height: MediaQuery.of(context).size.height * 0.55,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                              )
                            else ...[
                              BackgroundSyncIndicator(
                                isSyncing: _docsNotifier.isLoading,
                              ),
                              _buildStaggered(
                                controller: _contentController,
                                start: 0.0,
                                end: 0.5,
                                child: HomeBanner(banners: _banners),
                              ),
                              _buildStaggered(
                                controller: _contentController,
                                start: 0.2,
                                end: 0.7,
                                child: _buildSpecialtiesSection(),
                              ),
                              _buildStaggered(
                                controller: _contentController,
                                start: 0.4,
                                end: 0.9,
                                child: _buildPopularSection(),
                              ),
                              _buildStaggered(
                                controller: _contentController,
                                start: 0.5,
                                end: 1.0,
                                child: _buildFeaturedSection(),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
              ),
            ),
          ),
        ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return ListenableBuilder(
      listenable: _profileNotifier,
      builder: (context, _) {
        return HomeHeader(
          fullName: !_profileNotifier.isLoaded ? "Loading..." : _profileNotifier.fullName,
          avatarUrl: _profileNotifier.avatarUrl,
          searchController: _searchController,
          onSearchTap: () async {
            await context.push(AppRoutes.globalSearch);
            if (mounted) _refreshData();
          },
        );
      },
    );
  }

  Widget _buildSpecialtiesSection() {
    return ListenableBuilder(
      listenable: _docsNotifier,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const HomeSectionHeader(
              title: "Specialities most relevant to you",
            ),
            HomeSpecialtiesRow(
              specialties: _docsNotifier.specialties,
              onSpecialtyTap: (id, name, iconUrl) async {
                await context.push(
                  AppRoutes.specialtyDoctorsById('$id'),
                  extra: SpecialtyRouteArgs(name: name, iconUrl: iconUrl),
                );
                if (mounted) _refreshData();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildPopularSection() {
    return ListenableBuilder(
      listenable: _docsNotifier,
      builder: (context, _) {
        final popular = _docsNotifier.sortDoctorsByHighlight(
          _docsNotifier.homePopularDoctors,
          _userLat,
          _userLng,
          _popularHighlightRangeKm,
        );
        final bool isLocalZone =
            _organicClusterRadius <= _popularHighlightRangeKm;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HomeSectionHeader(
              title:
                  isLocalZone ? "Popular Doctors" : "Recommended",
              onTap: () async {
                await context.push(AppRoutes.popularDoctors);
              },
            ),
            _buildPopularList(popular),
          ],
        );
      },
    );
  }

  Widget _buildPopularList(List<Map<String, dynamic>> popular) {
    Widget content;

    if (_docsNotifier.isLoading && popular.isEmpty) {
      content = const SizedBox(
        key: ValueKey('popular_loading'),
        height: 275,
        child: Center(child: PremiumAppLoader()),
      );
    } else if (popular.isEmpty) {
      content = const EmptyStateWidget(
        key: ValueKey('popular_empty'),
        icon: Icons.group_off_rounded,
        title: "No popular doctors found",
      );
    } else {
      content = SizedBox(
        key: ValueKey('popular_content_${popular.length}'),
        height: 275,
        child: ListView.separated(
          clipBehavior: Clip.none,
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 19),
          scrollDirection: Axis.horizontal,
          itemCount: popular.length,
          separatorBuilder: (_, __) => const SizedBox(width: 16),
          itemBuilder: (context, index) {
            final doc = popular[index];
            final ratingVal = double.tryParse(doc['rating']?.toString() ?? '0') ?? 0.0;
            final bool isPopularFlag = doc['is_popular'] == true;
            final double distance = _docsNotifier.calculateDoctorDistance(
              doc,
              _userLat,
              _userLng,
            );
            final bool isWithinHighlightRange = distance <= _popularHighlightRangeKm;
            final bool shouldHighlight = isWithinHighlightRange && (ratingVal > 0 || isPopularFlag);

            return HomePopularDoctorCard(
              id: doc['id'],
              name: doc['full_name'] ?? 'Unknown',
              specialty: doc['specialties']?['name'] ?? 'Specialist',
              rating: doc['rating']?.toString() ?? '0.0',
              imageUrl: doc['profile_picture_url'],
              isHighlighted: shouldHighlight,
            );
          },
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOutQuart,
      switchOutCurve: Curves.easeInQuart,
      child: content,
    );
  }
  
  Widget _buildFeaturedSection() {
    return ListenableBuilder(
      listenable: Listenable.merge([_docsNotifier, _favNotifier]),
      builder: (context, _) {
        final featured = _docsNotifier.homeFeaturedDoctors;

        if (featured.length < 3) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HomeSectionHeader(
              title: "Featured Doctors",
              onTap: () async {
                await context.push(AppRoutes.featuredDoctors);
              },
            ),
            _buildFeaturedList(featured),
          ],
        );
      },
    );
  }

  Widget _buildFeaturedList(List<Map<String, dynamic>> featured) {
    final Widget content = SizedBox(
      key: ValueKey('featured_content_${featured.length}'),
      height: 230,
      child: ListView.separated(
        clipBehavior: Clip.none,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: featured.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final doc = featured[index];
          return HomeFeaturedDoctorCard(
            id: doc['id'],
            name: doc['full_name'] ?? 'Unknown',
            specialty: doc['specialties']?['name'] ?? 'Specialist',
            price: doc['hourly_rate']?.toString() ?? '20',
            rating: doc['rating']?.toString() ?? '0.0',
            imageUrl: doc['profile_picture_url'],
            isFavorite: _favNotifier.isFavorite(doc['id']),
          );
        },
      ),
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOutQuart,
      switchOutCurve: Curves.easeInQuart,
      child: content,
    );
  }
}
