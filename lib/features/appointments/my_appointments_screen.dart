import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

class MyAppointmentsScreen extends StatefulWidget {
  const MyAppointmentsScreen({super.key});

  @override
  State<MyAppointmentsScreen> createState() => _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends State<MyAppointmentsScreen> {
  // Colors
  final Color primaryGreen = const Color(0xFF00C689);
  final Color textDark = const Color(0xFF2C3A4B);
  final Color textLight = const Color(0xFF626F8D);

  bool _isLoading = true;
  List<Map<String, dynamic>> _appointments = [];

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  Future<void> _fetchAppointments() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final response = await Supabase.instance.client
          .from('appointments')
          .select('''
            id,
            schedule_date,
            start_time,
            end_time,
            status,
            doctors (
              full_name,
              profile_picture_url,
              specialties ( name )
            )
          ''')
          .eq('user_id', user.id)
          .order('schedule_date', ascending: true);

      if (mounted) {
        setState(() {
          _appointments = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching appointments: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- HELPER: Date Formatter ---
  String _formatDate(String? dateString) {
    if (dateString == null) return "Date TBD";
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('EEEE, d MMMM').format(date);
    } catch (e) {
      return dateString;
    }
  }

  // --- HELPER: Time Formatter ---
  String _formatTimeRange(String? startStr, String? endStr) {
    if (startStr == null) return "Time TBD";
    if (endStr == null) return _formatSingleTime(startStr);

    try {
      final DateTime startTime = _parseDatabaseTime(startStr);
      final DateTime endTime = _parseDatabaseTime(endStr);

      final String startHour = DateFormat("h:mm").format(startTime);
      final String startAmPm = DateFormat("a").format(startTime);

      final String endHour = DateFormat("h:mm").format(endTime);
      final String endAmPm = DateFormat("a").format(endTime);

      if (startAmPm == endAmPm) {
        return "$startHour - $endHour $endAmPm";
      } else {
        return "$startHour $startAmPm - $endHour $endAmPm";
      }
    } catch (e) {
      return "$startStr - $endStr";
    }
  }

  DateTime _parseDatabaseTime(String timeStr) {
    try {
      return DateFormat("HH:mm:ss").parse(timeStr);
    } catch (_) {
      return DateFormat("HH:mm").parse(timeStr);
    }
  }

  String _formatSingleTime(String timeStr) {
    try {
      final dt = _parseDatabaseTime(timeStr);
      return DateFormat("h:mm a").format(dt);
    } catch (_) {
      return timeStr;
    }
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
              // --- 1. Header ---
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          size: 18,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            context.go('/home');
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 20),
                    Text(
                      "My Appointments",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                      ),
                    ),
                  ],
                ),
              ),

              // --- 2. Upcoming Schedules Banner ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: primaryGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      "Upcoming Schedules",
                      style: TextStyle(
                        color: primaryGreen,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // --- 3. Appointment List ---
              Expanded(
                child:
                    _isLoading
                        ? Center(
                          child: CircularProgressIndicator(color: primaryGreen),
                        )
                        : _appointments.isEmpty
                        ? Center(
                          child: Text(
                            "No appointments found",
                            style: TextStyle(color: textLight),
                          ),
                        )
                        : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                          itemCount: _appointments.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final apt = _appointments[index];

                            final doctor =
                                apt['doctors'] as Map<String, dynamic>? ?? {};
                            final specialtyObj = doctor['specialties'];

                            final String name =
                                doctor['full_name'] ?? "Unknown Doctor";
                            final String imageUrl =
                                doctor['profile_picture_url'] ?? "";
                            final String specialty =
                                (specialtyObj is Map)
                                    ? specialtyObj['name'] ?? "Specialist"
                                    : "Specialist";

                            final String date = _formatDate(
                              apt['schedule_date'],
                            );
                            final String time = _formatTimeRange(
                              apt['start_time']?.toString(),
                              apt['end_time']?.toString(),
                            );

                            return _buildAppointmentCard(
                              name: name,
                              specialty: specialty,
                              date: date,
                              time: time,
                              imageUrl: imageUrl,
                            );
                          },
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- OVERFLOW-SAFE CARD WIDGET ---
  Widget _buildAppointmentCard({
    required String name,
    required String specialty,
    required String date,
    required String time,
    required String imageUrl,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Row 1: Doctor Info
          Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  image:
                      imageUrl.isNotEmpty
                          ? DecorationImage(
                            image: NetworkImage(imageUrl),
                            fit: BoxFit.cover,
                          )
                          : null,
                  color: Colors.grey[100],
                ),
                child:
                    imageUrl.isEmpty
                        ? Icon(Icons.person, size: 40, color: Colors.grey[400])
                        : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      specialty,
                      style: TextStyle(
                        fontSize: 14,
                        color: textLight,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Row 2: Date & Time Info
          Row(
            children: [
              // --- Date Section ---
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: Color(0xFF626F8D),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        date,
                        style: const TextStyle(
                          color: Color(0xFF626F8D),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // --- Time Section (ADJUSTED PLACEMENT) ---
              Expanded(
                flex: 5,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: Color(0xFF626F8D),
                    ),
                    const SizedBox(width: 6),
                    // CHANGED: From Expanded to Flexible.
                    // Flexible allows text to take only needed space, keeping it hugged to the icon.
                    // MainAxisAlignment.end pushes the whole [Icon + Text] group to the right.
                    Flexible(
                      child: Text(
                        time,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Color(0xFF626F8D),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
