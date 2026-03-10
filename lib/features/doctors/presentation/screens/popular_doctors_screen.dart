import 'dart:async';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../favorites_notifier.dart';
import '../../../profile/presentation/profile_notifier.dart';
import '../../data/doctor_repository.dart';

import '../../../../presentation/widgets/doctor_list_card.dart';
import '../../../../presentation/widgets/custom_search_bar.dart';

class PopularDoctorsScreen extends StatefulWidget {
  const PopularDoctorsScreen({super.key});

  @override
  State<PopularDoctorsScreen> createState() => _PopularDoctorsScreenState();
}

class _PopularDoctorsScreenState extends State<PopularDoctorsScreen> {
  final _searchController = TextEditingController();
  final _doctorRepo = DoctorRepository();
  final _favNotifier = FavoritesNotifier.instance;
  final _profileNotifier = ProfileNotifier.instance;
  Timer? _debounce;

  // Data State
  List<Map<String, dynamic>> _doctors = [];
  bool _isLoading = true;
  bool _showClearIcon = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _favNotifier.addListener(_onStateChanged);
    _profileNotifier.addListener(_onStateChanged);

    // Listen to text changes for UI (X icon) and Search Logic
    _searchController.addListener(() {
      setState(() {
        _showClearIcon = _searchController.text.isNotEmpty;
      });
      _onSearchChanged();
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

  // --- SEARCH LOGIC (Debouncing) ---
  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() => _isLoading = true);
      _fetchData(query: _searchController.text);
    });
  }

  // --- CLEAR SEARCH ---
  void _clearSearch() {
    _searchController.clear();
    FocusScope.of(context).unfocus();
  }

  // --- FETCH DATA ---
  Future<void> _fetchData({String? query, bool forceRefresh = false}) async {
    try {
      final countryIso = _profileNotifier.profile?.countryIso;
      final doctors = await _doctorRepo.fetchPopularDoctors(
        query: query,
        forceRefresh: forceRefresh,
        countryIso: countryIso,
      );

      if (!_favNotifier.isLoaded) {
        await _favNotifier.loadFavorites();
      }

      if (mounted) {
        setState(() {
          _doctors = doctors;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- NAVIGATION LOGIC ---
  Future<void> _navigateToDoctorDetails(int doctorId, Map<String, dynamic> doctorData) async {
    await context.push(AppRoutes.doctorDetailsById('$doctorId'), extra: doctorData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // PRO FIX: Extend body to let gradient flow underneath
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Center(
          child: InkWell(
            onTap: () => context.pop(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                // PRO FIX: Dynamic surface color for the back button
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colorBorder),
                boxShadow: AppStyles.cardShadow(context),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                size: 18,
                color: context.colorTextDark,
              ),
            ),
          ),
        ),
        title: Text(
          "Popular Doctors",
          style: AppTextStyles.h1(context).copyWith(fontSize: 22),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppStyles.pageGradient(context)),
        // PRO FIX: SafeArea prevents content from clipping into the notch
        child: SafeArea(
          child: Column(
            children: [
              // --- SEARCH BAR ---
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
                child: CustomSearchBar(
                  controller: _searchController,
                  hintText: "Search",
                  showClearIcon: _showClearIcon,
                  onClear: _clearSearch,
                ),
              ),

              // --- DOCTOR LIST ---
              Expanded(
                child:
                    _isLoading
                        ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryGreen,
                          ),
                        )
                        : _doctors.isEmpty
                        ? const Center(child: Text("No popular doctors found"))
                        : RefreshIndicator(
                          onRefresh: () => _fetchData(forceRefresh: true),
                          color: AppColors.primaryGreen,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                            itemCount: _doctors.length,
                            separatorBuilder:
                                (context, index) => const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              final doctor = _doctors[index];
                              final docId = doctor['id'] as int;
                              final specialtyName =
                                  doctor['specialties'] != null
                                      ? doctor['specialties']['name']
                                      : 'Specialist';
                              final views =
                                  doctor['views_count']?.toString() ?? '0';

                              final isFavorite = _favNotifier.isFavorite(docId);

                              return DoctorListCard(
                                id: docId,
                                name: doctor['full_name'] ?? 'Unknown',
                                specialty: " $specialtyName",
                                rating: doctor['rating']?.toString() ?? '0.0',
                                views: views,
                                imageUrl: doctor['profile_picture_url'],
                                isFavorite: isFavorite,
                                heroTagPrefix: 'popular-',
                                onFavoriteTap: () => _favNotifier.toggle(docId),
                                onCardTap:
                                    () => _navigateToDoctorDetails(docId, doctor),
                              );
                            },
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
