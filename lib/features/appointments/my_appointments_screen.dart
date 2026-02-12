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
  // --- DESIGN SYSTEM ---
  static const Color primaryGreen = Color(0xFF00C689);
  static const Color textDark = Color(0xFF1A1A1A);
  static const Color textLight = Color(0xFF626F8D);
  static const Color borderColor = Color(0xFFE0E0E0);
  static const Color dangerRed = Color(
    0xFFE53935,
  ); // Matched ProfileScreen error red

  bool _isLoading = true;
  List<Map<String, dynamic>> _appointments = [];
  RealtimeChannel? _appointmentsSubscription;
  OverlayEntry? _errorOverlay; // Added for Custom Error

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    if (_appointmentsSubscription != null) {
      Supabase.instance.client.removeChannel(_appointmentsSubscription!);
    }
    _errorOverlay?.remove(); // Clean up overlay
    super.dispose();
  }

  // --- 1. CUSTOM ERROR OVERLAY (Copied from ProfileScreen) ---
  void _showTopError(String message) {
    if (!mounted) return;
    _errorOverlay?.remove();
    _errorOverlay = OverlayEntry(
      builder:
          (context) => Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            right: 20,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: dangerRed,
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );

    Overlay.of(context).insert(_errorOverlay!);
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        _errorOverlay?.remove();
        _errorOverlay = null;
      }
    });
  }

  // --- 2. CUSTOM SUCCESS SNACKBAR (Matched ProfileScreen) ---
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: primaryGreen,
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        margin: const EdgeInsets.only(bottom: 40, left: 20, right: 20),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
      ),
    );
  }

  // --- REFRESH LOGIC ---
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra;
    if (extra != null && extra is Map && extra['refresh'] == true) {
      _fetchAppointments();
      // Clear extra logic would ideally happen here or inside router
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSuccessSnackBar("Appointment Successful!");
      });
    }
  }

  void _setupRealtimeSubscription() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _appointmentsSubscription =
        Supabase.instance.client
            .channel('public:appointments')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'appointments',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'user_id',
                value: user.id,
              ),
              callback: (payload) => _fetchAppointments(),
            )
            .subscribe();
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
            patient_name,
            patient_phone,
            patient_email,
            patient_gender,
            patient_dob,
            doctor_id,
            clinic_id,
            doctors (
              id,
              full_name,
              profile_picture_url,
              specialties ( name )
            ),
            clinics (
              id,
              name,
              address
            )
          ''')
          .eq('user_id', user.id)
          .neq('status', 'cancelled')
          .order('schedule_date', ascending: true);

      if (mounted) {
        setState(() {
          _appointments = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      // Use Top Error for fetch failures if desired, or silent/debugPrint
      debugPrint('Error fetching appointments: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelAppointment(int id) async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client
          .from('appointments')
          .update({'status': 'cancelled'})
          .eq('id', id);

      if (mounted) {
        _showSuccessSnackBar("Appointment Cancelled");
      }
    } catch (e) {
      if (mounted) {
        _showTopError("Could not cancel appointment.");
      }
    } finally {
      if (mounted) _fetchAppointments();
    }
  }

  Future<void> _handleReschedule(Map<String, dynamic> appointment) async {
    final doctor = appointment['doctors'];
    final clinic = appointment['clinics'];
    final int appointmentId = appointment['id'];

    debugPrint("Rescheduling Appointment ID: $appointmentId");

    final patientDetails = {
      'name': appointment['patient_name'] ?? "",
      'phone': appointment['patient_phone'] ?? "",
      'email': appointment['patient_email'] ?? "",
      'gender': appointment['patient_gender'] ?? "Male",
      'dob': appointment['patient_dob'] ?? DateTime.now().toIso8601String(),
    };

    final result = await context.push(
      '/payment_method',
      extra: {
        'doctor': doctor,
        'clinic': clinic,
        'patientDetails': patientDetails,
        'appointmentDate': DateTime.now().add(const Duration(days: 1)),
        'appointmentId': appointmentId,
      },
    );

    if (result == true && mounted) {
      _showSuccessSnackBar("Reschedule Successful!");
      _fetchAppointments();
    }
  }

  void _showActionSheet(Map<String, dynamic> appointment) {
    final String doctorName = appointment['doctors']?['full_name'] ?? "Doctor";

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (context) => SafeArea(
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: borderColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Manage Appointment",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "With $doctorName",
                    style: const TextStyle(color: textLight, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      _handleReschedule(appointment);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: primaryGreen.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit_calendar,
                              color: primaryGreen,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            "Reschedule",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Divider(color: borderColor),
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      _confirmCancellation(appointment);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: dangerRed.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: dangerRed,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            "Cancel Appointment",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: dangerRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _confirmCancellation(Map<String, dynamic> appointment) {
    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      color: dangerRed.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: dangerRed,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Cancel Appointment?",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Are you sure you want to cancel this appointment? This action cannot be undone.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textLight,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Back",
                            style: TextStyle(
                              color: textLight,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _cancelAppointment(appointment['id']);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: dangerRed,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Yes, Cancel",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
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
              _buildAppBar(),
              _buildUpcomingBanner(),
              const SizedBox(height: 24),
              Expanded(
                child:
                    _isLoading
                        ? const Center(
                          child: CircularProgressIndicator(color: primaryGreen),
                        )
                        : _buildListView(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.calendar_today, size: 18, color: textDark),
          ),
          const SizedBox(width: 20),
          const Text(
            "My Appointments",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: primaryGreen.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            "Upcoming Schedules",
            style: TextStyle(
              color: primaryGreen,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListView() {
    if (_appointments.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          const Center(
            child: Text(
              "No upcoming appointments",
              style: TextStyle(color: textLight),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      itemCount: _appointments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final apt = _appointments[index];
        final doctor = apt['doctors'] as Map<String, dynamic>? ?? {};
        final specialty =
            doctor['specialties'] != null
                ? doctor['specialties']['name']
                : "Specialist";

        return _buildAppointmentCard(
          appointment: apt,
          name: doctor['full_name'] ?? "Unknown Doctor",
          specialty: specialty,
          date: _formatDate(apt['schedule_date']),
          time: _formatTimeRange(apt['start_time'], apt['end_time']),
          imageUrl: doctor['profile_picture_url'] ?? "",
        );
      },
    );
  }

  Widget _buildAppointmentCard({
    required Map<String, dynamic> appointment,
    required String name,
    required String specialty,
    required String date,
    required String time,
    required String imageUrl,
  }) {
    return GestureDetector(
      onLongPress: () => _showActionSheet(appointment),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.grey[100],
                    image:
                        imageUrl.isNotEmpty
                            ? DecorationImage(
                              image: NetworkImage(imageUrl),
                              fit: BoxFit.cover,
                            )
                            : null,
                  ),
                  child:
                      imageUrl.isEmpty
                          ? const Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.grey,
                          )
                          : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        specialty,
                        style: const TextStyle(fontSize: 14, color: textLight),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert, color: textLight),
                  onPressed: () => _showActionSheet(appointment),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(Icons.calendar_today_outlined, date),
                ),
                Expanded(
                  child: _buildInfoItem(
                    Icons.access_time_rounded,
                    time,
                    alignRight: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text, {bool alignRight = false}) {
    return Row(
      mainAxisAlignment:
          alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: textLight),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              color: textLight,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatDate(String? d) {
    if (d == null) return "";
    try {
      return DateFormat('EEEE, d MMMM').format(DateTime.parse(d));
    } catch (_) {
      return d;
    }
  }

  String _formatTimeRange(String? s, String? e) {
    if (s == null) return "";
    return "${_formatTime(s)} - ${_formatTime(e ?? s)}";
  }

  String _formatTime(String t) {
    try {
      return DateFormat("h:mm a").format(DateFormat("HH:mm:ss").parse(t));
    } catch (_) {
      return t;
    }
  }
}
