import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../presentation/widgets/app_floating_dialog.dart';
import '../../../../presentation/widgets/home_featured_doctor_card.dart';
import '../../../../presentation/widgets/home_popular_doctor_card.dart';
import '../../../../presentation/widgets/primary_button.dart';
import '../../../doctors/presentation/doctors_notifier.dart';
import '../../../doctors/presentation/favorites_notifier.dart';
import '../../../doctors/presentation/models/doctors_route_args.dart';
import '../../../home/data/home_repository.dart';
import '../../../profile/presentation/profile_notifier.dart';
import '../../../settings/presentation/settings_notifier.dart';
import '../widgets/home_banner.dart';
import '../widgets/home_header.dart';
import '../widgets/home_section_header.dart';
import '../widgets/home_specialties_row.dart';

class HomeScreen extends StatefulWidget {
  final bool isBackgroundLayer;

  const HomeScreen({super.key, this.isBackgroundLayer = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _searchController = TextEditingController();
  final _homeRepo = HomeRepository();
  final _favNotifier = FavoritesNotifier.instance;
  final _profileNotifier = ProfileNotifier.instance;
  final _docsNotifier = DoctorsNotifier.instance;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  List<Map<String, dynamic>> _banners = HomeRepository.currentBanners;
  double _popularHighlightRangeKm = 25.0;
  double _organicClusterRadius = 500.0;
  double? _userLat;
  double? _userLng;
  bool _isFirstLoad = true;
  bool _isContentReady = false;
  bool _dataLoaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.isBackgroundLayer) {
      _isContentReady = true;
      _dataLoaded = true;
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_fetchAllData(forceRefresh: false));
    });
  }

  void _attemptShowContent() {
    if (_dataLoaded && !_isContentReady) {
      setState(() => _isContentReady = true);
    }
  }

  Future<void> _evaluateRegionalDensity() async {
    if (widget.isBackgroundLayer ||
        SettingsNotifier.instance.hasSeenRegionalWarning) {
      return;
    }

    final uniqueDocIds = <int>{};
    for (final doc in _docsNotifier.homePopularDoctors) {
      final id = doc['id'];
      if (id is int) uniqueDocIds.add(id);
    }
    for (final doc in _docsNotifier.homeFeaturedDoctors) {
      final id = doc['id'];
      if (id is int) uniqueDocIds.add(id);
    }

    final count = uniqueDocIds.length;
    final threshold = await _docsNotifier.fetchRegionalScarcityThreshold();

    if (count > threshold) return;

    final scarcityRadiusKm = await _docsNotifier.fetchRegionalScarcityRadius();

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted || SettingsNotifier.instance.hasSeenRegionalWarning) return;
      _showGeofenceDialog(count, scarcityRadiusKm);
    });
  }

  void _showGeofenceDialog(int doctorCount, int searchRadiusKm) {
    final isZero = doctorCount == 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => AppFloatingDialog(
        headerIcon: isZero ? Icons.public_off_rounded : Icons.radar_rounded,
        iconColor: isZero ? AppColors.dangerRed : Colors.orange,
        title: isZero ? "Coming to Your Region" : "Growing in Your Area",
        description: isZero
            ? "We haven't officially launched our network in your current location yet. Stay tuned as we expand globally!"
            : "We are actively expanding! We currently have a limited network of $doctorCount doctor${doctorCount == 1 ? '' : 's'} within $searchRadiusKm km of you. More specialists will be available soon.",
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: isZero
                ? AppColors.dangerRed.withValues(alpha: 0.1)
                : Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isZero
                  ? AppColors.dangerRed.withValues(alpha: 0.3)
                  : Colors.orange.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isZero
                        ? Icons.location_off_rounded
                        : Icons.my_location_rounded,
                    color: isZero ? AppColors.dangerRed : Colors.orange,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isZero
                        ? "0 Doctors Nearby"
                        : "$doctorCount Doctor${doctorCount == 1 ? '' : 's'} Found",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isZero
                          ? AppColors.dangerRed
                          : (isDark
                              ? Colors.orange.shade300
                              : Colors.orange.shade800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "Within $searchRadiusKm km range",
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white54 : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        actions: Row(
          children: [
            Expanded(
              child: PrimaryButton(
                label: isZero ? "Notify Me" : "Continue",
                backgroundColor:
                    isZero ? AppColors.dangerRed : AppColors.primaryGreen,
                onTap: () {
                  SettingsNotifier.instance.markRegionalWarningSeen();
                  Navigator.pop(ctx);
                },
                height: 54,
                borderRadius: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    await _fetchAllData(forceRefresh: true);
  }

  Future<void> _fetchAllData({bool forceRefresh = false}) async {
    if (!mounted) return;

    await _docsNotifier.prehydrateHomeFeed();

    if (_docsNotifier.homePopularDoctors.isNotEmpty ||
        _docsNotifier.specialties.isNotEmpty) {
      if (mounted && !_dataLoaded) {
        _dataLoaded = true;
        _attemptShowContent();
      }
    }

    final tempIso = _profileNotifier.profile?.countryIso ?? 'US';
    _homeRepo.fetchBanners(tempIso, forceRefresh: false).then((banners) {
      if (mounted && _banners.isEmpty) setState(() => _banners = banners);
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
      double featuredRadius = 30.0;

      if (forceRefresh) _docsNotifier.prepareForRadiusFetch(isHomeFeed: true);

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
        _homeRepo
            .fetchBanners(
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
          _isFirstLoad = false;
        });

        _dataLoaded = true;
        _attemptShowContent();
        _evaluateRegionalDensity();
      }
    } catch (e) {
      debugPrint("Error loading home data: $e");
      if (mounted) {
        setState(() => _isFirstLoad = false);
        _dataLoaded = true;
        _attemptShowContent();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final bottomSafeArea = MediaQuery.paddingOf(context).bottom;
    final dynamicBottomPadding = bottomSafeArea + 17;

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
              behavior:
                  ScrollConfiguration.of(context).copyWith(overscroll: false),
              child: SingleChildScrollView(
                clipBehavior: Clip.none,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                padding: EdgeInsets.only(bottom: dynamicBottomPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListenableBuilder(
                      listenable: _docsNotifier,
                      builder: (context, _) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader()
                                .animate(target: _isContentReady ? 1 : 0)
                                .fade(
                                  duration: 600.ms,
                                  curve: Curves.easeOut,
                                )
                                .slideY(
                                  begin: -0.2,
                                  end: 0,
                                  duration: 600.ms,
                                  curve: Curves.easeOutCubic,
                                ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 350),
                              reverseDuration:
                                  const Duration(milliseconds: 250),
                              switchInCurve: Curves.easeOut,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder:
                                  (Widget child, Animation<double> animation) {
                                if (child.key == const ValueKey('home_loader')) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: ScaleTransition(
                                      scale: Tween<double>(
                                        begin: 0.85,
                                        end: 1.0,
                                      ).animate(animation),
                                      child: child,
                                    ),
                                  );
                                }
                                return child;
                              },
                              child: !_isContentReady
                                  ? SizedBox(
                                      key: const ValueKey('home_loader'),
                                      height:
                                          MediaQuery.of(context).size.height *
                                              0.55,
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          color: AppColors.primaryGreen,
                                          strokeWidth: 3,
                                        ),
                                      ),
                                    )
                                  : Column(
                                      key: const ValueKey('home_content'),
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        HomeBanner(banners: _banners)
                                            .animate(delay: 50.ms)
                                            .fade(
                                              duration: 500.ms,
                                              curve: Curves.easeOut,
                                            )
                                            .slideY(
                                              begin: 0.1,
                                              end: 0,
                                              duration: 500.ms,
                                              curve: Curves.easeOutCubic,
                                            ),
                                        _buildSpecialtiesSection()
                                            .animate(delay: 150.ms)
                                            .fade(
                                              duration: 500.ms,
                                              curve: Curves.easeOut,
                                            )
                                            .slideY(
                                              begin: 0.1,
                                              end: 0,
                                              duration: 500.ms,
                                              curve: Curves.easeOutCubic,
                                            ),
                                        _buildPopularSection()
                                            .animate(delay: 250.ms)
                                            .fade(
                                              duration: 500.ms,
                                              curve: Curves.easeOut,
                                            )
                                            .slideY(
                                              begin: 0.1,
                                              end: 0,
                                              duration: 500.ms,
                                              curve: Curves.easeOutCubic,
                                            ),
                                        _buildFeaturedSection()
                                            .animate(delay: 350.ms)
                                            .fade(
                                              duration: 500.ms,
                                              curve: Curves.easeOut,
                                            )
                                            .slideY(
                                              begin: 0.1,
                                              end: 0,
                                              duration: 500.ms,
                                              curve: Curves.easeOutCubic,
                                            ),
                                      ],
                                    ),
                            ),
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
          fullName:
              !_profileNotifier.isLoaded ? "Loading..." : _profileNotifier.fullName,
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
        final isLocalZone = _organicClusterRadius <= _popularHighlightRangeKm;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HomeSectionHeader(
              title: isLocalZone ? "Popular Doctors" : "Recommended",
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

    if (popular.isEmpty && _docsNotifier.isLoading) {
      content = const SizedBox(
        key: ValueKey('popular_loading'),
        height: 275,
      );
    } else if (popular.isEmpty) {
      content = const EmptyStateWidget(
        key: ValueKey('popular_empty'),
        icon: Icons.group_off_rounded,
        title: "No popular doctors found",
      );
    } else {
      content = SizedBox(
        key: const ValueKey('popular_content_list'),
        height: 275,
        child: ListView.builder(
          clipBehavior: Clip.none,
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 19),
          scrollDirection: Axis.horizontal,
          itemCount: popular.length,
          itemBuilder: (context, index) {
            final doc = popular[index];
            final docId = doc['id'] as int;
            final ratingVal =
                double.tryParse(doc['rating']?.toString() ?? '0') ?? 0.0;
            final isPopularFlag = doc['is_popular'] == true;
            final distance = _docsNotifier.calculateDoctorDistance(
              doc,
              _userLat,
              _userLng,
            );
            final shouldHighlight = (distance <= _popularHighlightRangeKm) &&
                (ratingVal > 0 || isPopularFlag);

            return Padding(
              key: ValueKey('${shouldHighlight ? "hi" : "std"}_$docId'),
              padding: EdgeInsets.only(
                right: index == popular.length - 1 ? 0 : 16.0,
              ),
              child: HomePopularDoctorCard(
                index: index,
                id: docId,
                name: doc['full_name'] ?? 'Unknown',
                specialty: doc['specialties']?['name'] ?? 'Specialist',
                rating: doc['rating']?.toString() ?? '0.0',
                imageUrl: doc['profile_picture_url'],
                isHighlighted: shouldHighlight,
              ),
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
    final content = SizedBox(
      key: const ValueKey('featured_content_list'),
      height: 230,
      child: ListView.builder(
        clipBehavior: Clip.none,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: featured.length,
        itemBuilder: (context, index) {
          final doc = featured[index];
          final docId = doc['id'] as int;

          return Padding(
            key: ValueKey('feat_$docId'),
            padding: EdgeInsets.only(
              right: index == featured.length - 1 ? 0 : 16.0,
            ),
            child: HomeFeaturedDoctorCard(
              index: index,
              id: docId,
              name: doc['full_name'] ?? 'Unknown',
              specialty: doc['specialties']?['name'] ?? 'Specialist',
              price: doc['hourly_rate']?.toString() ?? '20',
              rating: doc['rating']?.toString() ?? '0.0',
              imageUrl: doc['profile_picture_url'],
              isFavorite: _favNotifier.isFavorite(docId),
            ),
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
