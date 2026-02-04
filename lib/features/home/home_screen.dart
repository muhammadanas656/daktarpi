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
  int _currentNavIndex = 0;
  String _userName = "Handwerker";
  String? _avatarUrl;

  // --- 1. DATA STREAMS ---
  late Future<List<Map<String, dynamic>>> _specialtiesFuture;
  late Future<List<Map<String, dynamic>>> _popularDoctorsFuture;
  late Future<List<Map<String, dynamic>>> _featureDoctorsFuture;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _initDataFetches();
  }

  void _initDataFetches() {
    final client = Supabase.instance.client;

    // Fetch Specialties
    _specialtiesFuture = client.from('specialties').select().limit(10);

    // Fetch Popular Doctors (is_popular = true)
    _popularDoctorsFuture = client
        .from('doctors')
        .select('*, specialties(name)') // Join to get specialty name
        .eq('is_popular', true)
        .limit(5);

    // Fetch Featured Doctors (is_featured = true)
    _featureDoctorsFuture = client
        .from('doctors')
        .select('*, specialties(name)')
        .eq('is_featured', true)
        .limit(5);
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
    const primaryGreen = Color(0xFF00C689);
    const bgColor = Color(0xFFFBFBFB);

    return Scaffold(
      backgroundColor: bgColor,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentNavIndex,
        onTap: (index) {
          setState(() => _currentNavIndex = index);
          if (index == 3) context.go('/profile');
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: primaryGreen,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Home"),
          BottomNavigationBarItem(
            icon: Icon(Icons.monitor_heart_outlined),
            label: "Doctors",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            label: "Appointment",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: "Profile",
          ),
        ],
      ),
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

            // --- SPECIALTIES LIST (Connected to DB) ---
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
                  if (snapshot.hasError) {
                    return const Center(child: Text("Error loading data"));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text("No specialties found"));
                  }

                  final specialties = snapshot.data!;

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    scrollDirection: Axis.horizontal,
                    itemCount: specialties.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 20),
                    itemBuilder: (context, index) {
                      final item = specialties[index];
                      // Note: Assuming you might store icon_url in DB later.
                      // For now, using a static icon for all.
                      return Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE0F7FA),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.medical_services_outlined,
                              color: Color(0xFF008FA0),
                              size: 28,
                            ),
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
                      );
                    },
                  );
                },
              ),
            ),

            // --- POPULAR DOCTORS (Connected to DB) ---
            _buildSectionHeader("Popular Doctor"),
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
                      // Safely access nested specialty name
                      final specialtyName =
                          doctor['specialties'] != null
                              ? doctor['specialties']['name']
                              : 'Specialist';

                      return _buildPopularDoctorCard(
                        name: doctor['full_name'] ?? 'Unknown',
                        specialty: specialtyName,
                        rating: doctor['rating']?.toString() ?? '5.0',
                        imageUrl:
                            doctor['profile_picture_url'] ??
                            'https://i.pravatar.cc/150?img=${index + 50}',
                      );
                    },
                  );
                },
              ),
            ),

            // --- FEATURED DOCTORS (Connected to DB) ---
            _buildSectionHeader("Feature Doctor"),
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
                      return _buildFeatureDoctorCard(
                        name: doctor['full_name'] ?? 'Unknown',
                        price: doctor['hourly_rate']?.toString() ?? '20',
                        rating: doctor['rating']?.toString() ?? '4.8',
                        imageUrl:
                            doctor['profile_picture_url'] ??
                            'https://i.pravatar.cc/150?img=${index + 10}',
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

  // --- REUSABLE WIDGETS ---

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Text(
            "See all >",
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularDoctorCard({
    required String name,
    required String specialty,
    required String rating,
    required String imageUrl,
  }) {
    return Container(
      width: 160,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(radius: 40, backgroundImage: NetworkImage(imageUrl)),
          const SizedBox(height: 10),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          Text(
            specialty,
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (i) => const Icon(Icons.star, color: Colors.amber, size: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureDoctorCard({
    required String name,
    required String price,
    required String rating,
    required String imageUrl,
  }) {
    return Container(
      width: 130,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
              const Icon(Icons.favorite_border, color: Colors.grey, size: 16),
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
          CircleAvatar(radius: 25, backgroundImage: NetworkImage(imageUrl)),
          const SizedBox(height: 8),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            "\$ $price/hour",
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
