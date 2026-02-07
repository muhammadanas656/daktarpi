import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FeatureDoctorsScreen extends StatefulWidget {
  const FeatureDoctorsScreen({super.key});

  @override
  State<FeatureDoctorsScreen> createState() => _FeatureDoctorsScreenState();
}

class _FeatureDoctorsScreenState extends State<FeatureDoctorsScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  // Data State
  List<Map<String, dynamic>> _doctors = [];
  Set<int> _favoriteDoctorIds = {};
  bool _isLoading = true;
  bool _showClearIcon = false;

  @override
  void initState() {
    super.initState();
    _fetchData();

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
    super.dispose();
  }

  // --- SEARCH LISTENER ---
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

  Future<void> _fetchData({String? query}) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;

    try {
      var dbQuery = client
          .from('doctors')
          .select('*, specialties(name)')
          .eq('is_featured', true);

      if (query != null && query.isNotEmpty) {
        dbQuery = dbQuery.ilike('full_name', '%$query%');
      }

      final doctorsData = await dbQuery.order('rating', ascending: false);

      if (userId != null) {
        final favoritesData = await client
            .from('favorite_doctors')
            .select('doctor_id')
            .eq('user_id', userId);

        final favIds = favoritesData.map((e) => e['doctor_id'] as int).toSet();

        if (mounted) {
          setState(() {
            _favoriteDoctorIds = favIds;
          });
        }
      }

      if (mounted) {
        setState(() {
          _doctors = List<Map<String, dynamic>>.from(doctorsData);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFavorite(int doctorId) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final isCurrentlyFavorite = _favoriteDoctorIds.contains(doctorId);

    setState(() {
      if (isCurrentlyFavorite) {
        _favoriteDoctorIds.remove(doctorId);
      } else {
        _favoriteDoctorIds.add(doctorId);
      }
    });

    try {
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
    } catch (e) {
      debugPrint("Error toggling favorite: $e");
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

  // --- NAVIGATION LOGIC ---
  Future<void> _navigateToDoctorDetails(int doctorId) async {
    // 1. Wait for user to return
    await context.push('/doctor_details/$doctorId');
    // 2. Refresh list on return
    if (mounted) {
      _fetchData(query: _searchController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFFFBFBFB);
    const primaryGreen = Color(0xFF00C689);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          "Featured Doctors",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: Column(
        children: [
          // --- SEARCH BAR ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    // FIX: Replaced withOpacity with withValues
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Search",
                  hintStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon:
                      _showClearIcon
                          ? IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.grey,
                              size: 20,
                            ),
                            onPressed: _clearSearch,
                          )
                          : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),

          // --- DOCTOR LIST ---
          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: CircularProgressIndicator(color: primaryGreen),
                    )
                    : _doctors.isEmpty
                    ? const Center(child: Text("No featured doctors found"))
                    : ListView.separated(
                      padding: const EdgeInsets.all(24),
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

                        final isFavorite = _favoriteDoctorIds.contains(docId);

                        return _buildDoctorListCard(
                          id: docId,
                          name: doctor['full_name'] ?? 'Unknown',
                          specialty: " $specialtyName",
                          rating: doctor['rating']?.toString() ?? '0.0',
                          price: doctor['hourly_rate']?.toString() ?? '20',
                          imageUrl: doctor['profile_picture_url'],
                          isFavorite: isFavorite,
                          onFavoriteTap: () => _toggleFavorite(docId),
                          onCardTap:
                              () => _navigateToDoctorDetails(
                                docId,
                              ), // Add Navigation Tap
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorListCard({
    required int id,
    required String name,
    required String specialty,
    required String rating,
    required String price,
    required String? imageUrl,
    required bool isFavorite,
    required VoidCallback onFavoriteTap,
    required VoidCallback onCardTap, // New Parameter
  }) {
    return GestureDetector(
      onTap: onCardTap, // Handle Card Tap
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              // FIX: Replaced withOpacity with withValues
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 80,
                height: 80,
                child:
                    (imageUrl != null && imageUrl.isNotEmpty)
                        ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (context, error, stackTrace) => Container(
                                color: Colors.grey[200],
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.grey,
                                  size: 40,
                                ),
                              ),
                        )
                        : Container(
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.person,
                            color: Colors.grey,
                            size: 40,
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
                            color: Color(0xFF1A1A1A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: onFavoriteTap,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 8.0,
                            bottom: 4.0,
                          ),
                          child: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? Colors.red : Colors.grey,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    specialty,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        rating,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      RichText(
                        text: TextSpan(
                          children: [
                            const TextSpan(
                              text: "\$ ",
                              style: TextStyle(
                                color: Color(0xFF00C689),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            TextSpan(
                              text: "$price/hour",
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
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
