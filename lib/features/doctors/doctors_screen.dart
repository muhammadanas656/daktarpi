import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- GLOBAL SIGNAL ---
// The HomeScreen will listen to this. When it changes, HomeScreen refreshes.
final ValueNotifier<bool> favoriteUpdateSignal = ValueNotifier(false);

class DoctorsScreen extends StatefulWidget {
  const DoctorsScreen({super.key});

  @override
  State<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends State<DoctorsScreen> {
  // --- DESIGN COLORS ---
  static const Color primaryGreen = Color(0xFF00C689);
  static const Color textDark = Color(0xFF1A1A1A);
  static const Color textLight = Color(0xFF626F8D);
  static const Color textGrey = Color(0xFF9E9E9E);
  static const Color borderColor = Color(0xFFE0E0E0);

  // --- STATE ---
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _doctors = [];
  Set<int> _favoriteDoctorIds = {};
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
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
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
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    final query = _searchController.text.trim();

    try {
      // 1. Build Doctor Query
      var dbQuery = client.from('doctors').select('*, specialties(name)');

      // Apply Search
      if (query.isNotEmpty) {
        dbQuery = dbQuery.ilike('full_name', '%$query%');
      }

      // Apply Sorting
      final response = await dbQuery.order('rating', ascending: false);

      // 2. Fetch Favorites
      if (userId != null) {
        final favResponse = await client
            .from('favorite_doctors')
            .select('doctor_id')
            .eq('user_id', userId);

        final favIds =
            List<Map<String, dynamic>>.from(
              favResponse,
            ).map((e) => e['doctor_id'] as int).toSet();

        if (mounted) {
          setState(() => _favoriteDoctorIds = favIds);
        }
      }

      if (mounted) {
        setState(() {
          _doctors = List<Map<String, dynamic>>.from(response);

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

  // --- TOGGLE FAVORITE & SEND SIGNAL ---
  Future<void> _toggleFavorite(int doctorId) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final isCurrentlyFavorite = _favoriteDoctorIds.contains(doctorId);

    // 1. Optimistic UI Update
    setState(() {
      if (isCurrentlyFavorite) {
        _favoriteDoctorIds.remove(doctorId);
      } else {
        _favoriteDoctorIds.add(doctorId);
      }
    });

    try {
      // 2. Database Sync
      if (isCurrentlyFavorite) {
        await client.from('favorite_doctors').delete().match({
          'user_id': userId,
          'doctor_id': doctorId,
        });
      } else {
        await client.from('favorite_doctors').insert({
          'user_id': userId,
          'doctor_id': doctorId,
        });
      }

      // 3. SEND SIGNAL TO HOME SCREEN
      // Flipping this boolean triggers the listener in HomeScreen
      favoriteUpdateSignal.value = !favoriteUpdateSignal.value;
    } catch (e) {
      debugPrint("Error toggling favorite: $e");
      // Revert if error
      if (mounted) {
        setState(() {
          if (isCurrentlyFavorite) {
            _favoriteDoctorIds.add(doctorId);
          } else {
            _favoriteDoctorIds.remove(doctorId);
          }
        });
      }
    }
  }

  // --- NAVIGATION (Fixed Path Parameter) ---
  Future<void> _navigateToDoctorDetails(int doctorId) async {
    // Navigate using ID in path
    await context.push('/doctor_details/$doctorId');

    // Refresh list on return (to sync favorites changed in details screen)
    if (mounted) {
      _fetchDoctors();
    }
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE0F7FA),
              Colors.white,
              Colors.white,
              Color(0xFFE8F5E9),
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
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
                          child: CircularProgressIndicator(color: primaryGreen),
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
          const Text(
            "Doctors",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: textDark,
              letterSpacing: 0.5,
            ),
          ),
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
            child: const Icon(
              Icons.notifications_none_rounded,
              color: textDark,
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
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(color: textDark, fontSize: 16),
          decoration: InputDecoration(
            hintText: "Search doctor, specialty...",
            hintStyle: TextStyle(
              color: textLight.withValues(alpha: 0.6),
              fontSize: 14,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: textLight,
              size: 24,
            ),
            suffixIcon:
                _searchController.text.isNotEmpty
                    ? IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: textLight,
                        size: 20,
                      ),
                      onPressed: _clearSearch,
                    )
                    : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
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
                color: isSelected ? primaryGreen : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border:
                    isSelected ? null : Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color:
                        isSelected
                            ? primaryGreen.withValues(alpha: 0.3)
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
                  color: isSelected ? Colors.white : textGrey,
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
                color: textLight,
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
        final isFavorite = _favoriteDoctorIds.contains(docId);

        return _buildDoctorCard(
          id: docId,
          name: doctor['full_name'] ?? 'Unknown',
          specialty: specialtyName,
          rating: doctor['rating']?.toString() ?? '0.0',
          price: doctor['hourly_rate']?.toString() ?? '20',
          imageUrl: doctor['profile_picture_url'],
          views: (doctor['patients_served'] ?? 0).toString(),
          isFavorite: isFavorite,
          onFavoriteTap: () => _toggleFavorite(docId),
          onCardTap: () => _navigateToDoctorDetails(docId),
        );
      },
    );
  }

  Widget _buildDoctorCard({
    required int id,
    required String name,
    required String specialty,
    required String rating,
    required String price,
    required String? imageUrl,
    required String views,
    required bool isFavorite,
    required VoidCallback onFavoriteTap,
    required VoidCallback onCardTap,
  }) {
    return GestureDetector(
      onTap: onCardTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'doc_img_list_$id',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  imageUrl ?? 'https://i.pravatar.cc/150?u=$id',
                  width: 85,
                  height: 85,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (_, __, ___) => Container(
                        width: 85,
                        height: 85,
                        color: Colors.grey[100],
                        child: const Icon(Icons.person, color: textGrey),
                      ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textDark,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: onFavoriteTap,
                        child: Icon(
                          isFavorite
                              ? Icons.favorite
                              : Icons.favorite_border_rounded,
                          color: isFavorite ? Colors.red : textGrey,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    specialty,
                    style: const TextStyle(
                      color: textLight,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ...List.generate(5, (index) {
                        double r = double.tryParse(rating) ?? 0.0;
                        if (index < r.floor()) {
                          return const Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                            size: 14,
                          );
                        } else if (index == r.floor() && (r - index) >= 0.5) {
                          return const Icon(
                            Icons.star_half_rounded,
                            color: Colors.amber,
                            size: 14,
                          );
                        }
                        return Icon(
                          Icons.star_border_rounded,
                          color: Colors.grey[300],
                          size: 14,
                        );
                      }),
                      const SizedBox(width: 8),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: "$rating ",
                              style: const TextStyle(
                                color: textDark,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            TextSpan(
                              text: "($views views)",
                              style: const TextStyle(
                                color: textGrey,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
