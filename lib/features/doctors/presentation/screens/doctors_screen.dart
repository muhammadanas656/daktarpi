import 'dart:async';
import '../../../../core/constants/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../favorites_notifier.dart';
import '../../data/doctor_repository.dart';
import '../../../../presentation/widgets/custom_search_bar.dart';
import '../../../../presentation/widgets/doctor_list_card.dart';

class DoctorsScreen extends StatefulWidget {
  const DoctorsScreen({super.key});

  @override
  State<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends State<DoctorsScreen> {
  final _doctorRepo = DoctorRepository();
  final _favNotifier = FavoritesNotifier.instance;

  // --- STATE ---
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _doctors = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';
  Timer? _debounce;

  final List<String> _filters = [
    'All',
    'Nearest',
    'Hospital',
    'Best Rated',
    'General',
    'Dental',
  ];

  @override
  void initState() {
    super.initState();
    _fetchDoctors();
    _searchController.addListener(_onSearchChanged);
    _favNotifier.addListener(_onFavoritesChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _favNotifier.removeListener(_onFavoritesChanged);
    super.dispose();
  }

  void _onFavoritesChanged() {
    if (mounted) setState(() {});
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      // Trigger refresh with search query
      setState(() => _isLoading = true);
      _fetchDoctors();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    FocusScope.of(context).unfocus();
  }

  // --- DATA FETCHING ---
  Future<void> _fetchDoctors() async {
    final query = _searchController.text.trim();

    try {
      final doctors = await _doctorRepo.fetchAllDoctors(query: query);

      // Ensure favorites are loaded
      if (!_favNotifier.isLoaded) {
        await _favNotifier.loadFavorites();
      }

      if (mounted) {
        setState(() {
          _doctors = doctors;

          if (_selectedFilter == 'Nearest') {
            _doctors.shuffle(); // Mock logic for nearest
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching doctors: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- NAVIGATION ---
  Future<void> _navigateToDoctorDetails(int doctorId) async {
    await context.push(AppRoutes.doctorDetailsById('$doctorId'));
  }

  void _onFilterTap(String filter) {
    setState(() {
      _selectedFilter = filter;
      _isLoading = true;
    });
    _fetchDoctors();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppStyles.pageGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildSearchBar(),
              _buildFilterChips(),
              Expanded(
                child:
                    _isLoading
                        ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryGreen,
                          ),
                        )
                        : _buildDoctorList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Doctors", style: AppTextStyles.h1.copyWith(letterSpacing: 0.3)),
          Container(
            padding: const EdgeInsets.all(10),
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
            child: Icon(
              Icons.notifications_none_rounded,
              color: AppColors.textDark,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: CustomSearchBar(
        controller: _searchController,
        hintText: "Search doctor, specialty...",
        showClearIcon: _searchController.text.isNotEmpty,
        onClear: _clearSearch,
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(top: 24, bottom: 16),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilter == filter;

          return GestureDetector(
            onTap: () => _onFilterTap(filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryGreen : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border:
                    isSelected ? null : Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color:
                        isSelected
                            ? AppColors.primaryGreen.withValues(alpha: 0.3)
                            : Colors.black.withValues(alpha: 0.05),
                    blurRadius: isSelected ? 8 : 4,
                    offset:
                        isSelected ? const Offset(0, 4) : const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                filter,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textGrey,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDoctorList() {
    if (_doctors.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              "No doctors found",
              style: TextStyle(
                color: AppColors.textLight,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      itemCount: _doctors.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final doctor = _doctors[index];
        final docId = doctor['id'] as int;
        final specialtyName =
            doctor['specialties'] != null
                ? doctor['specialties']['name']
                : 'Specialist';
        final isFavorite = _favNotifier.isFavorite(docId);

        return DoctorListCard(
          id: docId,
          name: doctor['full_name'] ?? 'Unknown',
          specialty: specialtyName,
          rating: doctor['rating']?.toString() ?? '0.0',
          views: (doctor['patients_served'] ?? 0).toString(),
          imageUrl: doctor['profile_picture_url'],
          isFavorite: isFavorite,
          onFavoriteTap: () => _favNotifier.toggle(docId),
          onCardTap: () => _navigateToDoctorDetails(docId),
        );
      },
    );
  }
}
