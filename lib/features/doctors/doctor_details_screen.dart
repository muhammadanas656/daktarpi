import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DoctorDetailsScreen extends StatefulWidget {
  final String doctorId;

  const DoctorDetailsScreen({super.key, required this.doctorId});

  @override
  State<DoctorDetailsScreen> createState() => _DoctorDetailsScreenState();
}

class _DoctorDetailsScreenState extends State<DoctorDetailsScreen> {
  // Colors
  final Color primaryGreen = const Color(0xFF00C689);
  final Color bgColor = const Color(0xFFFBFBFB);
  final Color textDark = const Color(0xFF1A1A1A);
  final Color goldColor = const Color(0xFFFFC107); // For Featured elements

  // State
  bool _isLoading = true;
  Map<String, dynamic>? _doctor;
  List<Map<String, dynamic>> _clinics = [];
  Map<String, dynamic>? _selectedClinic;
  String? _userLocation;
  int _selectedDateIndex = 0;
  int _selectedTimeSlotIndex = -1;

  @override
  void initState() {
    super.initState();
    _fetchDoctorDetails();
  }

  Future<void> _fetchDoctorDetails() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;

    try {
      final docResponse =
          await client
              .from('doctors')
              .select('*, specialties(name)')
              .eq('id', widget.doctorId)
              .single();

      final clinicsResponse = await client
          .from('doctor_clinics')
          .select('visit_price, clinics(*)')
          .eq('doctor_id', widget.doctorId);

      if (userId != null) {
        final profile =
            await client
                .from('profiles')
                .select('location')
                .eq('id', userId)
                .maybeSingle();
        _userLocation = profile?['location'];
      }

      if (mounted) {
        setState(() {
          _doctor = docResponse;
          _clinics = List<Map<String, dynamic>>.from(
            clinicsResponse.map((e) {
              final clinicData = e['clinics'] as Map<String, dynamic>;
              clinicData['visit_price'] = e['visit_price'];
              return clinicData;
            }),
          );

          if (_clinics.isNotEmpty) {
            _selectedClinic = _clinics.first;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading doctor details: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(child: CircularProgressIndicator(color: primaryGreen)),
      );
    }

    if (_doctor == null) {
      return const Scaffold(body: Center(child: Text("Doctor not found")));
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Positioned.fill(
            bottom: 80,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDoctorProfileCard(),
                  const SizedBox(height: 24),
                  _buildStatsRow(),
                  const SizedBox(height: 24),
                  _buildAppointmentSection(),
                  const SizedBox(height: 24),
                  const Text(
                    "Timing",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  _buildTimingList(),
                  const SizedBox(height: 24),
                  const Text(
                    "Location",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  _buildLocationSelector(),
                  const SizedBox(height: 16),
                  _buildMapSection(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              color: Colors.white,
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Book Now",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: bgColor,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: const Icon(
            Icons.arrow_back_ios,
            size: 16,
            color: Colors.black,
          ),
        ),
        onPressed: () => context.pop(),
      ),
      title: const Text(
        "Doctor Details",
        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.black),
          onPressed: () {},
        ),
      ],
    );
  }

  // --- UPDATED PROFILE CARD ---
  Widget _buildDoctorProfileCard() {
    final specialty =
        _doctor!['specialties'] != null
            ? _doctor!['specialties']['name']
            : 'Specialist';

    // Check Feature Status
    final bool isFeatured = _doctor!['is_featured'] ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image (With Gold Border if Featured)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    14,
                  ), // Slightly larger than clip
                  border:
                      isFeatured
                          ? Border.all(color: goldColor, width: 2)
                          : null,
                ),
                padding: isFeatured ? const EdgeInsets.all(2) : EdgeInsets.zero,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _doctor!['profile_picture_url'] ??
                        'https://i.pravatar.cc/300',
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, __, ___) => Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey[200],
                          child: const Icon(Icons.person, color: Colors.grey),
                        ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // FEATURED BADGE LOGIC
                    if (isFeatured)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: goldColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified, color: goldColor, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              "Featured Doctor",
                              style: TextStyle(
                                color: Colors.orange[800],
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                    Text(
                      _doctor!['full_name'],
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Specialist $specialty",
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    _buildDynamicStars(_doctor!['rating']?.toString() ?? '0'),
                  ],
                ),
              ),
              // Price
              Column(
                children: [
                  Text(
                    "৳ ${_doctor!['hourly_rate']}/visit",
                    style: TextStyle(
                      color: primaryGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Additional Info for Featured Doctors
          if (isFeatured)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  const Icon(Icons.shield, color: Colors.blue, size: 16),
                  const SizedBox(width: 6),
                  const Text(
                    "Priority Support",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.check_circle, color: primaryGreen, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    "Verified",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: primaryGreen,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 20),
          // Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Book Now",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.favorite, color: Colors.red, size: 28),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicStars(String rating) {
    final double ratingVal = double.tryParse(rating) ?? 0.0;
    final int fullStars = ratingVal.floor();
    final bool hasHalfStar = (ratingVal - fullStars) >= 0.5;

    return Row(
      children: List.generate(5, (index) {
        if (index < fullStars) {
          return const Icon(Icons.star, color: Colors.amber, size: 14);
        } else if (index == fullStars && hasHalfStar) {
          return const Icon(Icons.star_half, color: Colors.amber, size: 14);
        } else {
          return Icon(Icons.star_border, color: Colors.grey[300], size: 14);
        }
      }),
    );
  }

  // --- EXISTING WIDGETS ---

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStatItem(
          icon: Icons.star,
          color: Colors.amber,
          value: "${_doctor!['rating']}",
          label: "Rating & Review",
        ),
        Container(width: 1, height: 40, color: Colors.grey[300]),
        _buildStatItem(
          icon: Icons.work,
          color: primaryGreen,
          value: "${_doctor!['experience_years']}",
          label: "Years of work",
        ),
        Container(width: 1, height: 40, color: Colors.grey[300]),
        _buildStatItem(
          icon: Icons.people,
          color: Colors.blue,
          value: "${_doctor!['patients_served']}",
          label: "No. of patients",
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: textDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
      ],
    );
  }

  Widget _buildAppointmentSection() {
    final clinicName = _selectedClinic?['name'] ?? 'Unknown Clinic';
    final clinicAddress = _selectedClinic?['address'] ?? '';
    final clinicPrice =
        _selectedClinic?['visit_price'] ?? _doctor!['hourly_rate'];
    final waitTime = _doctor!['avg_wait_time'] ?? 'Unknown';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFE0F7FA),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "In-Clinic Appointment",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  "৳ $clinicPrice",
                  style: TextStyle(
                    color: primaryGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clinicName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      clinicAddress,
                      style: TextStyle(color: primaryGreen, fontSize: 12),
                    ),
                    if (_clinics.length > 1)
                      Text(
                        "${_clinics.length - 1} More clinic",
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "$waitTime or less wait time",
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                const Divider(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(3, (index) {
                    final date = DateTime.now().add(Duration(days: index));
                    final isSelected = _selectedDateIndex == index;
                    String label =
                        index == 0
                            ? "Today"
                            : index == 1
                            ? "Tomorrow"
                            : DateFormat('d MMM').format(date);

                    return GestureDetector(
                      onTap: () => setState(() => _selectedDateIndex = index),
                      child: Column(
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSelected ? textDark : Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (isSelected)
                            Container(
                              width: 40,
                              height: 3,
                              color: primaryGreen,
                            ),
                        ],
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children:
                      [
                        "06:00 - 06:30",
                        "06:30 - 07:00",
                        "07:00 - 07:30",
                      ].asMap().entries.map((entry) {
                        final isSelected = _selectedTimeSlotIndex == entry.key;
                        return GestureDetector(
                          onTap:
                              () => setState(
                                () => _selectedTimeSlotIndex = entry.key,
                              ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? primaryGreen.withOpacity(0.1)
                                      : const Color(0xFFE0F7FA),
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  isSelected
                                      ? Border.all(color: primaryGreen)
                                      : null,
                            ),
                            child: Text(
                              entry.value,
                              style: TextStyle(
                                color:
                                    isSelected ? primaryGreen : Colors.black54,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimingList() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children:
            ["Monday", "Tuesday", "Wednesday"].map((day) {
              return Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(16),
                width: 140,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      day,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "09:00 AM - 05:00 PM",
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildLocationSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children:
            _clinics.map((clinic) {
              final isSelected = _selectedClinic == clinic;
              final shortName = clinic['name'].toString().split(' ').first;

              return GestureDetector(
                onTap: () => setState(() => _selectedClinic = clinic),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(16),
                  width: 150,
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? primaryGreen.withOpacity(0.1)
                            : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? primaryGreen : Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shortName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? primaryGreen : textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        clinic['name'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildMapSection() {
    final bool hasLocation = _userLocation != null && _userLocation!.isNotEmpty;

    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        image: const DecorationImage(
          image: NetworkImage(
            "https://static.vecteezy.com/system/resources/previews/000/153/588/original/vector-roadmap-location-map.jpg",
          ),
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          const Center(
            child: Icon(Icons.location_on, color: Colors.red, size: 40),
          ),
          if (hasLocation)
            Positioned(
              bottom: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(blurRadius: 5, color: Colors.black26),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.directions, color: primaryGreen, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      "Get Directions",
                      style: TextStyle(
                        color: primaryGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Positioned(
              bottom: 20,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(blurRadius: 5, color: Colors.black26),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.map, color: Colors.grey[700], size: 20),
                    const SizedBox(width: 4),
                    Text(
                      "Clinic Location Only",
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
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
}
