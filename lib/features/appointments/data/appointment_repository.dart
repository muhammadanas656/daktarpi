import 'package:supabase_flutter/supabase_flutter.dart';
import 'appointment.dart';

class AppointmentRepository {
  final SupabaseClient _client;

  AppointmentRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  /// Returns the current user's ID, or null if not logged in.
  String? get currentUserId => _client.auth.currentUser?.id;

  /// Fetches appointments for a specific user.
  /// Returns a list of [Appointment] objects.
  Future<List<Appointment>> fetchAppointments(String userId) async {
    try {
      final response = await _client
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
          .eq('user_id', userId)
          .neq('status', 'cancelled')
          .order('schedule_date', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      return data
          .map((json) => Appointment.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch appointments: $e');
    }
  }

  /// Cancels an appointment by ID.
  Future<void> cancelAppointment(int appointmentId) async {
    try {
      await _client
          .from('appointments')
          .update({'status': 'cancelled'})
          .eq('id', appointmentId);
    } catch (e) {
      throw Exception('Failed to cancel appointment: $e');
    }
  }

  Future<List<String>> fetchBookedSlots({
    required String doctorId,
    required String clinicId,
    required String date,
    int? excludeAppointmentId,
  }) async {
    try {
      var query = _client
          .from('appointments')
          .select('start_time, end_time')
          .eq('doctor_id', doctorId)
          .eq('clinic_id', clinicId)
          .eq('schedule_date', date)
          .neq('status', 'cancelled');

      if (excludeAppointmentId != null) {
        query = query.neq('id', excludeAppointmentId);
      }

      final response = await query;

      final List<dynamic> data = response as List<dynamic>;
      return data.map((record) {
        final start = record['start_time'].toString().substring(0, 5);
        final end = record['end_time'].toString().substring(0, 5);
        return "$start - $end";
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch booked slots: $e');
    }
  }
  Future<void> createAppointment(Map<String, dynamic> appointmentData) async {
    try {
      await _client.from('appointments').insert(appointmentData);
    } catch (e) {
      throw Exception('Failed to create appointment: $e');
    }
  }

  Future<void> updateAppointment(int appointmentId, Map<String, dynamic> appointmentData) async {
    try {
      await _client
          .from('appointments')
          .update(appointmentData)
          .eq('id', appointmentId);
    } catch (e) {
      throw Exception('Failed to update appointment: $e');
    }
  }
  RealtimeChannel subscribeToAppointments({
    required String userId,
    required void Function(PostgresChangePayload) onChange,
  }) {
    return _client
        .channel('public:appointments')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'appointments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: onChange,
        )
        .subscribe();
  }
}
