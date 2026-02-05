import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; // Import go_router
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  String _userName = "Handwerker";
  String? _avatarUrl;

  // --- 1. DATA STREAMS ---
  late Future<List<Map<String, dynamic>>> _specialtiesFuture;
  late Future<List<Map<String, dynamic>>> _popularDoctorsFuture;
  late Future<List<Map<String, dynamic>>> _featureDoctorsFuture;

  // Store favorite IDs to check status
  Set<int> _favoriteDoctorIds = {};

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _initDataFetches();
    _fetchFavorites(); // <--- Fetch favorites on load
  }

  void _initDataFetches() {
    final client = Supabase.instance.client;

    // Fetch Specialties
    _specialtiesFuture = client.from('specialties').select().limit(10);

    // Fetch Popular Doctors
    _popularDoctorsFuture = client
        .from('doctors')
        .select('*, specialties(name)')
        .eq('is_popular', true)
        .limit(5);

    // Fetch Featured Doctors
    _featureDoctorsFuture = client
        .from('doctors')
        .select('*, specialties(name)')
        .eq('is_featured', true)
        .limit(5);
  }

  // --- FETCH FAVORITES (VISUAL ONLY) ---
  Future<void> _fetchFavorites() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await client
          .from('favorite_doctors')
          .select('doctor_id')
          .eq('user_id', userId);

      if (mounted) {
        setState(() {
          _favoriteDoctorIds =
              (response as List).map((e) => e['doctor_id'] as int).toSet();
        });
      }
    } catch (e) {
      debugPrint('Error fetching favorites: $e');
    }
  }

  Future<void> _loadUserData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final profile =
          await Supabase.instance.client
              .from('profiles')
              .select()
              .eq('id', user.id)
              .maybeSingle();

      if (mounted) {
        setState(() {
          _userName = profile?['full_name'] ?? "Handwerker";
          _avatarUrl = profile?['profile_picture_url'];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFFFBFBFB);

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
            SizedBox(
              height: 100,
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _specialtiesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text("No specialties found"));
                  }

                  final specialties = snapshot.data!;

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    scrollDirection: Axis.horizontal,
                    itemCount: specialties.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 24),
                    itemBuilder: (context, index) {
                      final item = specialties[index];
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
                                          (_, __, ___) =>
                                              _getFallbackIcon(name),
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
                  );
                },
              ),
            ),

            // --- POPULAR DOCTORS ---
            _buildSectionHeader(
              "Popular Doctor",
              onTap: () => context.push('/popular_doctors'),
            ),
            SizedBox(
              height: 240,
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _popularDoctorsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text("No popular doctors found"),
                    );
                  }

                  final doctors = snapshot.data!;

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    scrollDirection: Axis.horizontal,
                    itemCount: doctors.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      final doctor = doctors[index];
                      final specialtyName =
                          doctor['specialties'] != null
                              ? doctor['specialties']['name']
                              : 'Specialist';

                      return _buildPopularDoctorCard(
                        name: doctor['full_name'] ?? 'Unknown',
                        specialty: specialtyName,
                        rating: doctor['rating']?.toString() ?? '5.0',
                        imageUrl: doctor['profile_picture_url'],
                      );
                    },
                  );
                },
              ),
            ),

            // --- FEATURED DOCTORS ---
            _buildSectionHeader(
              "Feature Doctor",
              onTap: () => context.push('/feature_doctors'),
            ),
            SizedBox(
              height: 160,
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _featureDoctorsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text("No featured doctors found"),
                    );
                  }

                  final doctors = snapshot.data!;

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    scrollDirection: Axis.horizontal,
                    itemCount: doctors.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      final doctor = doctors[index];
                      // Check if this doctor is in the favorites list
                      final isFavorite = _favoriteDoctorIds.contains(
                        doctor['id'],
                      );

                      return _buildFeatureDoctorCard(
                        name: doctor['full_name'] ?? 'Unknown',
                        price: doctor['hourly_rate']?.toString() ?? '20',
                        rating: doctor['rating']?.toString() ?? '4.8',
                        imageUrl: doctor['profile_picture_url'],
                        isFavorite: isFavorite, // <--- Pass the state here
                      );
                    },
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
      case 'dental':
        iconData = Icons.masks_rounded;
        break;
      case 'cardiologist':
      case 'heart':
        iconData = Icons.favorite_rounded;
        break;
      case 'eye specialist':
      case 'eye':
        iconData = Icons.remove_red_eye_rounded;
        break;
      case 'pulmonologist':
      case 'lungs':
        iconData = Icons.air;
        break;
      default:
        iconData = Icons.medical_services_rounded;
    }
    return Icon(iconData, color: const Color(0xFF008FA0), size: 28);
  }

  // --- REUSABLE WIDGETS ---

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

  // --- POPULAR DOCTOR CARD ---
  Widget _buildPopularDoctorCard({
    required String name,
    required String specialty,
    required String rating,
    required String? imageUrl,
  }) {
    return Container(
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
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: double.infinity,
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.person,
                              color: Colors.grey,
                              size: 50,
                            ),
                          );
                        },
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      5,
                      (i) =>
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- FEATURED DOCTOR CARD ---
  Widget _buildFeatureDoctorCard({
    required String name,
    required String price,
    required String rating,
    required String? imageUrl,
    required bool isFavorite, // <--- New Parameter
  }) {
    return Container(
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
          // Favorite Icon (Visual Only) & Rating
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Visual State: Red if favorite, Grey border if not
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

          // Circle Image with Fallback
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
                      : const Icon(Icons.person, color: Colors.grey, size: 30),
            ),
          ),

          const SizedBox(height: 8),

          // Name
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 4),

          // Price
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
    );
  }
}
