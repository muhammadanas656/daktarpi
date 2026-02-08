import 'dart:async';
import 'dart:math' as math;
import 'dart:ui'; // For image filtering if needed
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // --- CONTROLLERS & CONFIG ---
  final _searchController = TextEditingController();
  late AnimationController _drawerController;
  final Color primaryGreen = const Color(0xFF00C689);
  final double _maxDrawerWidth = 300.0;

  // --- STATE VARIABLES ---
  bool _canBeDragged = false;
  bool _isLoading = true;
  bool _showTutorial = false;
  String _userName = "Handwerker";
  String? _avatarUrl;

  // --- DATA LISTS ---
  List<Map<String, dynamic>> _specialties = [];
  List<Map<String, dynamic>> _popularDoctors = [];
  List<Map<String, dynamic>> _featuredDoctors = [];
  Set<int> _favoriteDoctorIds = {};

  @override
  void initState() {
    super.initState();
    // Initialize the Animation Controller for the custom drawer
    _drawerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fetchAllData();
  }

  @override
  void dispose() {
    _drawerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // 1. CUSTOM DRAWER LOGIC (The "Engine")
  // ---------------------------------------------------------------------------

  void _onDragStart(DragStartDetails details) {
    if (_showTutorial)
      _dismissTutorial(); // Auto-dismiss tutorial on interaction

    // Allow dragging if:
    // 1. Drawer is already open (to close it)
    // 2. OR touch starts within the left 70% of the screen (Mid-screen swipe support)
    bool isDrawerOpen = _drawerController.value > 0;
    bool isDragFromLeft =
        details.localPosition.dx < MediaQuery.of(context).size.width * 0.7;

    _canBeDragged = isDrawerOpen || isDragFromLeft;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_canBeDragged) {
      // Convert pixel movement to animation value (0.0 to 1.0)
      double delta = details.primaryDelta! / _maxDrawerWidth;
      _drawerController.value += delta;
    }
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_canBeDragged) return;
    if (_drawerController.isDismissed || _drawerController.isCompleted) return;

    // Physics: If swipe is fast (>365 velocity), snap in that direction.
    // Otherwise, snap to the nearest side (0 or 1) based on drag distance.
    if (details.velocity.pixelsPerSecond.dx.abs() >= 365.0) {
      double visualVelocity =
          details.velocity.pixelsPerSecond.dx / _maxDrawerWidth;
      _drawerController.fling(velocity: visualVelocity);
    } else {
      if (_drawerController.value < 0.5) {
        _drawerController.reverse(); // Snap Close
      } else {
        _drawerController.forward(); // Snap Open
      }
    }
  }

  void _toggleDrawer() {
    if (_drawerController.isDismissed) {
      _drawerController.forward();
    } else {
      _drawerController.reverse();
    }
  }

  void _dismissTutorial() {
    if (mounted) setState(() => _showTutorial = false);
  }

  // ---------------------------------------------------------------------------
  // 2. DATA FETCHING
  // ---------------------------------------------------------------------------

  Future<void> _refreshData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 50));
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
          _favoriteDoctorIds =
              (results[1] as List).map((e) => e['doctor_id'] as int).toSet();
          _specialties = List<Map<String, dynamic>>.from(results[2] as List);
          _popularDoctors = List<Map<String, dynamic>>.from(results[3] as List);
          _featuredDoctors = List<Map<String, dynamic>>.from(
            results[4] as List,
          );
          _isLoading = false;
        });

        // Trigger tutorial AFTER loading finishes
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) setState(() => _showTutorial = true);
        });
      }
    } catch (e) {
      debugPrint("Error loading data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

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

  // ---------------------------------------------------------------------------
  // 3. MAIN UI BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFFBFBFB),
        body: Center(child: CircularProgressIndicator(color: primaryGreen)),
      );
    }

    return Stack(
      children: [
        // LAYER 1: The Main Screen (Scaffold)
        GestureDetector(
          // Attach Gesture Logic directly to the main screen layer
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          behavior: HitTestBehavior.translucent,
          child: Scaffold(
            backgroundColor: const Color(0xFFFBFBFB),
            body: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  _buildBanner(),
                  _buildContentSections(),
                ],
              ),
            ),
          ),
        ),

        // LAYER 2: The Scrim (Dark Overlay)
        // Only visible when drawer moves. Tapping it closes drawer.
        AnimatedBuilder(
          animation: _drawerController,
          builder: (context, child) {
            if (_drawerController.value == 0) return const SizedBox.shrink();
            return GestureDetector(
              onTap: _toggleDrawer,
              child: Container(
                color: Colors.black.withValues(
                  alpha: 0.5 * _drawerController.value,
                ),
                width: double.infinity,
                height: double.infinity,
              ),
            );
          },
        ),

        // LAYER 3: The Custom Drawer Panel
        AnimatedBuilder(
          animation: _drawerController,
          builder: (context, child) {
            // Translate X from -300 (hidden) to 0 (visible)
            final double slide =
                -_maxDrawerWidth * (1.0 - _drawerController.value);
            return Transform.translate(offset: Offset(slide, 0), child: child);
          },
          child: _buildDrawerPanel(),
        ),

        // LAYER 4: The Swipe Tutorial Overlay
        if (_showTutorial)
          Positioned.fill(child: SwipeIndicator(onDismiss: _dismissTutorial)),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 4. COMPONENT WIDGETS
  // ---------------------------------------------------------------------------

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
              // Avatar Toggles Custom Drawer
              GestureDetector(
                onTap: _toggleDrawer,
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white24,
                  backgroundImage:
                      _avatarUrl != null
                          ? NetworkImage(_avatarUrl!)
                          : const NetworkImage('https://i.pravatar.cc/300'),
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

  Widget _buildDrawerPanel() {
    return Container(
      width: _maxDrawerWidth,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(5, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 220,
            width: double.infinity,
            color: primaryGreen,
            padding: const EdgeInsets.only(top: 60, left: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.white,
                  backgroundImage:
                      _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                  child:
                      _avatarUrl == null
                          ? Icon(Icons.person, size: 40, color: primaryGreen)
                          : null,
                ),
                const SizedBox(height: 15),
                Text(
                  _userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  "Welcome back",
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  Icons.person,
                  "My Profile",
                  () => context.go('/profile'),
                ),
                _buildDrawerItem(
                  Icons.calendar_today,
                  "My Appointments",
                  () => context.push('/appointments'),
                ),
                _buildDrawerItem(Icons.settings, "Settings", _toggleDrawer),
                const Divider(),
                _buildDrawerItem(Icons.logout, "Logout", () async {
                  await Supabase.instance.client.auth.signOut();
                  if (mounted) context.go('/login');
                }, color: Colors.red),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    IconData icon,
    String title,
    VoidCallback onTap, {
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.grey[700]),
      title: Text(
        title,
        style: TextStyle(color: color ?? const Color(0xFF1A1A1A), fontSize: 16),
      ),
      onTap: () {
        _toggleDrawer(); // Close drawer first
        onTap();
      },
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
    if (name.toLowerCase().contains('dentist')) iconData = Icons.masks_rounded;
    if (name.toLowerCase().contains('cardio'))
      iconData = Icons.favorite_rounded;
    if (name.toLowerCase().contains('eye'))
      iconData = Icons.remove_red_eye_rounded;
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

// -----------------------------------------------------------------------------
// 5. INTEGRATED SWIPE INDICATOR CLASS (No separate file needed)
// -----------------------------------------------------------------------------

class SwipeIndicator extends StatefulWidget {
  final VoidCallback onDismiss;
  const SwipeIndicator({super.key, required this.onDismiss});

  @override
  State<SwipeIndicator> createState() => _SwipeIndicatorState();
}

class _SwipeIndicatorState extends State<SwipeIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _positionAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    // Start from 20 (Left) -> Move to 120 (Right) to simulate opening drawer
    _positionAnimation = Tween<double>(begin: 20.0, end: 120.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );
    _startTutorial();
  }

  Future<void> _startTutorial() async {
    await _controller.forward();
    _controller.reset();
    await _controller.forward();
    if (mounted) widget.onDismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: widget.onDismiss,
          child: Container(
            color: Colors.black.withValues(alpha: 0.4),
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        Positioned(
          left: 0,
          top: MediaQuery.of(context).size.height * 0.4,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_positionAnimation.value, 0),
                child: Opacity(opacity: _opacityAnimation.value, child: child),
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.2),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.touch_app_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 12),
                const Material(
                  color: Colors.transparent,
                  child: Text(
                    "Swipe to open menu",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        BoxShadow(
                          color: Colors.black,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
