import 'dart:async';
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

class HomeScreen extends StatefulWidget {
  final bool isBackgroundLayer;
  
  const HomeScreen({super.key, this.isBackgroundLayer = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _homeRepo = HomeRepository();
  final _favNotifier = FavoritesNotifier.instance;
  final _profileNotifier = ProfileNotifier.instance;
  final _docsNotifier = DoctorsNotifier.instance;

  late AnimationController _launchController;
  List<Map<String, dynamic>> _banners = [];

  @override
  void initState() {
    super.initState();
    _launchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    if (!widget.isBackgroundLayer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_fetchAllData());
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _launchController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    await _fetchAllData(forceRefresh: true);
  }

  Future<void> _fetchAllData({bool forceRefresh = false}) async {
    if (!mounted) return;

    try {
      if (forceRefresh || !_profileNotifier.isLoaded) {
        await Future.wait([
          _profileNotifier.loadProfile(),
          _favNotifier.loadFavorites(),
        ]).timeout(const Duration(seconds: 10));
      }

      final countryIso = _profileNotifier.profile?.countryIso;

      final results = await Future.wait([
        _docsNotifier.fetchSpecialties(forceRefresh: forceRefresh),
        _docsNotifier.fetchPopularDoctors(limit: 5, forceRefresh: forceRefresh, isHomeFeed: true),
        _docsNotifier.fetchFeaturedDoctors(limit: 5, forceRefresh: forceRefresh, isHomeFeed: true),
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

        if (!_launchController.isAnimating && !_launchController.isCompleted) {
          _launchController.forward();
        }
      }
    } catch (e) {
      debugPrint("Error loading home data: $e");
      if (mounted && !_launchController.isCompleted) {
        _launchController.forward();
      }
    }
  }

  Widget _buildStaggered({
    required Widget child,
    required double start,
    required double end,
    bool slideDown = false,
  }) {
    return AnimatedBuilder(
      animation: _launchController,
      builder: (context, child) {
        if (_launchController.isCompleted || widget.isBackgroundLayer) return child!;

        final slideOffset = slideDown ? const Offset(0, -0.3) : const Offset(0, 0.15);
        final slide = Tween<Offset>(begin: slideOffset, end: Offset.zero)
            .animate(CurvedAnimation(parent: _launchController, curve: Interval(start, end, curve: Curves.easeOutQuart))).value;

        final opacity = Tween<double>(begin: 0.0, end: 1.0)
            .animate(CurvedAnimation(parent: _launchController, curve: Interval(start, end, curve: Curves.easeOut))).value;

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
      body: RefreshIndicator(
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
                _buildStaggered(
                  start: 0.1,
                  end: 0.6,
                  slideDown: true,
                  child: _buildHeader(), 
                ),
                _buildStaggered(
                  start: 0.2,
                  end: 0.7,
                  child: HomeBanner(banners: _banners),
                ),
                _buildStaggered(
                  start: 0.3,
                  end: 0.8,
                  child: _buildSpecialtiesSection(),
                ),
                _buildStaggered(
                  start: 0.4,
                  end: 0.9,
                  child: _buildPopularSection(),
                ),
                _buildStaggered(
                  start: 0.5,
                  end: 1.0,
                  child: _buildFeaturedSection(),
                ),
              ],
            ),
          ),
        ),
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HomeSectionHeader(
              title: "Popular Doctor",
              onTap: () async {
                await context.push(AppRoutes.popularDoctors);
              },
            ),
            _buildPopularList(_docsNotifier.homePopularDoctors),
          ],
        );
      },
    );
  }

  Widget _buildFeaturedSection() {
    return ListenableBuilder(
      listenable: Listenable.merge([_docsNotifier, _favNotifier]),
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HomeSectionHeader(
              title: "Feature Doctor",
              onTap: () async {
                await context.push(AppRoutes.featuredDoctors);
              },
            ),
            _buildFeaturedList(_docsNotifier.homeFeaturedDoctors),
          ],
        );
      },
    );
  }

  Widget _buildPopularList(List<Map<String, dynamic>> popular) {
    if (popular.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.group_off_rounded,
        title: "No popular doctors found",
      );
    }
    return SizedBox(
      height: 275, // OVERFLOW FIX: Accommodates your new card physics
      child: ListView.separated(
        clipBehavior: Clip.none,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 19),
        scrollDirection: Axis.horizontal,
        itemCount: popular.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final doc = popular[index];
          return HomePopularDoctorCard(
            id: doc['id'],
            name: doc['full_name'] ?? 'Unknown',
            specialty: doc['specialties']?['name'] ?? 'Specialist',
            rating: doc['rating']?.toString() ?? '0.0',
            imageUrl: doc['profile_picture_url'],
          );
        },
      ),
    );
  }

  Widget _buildFeaturedList(List<Map<String, dynamic>> featured) {
    if (featured.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.star_border_rounded,
        title: "No featured doctors found",
      );
    }
    return SizedBox(
      height: 230, // OVERFLOW FIX: Accommodates your new card physics & specialty text
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
            rating: doc['rating']?.toString() ?? '4.8',
            imageUrl: doc['profile_picture_url'],
            isFavorite: _favNotifier.isFavorite(doc['id']),
          );
        },
      ),
    );
  }
}
