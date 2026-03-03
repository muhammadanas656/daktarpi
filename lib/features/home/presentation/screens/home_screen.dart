import 'dart:async';
import '../../../../core/constants/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../doctors/presentation/favorites_notifier.dart';
import '../../../profile/presentation/profile_notifier.dart';
import '../../../doctors/data/doctor_repository.dart';
import '../../../home/data/home_repository.dart';
import '../../../doctors/presentation/models/doctors_route_args.dart';

import '../../../../presentation/widgets/home_popular_doctor_card.dart';
import '../../../../presentation/widgets/home_featured_doctor_card.dart';

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
  final _doctorRepo = DoctorRepository();
  final _homeRepo = HomeRepository();
  final _favNotifier = FavoritesNotifier.instance;
  final _profileNotifier = ProfileNotifier.instance;

  // --- STATE VARIABLES ---
  bool _isLoading = true;

  // Data Lists
  List<Map<String, dynamic>> _specialties = [];
  List<Map<String, dynamic>> _popularDoctors = [];
  List<Map<String, dynamic>> _featuredDoctors = [];
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
    try {
      // Load profile + favorites via notifiers (shared across screens)
      // Profile/Favorites handled by notifiers, so we usually just sync them if needed.
      // Notifiers have their own internal state management.
      if (forceRefresh) {
        await Future.wait([
          _profileNotifier.loadProfile(),
          _favNotifier.loadFavorites(),
        ]);
      } else {
        // Initial load check
        if (!_profileNotifier.isLoaded) _profileNotifier.loadProfile();
        if (_favNotifier.favoriteIds.isEmpty) _favNotifier.loadFavorites();
      }

      // Load screen-specific data with caching
      final userLocation = _profileNotifier.profile?.location;
      final countryIso = _profileNotifier.profile?.countryIso;

      final results = await Future.wait([
        _doctorRepo.fetchSpecialties(forceRefresh: forceRefresh),
        _doctorRepo.fetchPopularDoctors(
          limit: 5,
          forceRefresh: forceRefresh,
          userLocation: userLocation,
          countryIso: countryIso,
        ),
        _doctorRepo.fetchFeaturedDoctors(
          limit: 5,
          forceRefresh: forceRefresh,
          userLocation: userLocation,
          countryIso: countryIso,
        ),
        _homeRepo.fetchBanners(countryIso),
      ]);

      if (mounted) {
        setState(() {
          _specialties = results[0];
          _popularDoctors = results[1];
          _featuredDoctors = results[2];
          _banners = results[3];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading home data: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFFBFBFB),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: AppColors.primaryGreen,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_buildHeader(), _buildBanner(), _buildContentSections()],
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
        await context.push(AppRoutes.popularDoctors);
        if (mounted) _refreshData();
      },
    );
  }

  Widget _buildBanner() {
    return HomeBanner(banners: _banners);
  }

  Widget _buildContentSections() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            "Specialities most relevant to you",
            style: AppTextStyles.h2.copyWith(fontSize: 18),
          ),
        ),
        const SizedBox(height: 16),
        HomeSpecialtiesRow(
          specialties: _specialties,
          onSpecialtyTap: _navigateToSpecialty,
        ),
        HomeSectionHeader(
          title: "Popular Doctor",
          onTap: () async {
            await context.push(AppRoutes.popularDoctors);
            if (mounted) _refreshData();
          },
        ),
        if (_popularDoctors.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text("No popular doctors found"),
          )
        else
          SizedBox(
            height: 240,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              scrollDirection: Axis.horizontal,
              itemCount: _popularDoctors.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final doc = _popularDoctors[index];
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
        if (_featuredDoctors.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text("No featured doctors found"),
          )
        else
          SizedBox(
            height: 160,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              scrollDirection: Axis.horizontal,
              itemCount: _featuredDoctors.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final doc = _featuredDoctors[index];
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
