import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/doctor_repository.dart';
import '../../presentation/favorites_notifier.dart';
import '../../../../presentation/widgets/doctor_list_card.dart';
import '../../../../presentation/widgets/custom_search_bar.dart';

class ClinicDoctorsScreen extends StatefulWidget {
  final int clinicId;
  final String clinicName;

  const ClinicDoctorsScreen({
    super.key,
    required this.clinicId,
    required this.clinicName,
  });

  @override
  State<ClinicDoctorsScreen> createState() => _ClinicDoctorsScreenState();
}

class _ClinicDoctorsScreenState extends State<ClinicDoctorsScreen> {
  final _doctorRepo = DoctorRepository();
  final _favNotifier = FavoritesNotifier.instance;
  final TextEditingController _searchController = TextEditingController();

  late Future<List<Map<String, dynamic>>> _doctorsFuture;
  Timer? _debounce;

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
      _fetchDoctors();
    });
  }

  void _fetchDoctors() {
    setState(() {
      _doctorsFuture = _doctorRepo.fetchDoctorsByClinic(
        widget.clinicId,
        query: _searchController.text.trim(),
      );
    });
  }

  void _navigateToDoctorDetails(int doctorId) {
    context.push(AppRoutes.doctorDetailsById('$doctorId'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text("Doctors", style: AppTextStyles.h2),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: AppColors.textDark,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: CustomSearchBar(
              controller: _searchController,
              hintText: "Search doctors...",
              showClearIcon: true,
              onClear: () {
                _searchController.clear();
                // Trigger search update
                _fetchDoctors();
                FocusScope.of(context).unfocus();
              },
            ),
          ),

          // 2. Clinic Name Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Text(
              widget.clinicName,
              style: AppTextStyles.h2.copyWith(
                fontSize: 20,
              ), // Slightly larger/bold
            ),
          ),

          // 3. Doctor List
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _doctorsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryGreen,
                    ),
                  );
                } else if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.dangerRed,
                      ),
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Text(
                      'No doctors found.',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textGrey,
                      ),
                    ),
                  );
                }

                final doctors = snapshot.data!;

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                  itemCount: doctors.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final doctor = doctors[index];
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
                      rating: (doctor['rating'] as num?)?.toString() ?? '0.0',
                      views: (doctor['views_count'] ?? 0).toString(),
                      imageUrl: doctor['profile_picture_url'],
                      isFavorite: isFavorite,
                      onFavoriteTap: () => _favNotifier.toggle(docId),
                      onCardTap: () => _navigateToDoctorDetails(docId),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
