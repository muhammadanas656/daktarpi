import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../doctors/presentation/favorites_notifier.dart';
import '../../../profile/presentation/profile_notifier.dart';
import '../../../doctors/presentation/doctors_notifier.dart';
import '../../../home/data/home_repository.dart';
import '../../../doctors/presentation/models/doctors_route_args.dart';

import '../../../../presentation/widgets/home_popular_doctor_card.dart';
import '../../../../presentation/widgets/home_featured_doctor_card.dart';
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
  final _docsNotifier = DoctorsNotifier.instance;

  bool _isScreenLoading = true;
  List<Map<String, dynamic>> _banners = [];

  final List<Map<String, dynamic>> _dummyBanners = [
    {
      'title': 'Loading Medical Center Name',
      'subtitle': 'Find the best doctors in your area very easily.',
      'image_url': null,
    },
  ];

  final List<Map<String, dynamic>> _dummyDoctors = List.generate(
    3,
    (index) => {
      'id': 0,
      'full_name': 'Dr. Patient Name',
      'specialties': {'name': 'General Specialist'},
      'hourly_rate': '100',
      'rating': '4.5',
      'profile_picture_url': '',
    },
  );

  final List<Map<String, dynamic>> _dummySpecialties = List.generate(
    4,
    (index) => {'id': 0, 'name': 'Medical', 'icon_url': ''},
  );

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

  Future<void> _refreshData() async {
    if (!mounted) return;
    await _fetchAllData(forceRefresh: true);
  }

  Future<void> _fetchAllData({bool forceRefresh = false}) async {
    if (!mounted) return;

    final isFirstLoad = _docsNotifier.popularDoctors.isEmpty && _banners.isEmpty;
    if (isFirstLoad) {
      setState(() => _isScreenLoading = true);
    }

    try {
      if (forceRefresh || !_profileNotifier.isLoaded) {
        await Future.wait([
          _profileNotifier.loadProfile(),
          _favNotifier.loadFavorites(),
        ]);
      }

      final countryIso = _profileNotifier.profile?.countryIso;

      final results = await Future.wait([
        _docsNotifier.fetchSpecialties(forceRefresh: forceRefresh),
        _docsNotifier.fetchPopularDoctors(limit: 5, forceRefresh: forceRefresh),
        _docsNotifier.fetchFeaturedDoctors(limit: 5, forceRefresh: forceRefresh),
        _homeRepo.fetchBanners(countryIso).catchError((_) => <Map<String, dynamic>>[]),
      ]);

      if (mounted) {
        setState(() {
          _banners = results[3] as List<Map<String, dynamic>>;
          _isScreenLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading home data: $e");
      if (mounted) setState(() => _isScreenLoading = false);
    }
  }

  // PRO FIX: Centralized Shimmer effect so both isolated skeletons match perfectly
  ShimmerEffect get _shimmerEffect => ShimmerEffect(
        baseColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2D3748)
            : Colors.grey[200]!,
        highlightColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF4A5568)
            : Colors.white,
        duration: const Duration(milliseconds: 2000), 
      );

  @override
  Widget build(BuildContext context) {
    final specialtiesToShow = _isScreenLoading ? _dummySpecialties : _docsNotifier.specialties;
    final popularToShow = _isScreenLoading ? _dummyDoctors : _docsNotifier.popularDoctors;
    final featuredToShow = _isScreenLoading ? _dummyDoctors : _docsNotifier.featuredDoctors;
    final bannersToShow = (_isScreenLoading && _banners.isEmpty) ? _dummyBanners : _banners;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // PRO FIX: The root Skeletonizer is gone! 
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: AppColors.primaryGreen,
        backgroundColor: Theme.of(context).colorScheme.surface,
        child: SingleChildScrollView(
          physics: _isScreenLoading
              ? const NeverScrollableScrollPhysics()
              : const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              
              // 1. ISOLATED HEADER SKELETON
              // This acts entirely on its own. As soon as Profile loads (usually 0ms), it reveals!
              Skeletonizer(
                enabled: !_profileNotifier.isLoaded,
                effect: _shimmerEffect,
                textBoneBorderRadius: TextBoneBorderRadius(BorderRadius.circular(8)),
                child: _buildHeader(),
              ),

              const SizedBox(height: 24),

              // 2. ISOLATED BODY SKELETON
              // This stays shimmering until the Banners & Doctors network call finishes.
              Skeletonizer(
                enabled: _isScreenLoading,
                effect: _shimmerEffect,
                textBoneBorderRadius: TextBoneBorderRadius(BorderRadius.circular(8)),
                ignoreContainers: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HomeBanner(banners: bannersToShow),
                    _buildContentSections(
                      specialties: specialtiesToShow,
                      popular: popularToShow,
                      featured: featuredToShow,
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

  Widget _buildHeader() {
    return HomeHeader(
      fullName: !_profileNotifier.isLoaded
          ? "Loading User"
          : _profileNotifier.fullName,
      avatarUrl: _profileNotifier.avatarUrl,
      searchController: _searchController,
      onSearchTap: () async {
        await context.push(AppRoutes.globalSearch);
        if (mounted) _refreshData();
      },
    );
  }

  Widget _buildContentSections({
    required List<Map<String, dynamic>> specialties,
    required List<Map<String, dynamic>> popular,
    required List<Map<String, dynamic>> featured,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 15),
          child: Text(
            "Specialities most relevant to you",
            style: AppTextStyles.h3(context),
          ),
        ),
        HomeSpecialtiesRow(
          specialties: specialties,
          onSpecialtyTap: (id, name) async {
            await context.push(
              AppRoutes.specialtyDoctorsById('$id'),
              extra: SpecialtyRouteArgs(name: name),
            );
            if (mounted) _refreshData();
          },
        ),
        HomeSectionHeader(
          title: "Popular Doctor",
          onTap: () async {
            await context.push(AppRoutes.popularDoctors);
            if (mounted) _refreshData();
          },
        ),
        _buildPopularList(popular),
        HomeSectionHeader(
          title: "Feature Doctor",
          onTap: () async {
            await context.push(AppRoutes.featuredDoctors);
            if (mounted) _refreshData();
          },
        ),
        _buildFeaturedList(featured),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildPopularList(List<Map<String, dynamic>> popular) {
    if (popular.isEmpty && !_isScreenLoading) {
      return const EmptyStateWidget(
        icon: Icons.group_off_rounded,
        title: "No popular doctors found",
      );
    }
    return SizedBox(
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
    );
  }

  Widget _buildFeaturedList(List<Map<String, dynamic>> featured) {
    if (featured.isEmpty && !_isScreenLoading) {
      return const EmptyStateWidget(
        icon: Icons.star_border_rounded,
        title: "No featured doctors found",
      );
    }
    return SizedBox(
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
    );
  }
}