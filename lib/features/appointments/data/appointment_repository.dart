import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_failure.dart';
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
          .eq('status', 'confirmed')
          .order('schedule_date', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      return data
          .map((json) => Appointment.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to load appointments right now.',
      );
    }
  }

  /// Cancels an appointment by ID.
  Future<void> cancelAppointment(int appointmentId) async {
    try {
      await _client
          .from('appointments')
          .update({'status': 'cancelled'})
          .eq('id', appointmentId);
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to cancel appointment right now.',
      );
    }
  }

  /// Marks an appointment as completed.
  Future<void> completeAppointment(int appointmentId) async {
    try {
      await _client
          .from('appointments')
          .update({'status': 'completed'})
          .eq('id', appointmentId);
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to update appointment status right now.',
      );
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
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to load booked slots right now.',
      );
    }
  }

  Future<int> createAppointment(Map<String, dynamic> appointmentData) async {
    try {
      final inserted =
          await _client
              .from('appointments')
              .insert(appointmentData)
              .select('id')
              .single();

      final idValue = inserted['id'];
      if (idValue is int) {
        return idValue;
      }

      final parsed = int.tryParse(idValue.toString());
      if (parsed == null) {
        throw const AppFailure(
          type: AppFailureType.backend,
          userMessage: 'Booking created but appointment ID could not be read.',
          technicalMessage:
              'appointments.insert returned an invalid/non-numeric id.',
          code: 'invalid_appointment_id',
        );
      }

      return parsed;
    } on PostgrestException catch (error) {
      final details =
          '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
              .toLowerCase();
      if (error.code == '23505' && details.contains('idempotency')) {
        throw const AppFailure(
          type: AppFailureType.validation,
          userMessage:
              'This booking request was already submitted. Please wait for confirmation.',
          technicalMessage:
              'Duplicate idempotency key detected while creating appointment.',
          code: 'duplicate_idempotency_key',
        );
      }
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to create appointment right now.',
      );
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to create appointment right now.',
      );
    }
  }

  Future<void> updateAppointment(
    int appointmentId,
    Map<String, dynamic> appointmentData,
  ) async {
    try {
      await _client
          .from('appointments')
          .update(appointmentData)
          .eq('id', appointmentId);
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to update appointment right now.',
      );
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

  /// Removes a realtime channel subscription.
  Future<void> removeChannel(RealtimeChannel channel) async {
    try {
      await _client.removeChannel(channel);
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to refresh realtime updates right now.',
      );
    }
  }
}
