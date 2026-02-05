import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PopularDoctorsScreen extends StatefulWidget {
  const PopularDoctorsScreen({super.key});

  @override
  State<PopularDoctorsScreen> createState() => _PopularDoctorsScreenState();
}

class _PopularDoctorsScreenState extends State<PopularDoctorsScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  // Data State
  List<Map<String, dynamic>> _doctors = [];
  Set<int> _favoriteDoctorIds = {};
  bool _isLoading = true;
  bool _showClearIcon = false; // Controls visibility of the 'X' icon

  @override
  void initState() {
    super.initState();
    _fetchData();

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
    super.dispose();
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
    FocusScope.of(context).unfocus(); // Dismiss keyboard
    // _onSearchChanged will trigger automatically
  }

  Future<void> _fetchData({String? query}) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;

    try {
      // 1. Build Query
      var dbQuery = client
          .from('doctors')
          .select('*, specialties(name)')
          .eq('is_popular', true); // Base filter

      // 2. Apply Search
      if (query != null && query.isNotEmpty) {
        dbQuery = dbQuery.ilike('full_name', '%$query%');
      }

      // 3. Execute
      final doctorsData = await dbQuery.order('rating', ascending: false);

      // 4. Fetch Favorites (only if user logged in)
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

  // --- TOGGLE FAVORITE ---
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
          "Popular Doctors",
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
                  // --- CLEAR BUTTON ---
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
                    ? const Center(child: Text("No popular doctors found"))
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
                        final reviews =
                            doctor['reviews_count']?.toString() ?? '0';

                        final isFavorite = _favoriteDoctorIds.contains(docId);

                        return _buildDoctorListCard(
                          id: docId,
                          name: doctor['full_name'] ?? 'Unknown',
                          specialty: "Specialist $specialtyName",
                          rating: doctor['rating']?.toString() ?? '0.0',
                          views: reviews,
                          imageUrl: doctor['profile_picture_url'],
                          isFavorite: isFavorite,
                          onFavoriteTap: () => _toggleFavorite(docId),
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
    required String views,
    required String? imageUrl,
    required bool isFavorite,
    required VoidCallback onFavoriteTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- IMAGE ---
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

          // --- INFO COLUMN ---
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
                        padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
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
                    ...List.generate(5, (index) {
                      return const Icon(
                        Icons.star,
                        color: Colors.amber,
                        size: 14,
                      );
                    }),
                    const SizedBox(width: 8),
                    Flexible(
                      child: RichText(
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: rating,
                              style: const TextStyle(
                                color: Color(0xFF1A1A1A),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            TextSpan(
                              text: "  ($views views)",
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
