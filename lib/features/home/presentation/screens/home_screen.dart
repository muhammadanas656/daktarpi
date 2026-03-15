import 'dart:async';
import '../../../../core/constants/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../doctors/presentation/favorites_notifier.dart';
import '../../../profile/presentation/profile_notifier.dart';
import '../../../doctors/presentation/doctors_notifier.dart'; // PRO FIX: Central Notifier
import '../../../home/data/home_repository.dart';
import '../../../doctors/presentation/models/doctors_route_args.dart';

import '../../../../presentation/widgets/home_popular_doctor_card.dart';
import '../../../../presentation/widgets/home_featured_doctor_card.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/empty_state_widget.dart';

import '../widgets/home_header.dart';
import '../widgets/home_banner.dart';
import '../widgets/home_specialties_row.dart';
import '../widgets/home_section_header.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  final _homeRepo = HomeRepository();
  final _favNotifier = FavoritesNotifier.instance;
  final _profileNotifier = ProfileNotifier.instance;
  final _docsNotifier = DoctorsNotifier.instance; // PRO FIX: Singleton Vault

  // --- STATE VARIABLES ---
  bool _isScreenLoading = true; // PRO FIX: Unified loading state
  List<Map<String, dynamic>> _banners = [];

  @override
  void initState() {
    super.initState();
    _fetchAllData();
    _favNotifier.addListener(_onNotifierChanged);
    _profileNotifier.addListener(_onNotifierChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _favNotifier.removeListener(_onNotifierChanged);
    _profileNotifier.removeListener(_onNotifierChanged);
    super.dispose();
  }

  void _onNotifierChanged() {
    if (mounted) setState(() {});
  }

  // --- DATA LOADING ---
  Future<void> _refreshData() async {
    if (!mounted) return;
    await _fetchAllData(forceRefresh: true);
  }

  Future<void> _fetchAllData({bool forceRefresh = false}) async {
    if (!mounted) return;

    // PRO FIX: Only show full-screen loader if we have no data (First Launch)
    // If it's a pull-to-refresh, the RefreshIndicator handles the UI seamlessly.
    final isFirstLoad =
        _docsNotifier.popularDoctors.isEmpty && _banners.isEmpty;
    if (isFirstLoad) {
      setState(() => _isScreenLoading = true);
    }

    try {
      // 1. Await User Profile first (since we need their Country ISO for banners)
      if (forceRefresh || !_profileNotifier.isLoaded) {
        await Future.wait([
          _profileNotifier.loadProfile(),
          _favNotifier.loadFavorites(),
        ]);
      }

      final countryIso = _profileNotifier.profile?.countryIso;

      // 2. PRO FIX: Unified Future Lock
      // Group all fetches together so they resolve at the exact same millisecond
      final results = await Future.wait([
        _docsNotifier.fetchSpecialties(forceRefresh: forceRefresh),
        _docsNotifier.fetchPopularDoctors(limit: 5, forceRefresh: forceRefresh),
        _docsNotifier.fetchFeaturedDoctors(
          limit: 5,
          forceRefresh: forceRefresh,
        ),
        _homeRepo
            .fetchBanners(countryIso)
            .catchError((_) => <Map<String, dynamic>>[]),
      ]);

      if (mounted) {
        setState(() {
          // Banners are the 4th item in the Future.wait array (index 3)
          _banners = results[3] as List<Map<String, dynamic>>;
          _isScreenLoading = false; // Unlock the UI!
        });
      }
    } catch (e) {
      debugPrint("Error loading home data: $e");
      if (mounted) setState(() => _isScreenLoading = false);
    }
  }

  Future<void> _navigateToSpecialty(
    int specialtyId,
    String specialtyName,
  ) async {
    await context.push(
      AppRoutes.specialtyDoctorsById('$specialtyId'),
      extra: SpecialtyRouteArgs(name: specialtyName),
    );
    if (mounted) _refreshData();
  }

  @override
  Widget build(BuildContext context) {
    // PRO FIX: Clean, singular loading condition
    if (_isScreenLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const AppLoader(),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: AppColors.primaryGreen,
        backgroundColor: Theme.of(context).colorScheme.surface,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildBanner(),
              ListenableBuilder(
                listenable: _docsNotifier,
                builder: (context, _) => _buildContentSections(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildHeader() {
    return HomeHeader(
      fullName: _profileNotifier.fullName,
      avatarUrl: _profileNotifier.avatarUrl,
      searchController: _searchController,
      onSearchTap: () async {
        await context.push(AppRoutes.globalSearch);
        if (mounted) _refreshData();
      },
    );
  }

  Widget _buildBanner() {
    return HomeBanner(banners: _banners);
  }

  Widget _buildContentSections() {
    final specialties = _docsNotifier.specialties;
    final popular = _docsNotifier.popularDoctors;
    final featured = _docsNotifier.featuredDoctors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // PRO FIX: Matched padding and text style to HomeSectionHeader exactly!
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 25, 24, 15),
          child: Text(
            "Specialities most relevant to you",
            style: AppTextStyles.h3(context), // Switched from h2 to h3
          ),
        ),
        HomeSpecialtiesRow(
          specialties: specialties,
          onSpecialtyTap: _navigateToSpecialty,
        ),
        HomeSectionHeader(
          title: "Popular Doctor",
          onTap: () async {
            await context.push(AppRoutes.popularDoctors);
            if (mounted) _refreshData();
          },
        ),
        if (popular.isEmpty)
          const EmptyStateWidget(
            icon: Icons.group_off_rounded,
            title: "No popular doctors found",
          )
        else
          SizedBox(
            height: 240,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24),
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
          ),
        HomeSectionHeader(
          title: "Feature Doctor",
          onTap: () async {
            await context.push(AppRoutes.featuredDoctors);
            if (mounted) _refreshData();
          },
        ),
        if (featured.isEmpty)
          const EmptyStateWidget(
            icon: Icons.star_border_rounded,
            title: "No featured doctors found",
          )
        else
          SizedBox(
            height: 160,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              scrollDirection: Axis.horizontal,
              itemCount: featured.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final doc = featured[index];
                return HomeFeaturedDoctorCard(
                  id: doc['id'],
                  name: doc['full_name'] ?? 'Unknown',
                  price: doc['hourly_rate']?.toString() ?? '20',
                  rating: doc['rating']?.toString() ?? '4.8',
                  imageUrl: doc['profile_picture_url'],
                  isFavorite: _favNotifier.isFavorite(doc['id']),
                );
              },
            ),
          ),
        const SizedBox(height: 40),
      ],
    );
  }
}
