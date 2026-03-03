import 'package:flutter/foundation.dart';
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
          .isFilter('deleted_at', null)
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

  /// Cancels an appointment by physically removing it from the active table.
  Future<void> cancelAppointment(int appointmentId) async {
    try {
      final response =
          await _client
              .from('appointments')
              .delete()
              .eq('id', appointmentId)
              .select();

      if (response.isEmpty) {
        throw const AppFailure(
          type: AppFailureType.backend,
          userMessage:
              'Unable to cancel appointment. It may have already been removed.',
          technicalMessage:
              'RLS blocked the cancellation, or appointment not found.',
          code: 'cancel_failed_empty',
        );
      }
    } on PostgrestException catch (e) {
      // Safely catch Supabase errors and provide a professional fallback.
      throw AppFailure.fromError(
        e,
        fallbackUserMessage:
            'Unable to cancel this appointment right now. Please try again.',
      );
    } catch (error) {
      // Safely catch general errors.
      throw AppFailure.fromError(
        error,
        fallbackUserMessage:
            'An unexpected error occurred while canceling the appointment.',
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
          .isFilter('deleted_at', null)
          .neq('status', 'canceled');

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

  /// Fetches the exhaustive audit log of all appointment actions and checks review status.
  Future<List<Map<String, dynamic>>> fetchActivityLog(String userId) async {
    try {
      // 1. Fetch the history log
      final response = await _client
          .from('appointment_history')
          .select('''
            *,
            doctors ( full_name, profile_picture_url ),
            clinics ( name )
          ''')
          .eq('user_id', userId)
          .order('archived_at', ascending: false);

      final historyList = List<Map<String, dynamic>>.from(response);

      // 2. Fetch all reviews made by this user to see which appointments are already reviewed
      final reviewsResponse = await _client
          .from('reviews')
          .select('appointment_id')
          .eq('user_id', userId);

      // Create a fast lookup set of reviewed appointment IDs
      final reviewedIds =
          reviewsResponse.map((r) => r['appointment_id']).toSet();

      // 3. Inject a 'has_review' flag into each history item
      for (var item in historyList) {
        item['has_review'] = reviewedIds.contains(item['id']);
      }

      return historyList;
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to load activity log right now.',
      );
    }
  }

  /// Submits a review for a completed appointment.
  Future<void> submitReview({
    required int appointmentId,
    required int doctorId,
    required int rating,
    String? comment,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception("User not logged in.");

      await _client.from('reviews').insert({
        'appointment_id':
            appointmentId, // This is the unique key to prevent double reviews
        'doctor_id': doctorId,
        'user_id': userId,
        'rating': rating,
        'comment': comment,
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        // Postgres code for Unique Constraint Violation
        throw AppFailure.fromError(
          e,
          fallbackUserMessage: 'You have already reviewed this appointment.',
        );
      }
      throw AppFailure.fromError(
        e,
        fallbackUserMessage: 'Unable to submit review right now.',
      );
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to submit review right now.',
      );
    }
  }

  /// Fetches completed appointments that have NOT been reviewed yet.
  Future<List<Map<String, dynamic>>> fetchPendingReviews(String userId) async {
    try {
      // Query appointments joined with reviews
      final response = await _client
          .from('appointments')
          .select('''
            *,
            doctors ( id, full_name, profile_picture_url, specialties ( name ) ),
            clinics ( id, name ),
            reviews ( id ) 
          ''')
          .eq('user_id', userId)
          .eq('status', 'completed')
          .isFilter('deleted_at', null)
          .order('schedule_date', ascending: false);

      final List<dynamic> data = response as List<dynamic>;

      // Filter out any appointments where the 'reviews' array is not empty
      return data.map((e) => e as Map<String, dynamic>).where((appt) {
        final reviews = appt['reviews'];
        if (reviews is List) return reviews.isEmpty;
        return reviews == null;
      }).toList();
    } catch (error) {
      debugPrint("Fetch pending reviews error: $error");
      return []; // Return empty so the UI gracefully hides the carousel on error
    }
  }
}
