import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  final Color primaryGreen = const Color(0xFF00C689);

  // --- STATE VARIABLES ---
  bool _isLoading = true; // Global loading state
  String _userName = "Handwerker";
  String? _avatarUrl;

  // Data Lists (Replaces Futures)
  List<Map<String, dynamic>> _specialties = [];
  List<Map<String, dynamic>> _popularDoctors = [];
  List<Map<String, dynamic>> _featuredDoctors = [];
  Set<int> _favoriteDoctorIds = {};

  @override
  void initState() {
    super.initState();
    _fetchAllData();
  }

  // --- FETCH ALL DATA (PARALLEL) ---
  Future<void> _fetchAllData() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;

    try {
      // 1. Prepare Futures
      final Future<dynamic> profileFuture =
          userId != null
              ? client.from('profiles').select().eq('id', userId).maybeSingle()
              : Future.value(null);

      final Future<dynamic> favoritesFuture =
          userId != null
              ? client
                  .from('favorite_doctors')
                  .select('doctor_id')
                  .eq('user_id', userId)
              : Future.value([]);

      final Future<dynamic> specialtiesFuture = client
          .from('specialties')
          .select()
          .limit(10);

      final Future<dynamic> popularDocsFuture = client
          .from('doctors')
          .select('*, specialties(name)')
          .eq('is_popular', true)
          .limit(5);

      final Future<dynamic> featuredDocsFuture = client
          .from('doctors')
          .select('*, specialties(name)')
          .eq('is_featured', true)
          .limit(5);

      // 2. Wait for completion
      final results = await Future.wait([
        profileFuture,
        favoritesFuture,
        specialtiesFuture,
        popularDocsFuture,
        featuredDocsFuture,
      ]);

      // 3. Extract & Cast Data
      final profileData = results[0] as Map<String, dynamic>?;
      final favoritesData = results[1] as List<dynamic>;
      final specialtiesData = List<Map<String, dynamic>>.from(
        results[2] as List,
      );
      final popularData = List<Map<String, dynamic>>.from(results[3] as List);
      final featuredData = List<Map<String, dynamic>>.from(results[4] as List);

      if (mounted) {
        setState(() {
          // Profile
          if (profileData != null) {
            _userName = profileData['full_name'] ?? "Handwerker";
            _avatarUrl = profileData['profile_picture_url'];
          }

          // Favorites Set
          _favoriteDoctorIds =
              favoritesData.map((e) => e['doctor_id'] as int).toSet();

          // Content Lists
          _specialties = specialtiesData;
          _popularDoctors = popularData;
          _featuredDoctors = featuredData;

          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading home data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- NAVIGATION HELPER (With Refresh Logic) ---
  Future<void> _navigateToDoctorDetails(
    BuildContext context,
    int doctorId,
  ) async {
    // 1. Wait for the user to return from the details screen
    await context.push('/doctor_details/$doctorId');

    // 2. Once they return, refresh the data to update hearts/ratings
    if (mounted) {
      _fetchAllData();
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFFFBFBFB);

    // 1. Global Loading State
    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(child: CircularProgressIndicator(color: primaryGreen)),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER ---
            Container(
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
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
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
                                : const NetworkImage(
                                  'https://i.pravatar.cc/300',
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  // Search Bar
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
                        if (mounted) _fetchAllData(); // Refresh on return
                      },
                      decoration: const InputDecoration(
                        hintText: "Search.....",
                        hintStyle: TextStyle(color: Colors.grey),
                        prefixIcon: Icon(Icons.search, color: Colors.grey),
                        suffixIcon: Icon(
                          Icons.close,
                          color: Colors.grey,
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // --- BANNER ---
            Padding(
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
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
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
            ),

            // --- SPECIALTIES LIST ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: const Text(
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
                    final name = item['name'] ?? 'Unknown';
                    final iconUrl = item['icon_url'];

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
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
                              iconUrl != null
                                  ? Image.network(
                                    iconUrl,
                                    fit: BoxFit.contain,
                                    errorBuilder:
                                        (_, __, ___) => _getFallbackIcon(name),
                                  )
                                  : _getFallbackIcon(name),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

            // --- POPULAR DOCTORS ---
            _buildSectionHeader(
              "Popular Doctor",
              onTap: () async {
                await context.push('/popular_doctors');
                if (mounted) _fetchAllData(); // Refresh on return
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
                    final doctor = _popularDoctors[index];
                    final specialtyName =
                        doctor['specialties'] != null
                            ? doctor['specialties']['name']
                            : 'Specialist';

                    return _buildPopularDoctorCard(
                      context: context,
                      id: doctor['id'] as int,
                      name: doctor['full_name'] ?? 'Unknown',
                      specialty: specialtyName,
                      rating: doctor['rating']?.toString() ?? '0.0',
                      imageUrl: doctor['profile_picture_url'],
                    );
                  },
                ),
              ),

            // --- FEATURED DOCTORS ---
            _buildSectionHeader(
              "Feature Doctor",
              onTap: () async {
                await context.push('/feature_doctors');
                if (mounted) _fetchAllData(); // Refresh on return
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
                    final doctor = _featuredDoctors[index];
                    final isFavorite = _favoriteDoctorIds.contains(
                      doctor['id'],
                    );

                    return _buildFeatureDoctorCard(
                      context: context,
                      id: doctor['id'] as int,
                      name: doctor['full_name'] ?? 'Unknown',
                      price: doctor['hourly_rate']?.toString() ?? '20',
                      rating: doctor['rating']?.toString() ?? '4.8',
                      imageUrl: doctor['profile_picture_url'],
                      isFavorite: isFavorite,
                    );
                  },
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- HELPER: FALLBACK ICONS ---
  Widget _getFallbackIcon(String name) {
    IconData iconData;
    switch (name.toLowerCase()) {
      case 'dentist':
        iconData = Icons.masks_rounded;
        break;
      case 'cardiologist':
        iconData = Icons.favorite_rounded;
        break;
      case 'eye surgeon':
      case 'eye specialist':
        iconData = Icons.remove_red_eye_rounded;
        break;
      default:
        iconData = Icons.medical_services_rounded;
    }
    return Icon(iconData, color: const Color(0xFF008FA0), size: 28);
  }

  // --- REUSABLE HEADER ---
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

  // --- POPULAR DOCTOR CARD (Updated Stars & Navigation) ---
  Widget _buildPopularDoctorCard({
    required BuildContext context,
    required int id,
    required String name,
    required String specialty,
    required String rating,
    required String? imageUrl,
  }) {
    final double ratingVal = double.tryParse(rating) ?? 0.0;
    final int fullStars = ratingVal.floor();
    final bool hasHalfStar = (ratingVal - fullStars) >= 0.5;

    return GestureDetector(
      onTap: () => _navigateToDoctorDetails(context, id),
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
            // Image Section
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child:
                    (imageUrl != null && imageUrl.isNotEmpty)
                        ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder:
                              (context, error, stackTrace) => Container(
                                width: double.infinity,
                                color: Colors.grey[200],
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.grey,
                                  size: 50,
                                ),
                              ),
                        )
                        : Container(
                          width: double.infinity,
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.person,
                            color: Colors.grey,
                            size: 50,
                          ),
                        ),
              ),
            ),
            // Info Section
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      specialty,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                    const SizedBox(height: 8),
                    // STARS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        if (index < fullStars) {
                          return const Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: 14,
                          );
                        } else if (index == fullStars && hasHalfStar) {
                          return const Icon(
                            Icons.star_half,
                            color: Colors.amber,
                            size: 14,
                          );
                        } else {
                          return Icon(
                            Icons.star_border,
                            color: Colors.grey[300],
                            size: 14,
                          );
                        }
                      }),
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

  // --- FEATURED DOCTOR CARD (Navigation & Visual Favorite) ---
  Widget _buildFeatureDoctorCard({
    required BuildContext context,
    required int id,
    required String name,
    required String price,
    required String rating,
    required String? imageUrl,
    bool isFavorite = false,
  }) {
    return GestureDetector(
      onTap: () => _navigateToDoctorDetails(context, id),
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
                    const SizedBox(width: 4),
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
                    (imageUrl != null && imageUrl.isNotEmpty)
                        ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          width: 50,
                          height: 50,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.person,
                              color: Colors.grey,
                              size: 30,
                            );
                          },
                        )
                        : const Icon(
                          Icons.person,
                          color: Colors.grey,
                          size: 30,
                        ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              "\$ $price/hour",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF00C689),
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
