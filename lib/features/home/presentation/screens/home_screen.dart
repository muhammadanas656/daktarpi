import 'dart:async';
import '../../../../core/constants/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../doctors/presentation/favorites_notifier.dart';
import '../../../profile/presentation/profile_notifier.dart';
import '../../../doctors/data/doctor_repository.dart';
import '../../../doctors/presentation/models/doctors_route_args.dart';

import '../../../../presentation/widgets/custom_search_bar.dart';
import '../../../../presentation/widgets/home_popular_doctor_card.dart';
import '../../../../presentation/widgets/home_featured_doctor_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  final _doctorRepo = DoctorRepository();
  final _favNotifier = FavoritesNotifier.instance;
  final _profileNotifier = ProfileNotifier.instance;

  // --- STATE VARIABLES ---
  bool _isLoading = true;

  // Data Lists
  List<Map<String, dynamic>> _specialties = [];
  List<Map<String, dynamic>> _popularDoctors = [];
  List<Map<String, dynamic>> _featuredDoctors = [];

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
      final results = await Future.wait([
        _doctorRepo.fetchSpecialties(forceRefresh: forceRefresh),
        _doctorRepo.fetchPopularDoctors(limit: 5, forceRefresh: forceRefresh),
        _doctorRepo.fetchFeaturedDoctors(limit: 5, forceRefresh: forceRefresh),
      ]);

      if (mounted) {
        setState(() {
          _specialties = results[0];
          _popularDoctors = results[1];
          _featuredDoctors = results[2];
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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_buildHeader(), _buildBanner(), _buildContentSections()],
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 70, 24, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00C689), Color(0xFF008FA0)], // Richer Gradient
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x33008FA0),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Hi ${_profileNotifier.fullName}!",
                    style: AppTextStyles.body.copyWith(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "Find Your Doctor",
                    style: AppTextStyles.h1.copyWith(color: Colors.white),
                  ),
                ],
              ),
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white24,
                backgroundImage:
                    _profileNotifier.avatarUrl != null
                        ? NetworkImage(_profileNotifier.avatarUrl!)
                        : const NetworkImage('https://i.pravatar.cc/300'),
              ),
            ],
          ),
          const SizedBox(height: 25),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 0,
            ), // Removed padding from container
            child: CustomSearchBar(
              controller: _searchController,
              readOnly: true,
              hintText: "Search.....",
              onTap: () async {
                await context.push(AppRoutes.popularDoctors);
                if (mounted) _refreshData();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        width: double.infinity,
        height: 160,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF008FA0), Color(0xFF00C689)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20), // Premium Radius
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF008FA0).withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: 20,
              top: 30,
              child: SizedBox(
                width: 180,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Medical Center",
                      style: AppTextStyles.h3.copyWith(color: Colors.white),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Yorem ipsum dolor sit amet, consectetur adipiscing elit.",
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 10,
              bottom: 0,
              child: Image.network(
                "https://pngimg.com/d/doctor_PNG15988.png",
                height: 140,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ),
      ),
    );
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
        if (_specialties.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text("No specialties found"),
          )
        else
          SizedBox(
            height: 100,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              scrollDirection: Axis.horizontal,
              itemCount: _specialties.length,
              separatorBuilder: (_, __) => const SizedBox(width: 24),
              itemBuilder: (context, index) {
                final item = _specialties[index];
                return GestureDetector(
                  onTap:
                      () =>
                          _navigateToSpecialty(item['id'], item['name'] ?? ''),
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child:
                            item['icon_url'] != null
                                ? Image.network(item['icon_url'])
                                : _getFallbackIcon(item['name'] ?? ''),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item['name'] ?? '',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        _buildSectionHeader(
          "Popular Doctor",
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
        _buildSectionHeader(
          "Feature Doctor",
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

  // --- REUSABLE UI HELPERS ---
  Widget _getFallbackIcon(String name) {
    IconData iconData = Icons.medical_services_rounded;
    if (name.toLowerCase().contains('dentist')) {
      iconData = Icons.masks_rounded;
    }
    if (name.toLowerCase().contains('cardio')) {
      iconData = Icons.favorite_rounded;
    }
    if (name.toLowerCase().contains('eye')) {
      iconData = Icons.remove_red_eye_rounded;
    }
    return Icon(iconData, color: const Color(0xFF008FA0), size: 28);
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 25, 24, 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppTextStyles.h3),
          InkWell(
            onTap: onTap,
            child: Text("See all >", style: AppTextStyles.bodySmall),
          ),
        ],
      ),
    );
  }
}
