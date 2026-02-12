import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Import the Doctors Screen to access the global signal
import '../../features/doctors/doctors_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  final Color primaryGreen = const Color(0xFF00C689);

  // --- STATE VARIABLES ---
  bool _isLoading = true;
  String _userName = "Handwerker";
  String? _avatarUrl;

  // Data Lists
  List<Map<String, dynamic>> _specialties = [];
  List<Map<String, dynamic>> _popularDoctors = [];
  List<Map<String, dynamic>> _featuredDoctors = [];
  Set<int> _favoriteDoctorIds = {};

  @override
  void initState() {
    super.initState();
    _fetchAllData();

    // --- LISTENER FOR FAVORITES UPDATE ---
    // This listens to the signal sent from DoctorsScreen
    favoriteUpdateSignal.addListener(() {
      if (mounted) {
        _refreshData();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    favoriteUpdateSignal.removeListener(
      () {},
    ); // Cleanup listener (best practice)
    super.dispose();
  }

  // --- DATA LOADING ---
  Future<void> _refreshData() async {
    if (!mounted) return;
    // Silent refresh if desired, or show loading.
    // Showing loading briefly ensures user knows data updated.
    // setState(() => _isLoading = true);
    // await Future.delayed(const Duration(milliseconds: 50));
    await _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;

    try {
      final results = await Future.wait([
        (userId != null
            ? client.from('profiles').select().eq('id', userId).maybeSingle()
            : Future.value(null)),
        (userId != null
            ? client
                .from('favorite_doctors')
                .select('doctor_id')
                .eq('user_id', userId)
            : Future.value([])),
        client.from('specialties').select().limit(10),
        client
            .from('doctors')
            .select('*, specialties(name)')
            .eq('is_popular', true)
            .limit(5),
        client
            .from('doctors')
            .select('*, specialties(name)')
            .eq('is_featured', true)
            .limit(5),
      ]);

      if (mounted) {
        setState(() {
          final profileData = results[0] as Map<String, dynamic>?;
          if (profileData != null) {
            _userName = profileData['full_name'] ?? "Handwerker";
            _avatarUrl = profileData['profile_picture_url'];
          }

          // Parse Favorites
          _favoriteDoctorIds =
              (results[1] as List).map((e) => e['doctor_id'] as int).toSet();

          _specialties = List<Map<String, dynamic>>.from(results[2] as List);
          _popularDoctors = List<Map<String, dynamic>>.from(results[3] as List);
          _featuredDoctors = List<Map<String, dynamic>>.from(
            results[4] as List,
          );
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

  // --- NAVIGATION LOGIC ---
  Future<void> _navigateToDoctorDetails(int doctorId) async {
    await context.push('/doctor_details/$doctorId');
    _refreshData();
  }

  Future<void> _navigateToSpecialty(
    int specialtyId,
    String specialtyName,
  ) async {
    await context.push(
      '/specialty_doctors/$specialtyId',
      extra: {'name': specialtyName},
    );
    _refreshData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFFBFBFB),
        body: Center(child: CircularProgressIndicator(color: primaryGreen)),
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
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF00C689), Color(0xFF00A975)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
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
                    "Hi $_userName!",
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    "Find Your Doctor",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white24,
                backgroundImage:
                    _avatarUrl != null
                        ? NetworkImage(_avatarUrl!)
                        : const NetworkImage('https://i.pravatar.cc/300'),
              ),
            ],
          ),
          const SizedBox(height: 25),
          Container(
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
              readOnly: true,
              onTap: () async {
                await context.push('/popular_doctors');
                _refreshData();
              },
              decoration: const InputDecoration(
                hintText: "Search.....",
                hintStyle: TextStyle(color: Colors.grey),
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                suffixIcon: Icon(Icons.close, color: Colors.grey, size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 15),
              ),
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
          color: const Color(0xFF008FA0),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            const Positioned(
              left: 20,
              top: 30,
              child: SizedBox(
                width: 180,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Medical Center",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Yorem ipsum dolor sit amet, consectetur adipiscing elit.",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
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
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            "Specialities most relevant to you",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                        decoration: const BoxDecoration(
                          color: Color(0xFFE0F7FA),
                          shape: BoxShape.circle,
                        ),
                        child:
                            item['icon_url'] != null
                                ? Image.network(item['icon_url'])
                                : _getFallbackIcon(item['name'] ?? ''),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item['name'] ?? '',
                        style: const TextStyle(
                          fontSize: 12,
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
            await context.push('/popular_doctors');
            _refreshData();
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
                return _buildPopularDoctorCard(
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
            await context.push('/feature_doctors');
            _refreshData();
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
                return _buildFeatureDoctorCard(
                  id: doc['id'],
                  name: doc['full_name'] ?? 'Unknown',
                  price: doc['hourly_rate']?.toString() ?? '20',
                  rating: doc['rating']?.toString() ?? '4.8',
                  imageUrl: doc['profile_picture_url'],
                  isFavorite: _favoriteDoctorIds.contains(doc['id']),
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
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          InkWell(
            onTap: onTap,
            child: const Text(
              "See all >",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularDoctorCard({
    required int id,
    required String name,
    required String specialty,
    required String rating,
    String? imageUrl,
  }) {
    return GestureDetector(
      onTap: () => _navigateToDoctorDetails(id),
      child: Container(
        width: 170,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child:
                    imageUrl != null
                        ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        )
                        : Container(
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.person,
                            size: 50,
                            color: Colors.grey,
                          ),
                        ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      specialty,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 14),
                        Text(" $rating", style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureDoctorCard({
    required int id,
    required String name,
    required String price,
    required String rating,
    String? imageUrl,
    bool isFavorite = false,
  }) {
    return GestureDetector(
      onTap: () => _navigateToDoctorDetails(id),
      child: Container(
        width: 130,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.red : Colors.grey,
                  size: 16,
                ),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 12),
                    Text(
                      rating,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[200],
              ),
              child: ClipOval(
                child:
                    imageUrl != null
                        ? Image.network(imageUrl, fit: BoxFit.cover)
                        : const Icon(Icons.person, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Text(
              "\$ $price/hour",
              style: TextStyle(
                color: primaryGreen,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
