import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/network/network_notifier.dart';
import 'appointment.dart';

class AppointmentRepository {
  final SupabaseClient _client;

  static const String _cacheBoxName = 'appointment_cache';
  static const String _queueBoxName = 'offline_actions_queue';
  static const _cacheDuration = Duration(minutes: 60);

  AppointmentRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  String? get currentUserId => _client.auth.currentUser?.id;

  // ─── Phase 2: Hive Read Cache ──────────────────────────────────────────────

  Future<Box> _getCacheBox() async {
    if (Hive.isBoxOpen(_cacheBoxName)) return Hive.box(_cacheBoxName);
    return await Hive.openBox(_cacheBoxName);
  }

  bool _isCacheValid(DateTime? lastFetch) {
    if (lastFetch == null) return false;
    return DateTime.now().difference(lastFetch) < _cacheDuration;
  }

  Future<List<Map<String, dynamic>>> _fetchWithCache({
    required String cacheKey,
    required Future<List<Map<String, dynamic>>> Function() fetcher,
    bool forceRefresh = true,
  }) async {
    final box = await _getCacheBox();
    final isOffline = NetworkNotifier.instance.isOffline;
    final lastFetchKey = '${cacheKey}_time';

    final cachedData = box.get(cacheKey);
    final lastFetchStr = box.get(lastFetchKey);
    DateTime? lastFetch =
        lastFetchStr != null ? DateTime.tryParse(lastFetchStr) : null;

    if (isOffline ||
        (!forceRefresh && _isCacheValid(lastFetch) && cachedData != null)) {
      if (cachedData != null) {
        final List<dynamic> decoded = jsonDecode(cachedData);
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      if (isOffline) return [];
    }

    // --- PRO FIX: The Sync Guard ---
    // If the internet just came back, this will PAUSE the fetch until the offline
    // queue is 100% uploaded to Supabase. No more blinking UI!
    await NetworkNotifier.instance.waitForSync();

    try {
      final data = await fetcher();
      await box.put(cacheKey, jsonEncode(data));
      await box.put(lastFetchKey, DateTime.now().toIso8601String());
      return data;
    } catch (e) {
      if (cachedData != null) {
        final List<dynamic> decoded = jsonDecode(cachedData);
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      rethrow;
    }
  }

  // ─── Phase 3: Offline Action Queue ─────────────────────────────────────────

  Future<Box> _getQueueBox() async {
    if (Hive.isBoxOpen(_queueBoxName)) return Hive.box(_queueBoxName);
    return await Hive.openBox(_queueBoxName);
  }

  Future<void> _queueAction(
    String actionType,
    Map<String, dynamic> payload,
  ) async {
    final box = await _getQueueBox();
    await box.add({
      'action': actionType,
      'payload': jsonEncode(payload),
      'timestamp': DateTime.now().toIso8601String(),
    });
    debugPrint('⚡ [Offline Queue] Action saved: $actionType');
  }

  Future<void> syncOfflineQueue() async {
    if (NetworkNotifier.instance.isOffline) return;

    final box = await _getQueueBox();
    if (box.isEmpty) return;

    debugPrint('🔄 [Sync] Processing ${box.length} offline actions...');
    final keys = box.keys.toList();

    for (var key in keys) {
      final item = box.get(key);
      if (item != null) {
        try {
          final action = item['action'];
          final payload = jsonDecode(item['payload']);

          switch (action) {
            case 'create_appointment':
              await _client.from('appointments').insert(payload);
              break;
            case 'cancel_appointment':
              await _client
                  .from('appointments')
                  .update({'status': 'canceled'})
                  .eq('id', payload['id']);
              break;
            case 'complete_appointment':
              await _client
                  .from('appointments')
                  .update({'status': 'completed'})
                  .eq('id', payload['id']);
              break;
            case 'update_appointment':
              await _client
                  .from('appointments')
                  .update(payload['data'])
                  .eq('id', payload['id']);
              break;
            case 'submit_review':
              await _client.from('reviews').insert(payload);
              break;
            case 'submit_complaint':
              await _client.from('complaints').insert(payload);
              break;
          }
          await box.delete(key);
          debugPrint('✅ [Sync] Action completed: $action');
        } catch (e) {
          debugPrint('❌ [Sync] Failed to process action: $e');
        }
      }
    }
  }

  // ─── Data Access & Mutations ───────────────────────────────────────────────

  Future<List<Appointment>> fetchAppointments(String userId) async {
    try {
      final data = await _fetchWithCache(
        cacheKey: 'appointments_$userId',
        fetcher: () async {
          final response = await _client
              .from('appointments')
              .select('''
                id, schedule_date, start_time, end_time, status, patient_name,
                patient_phone, patient_email, patient_gender, patient_dob,
                doctor_id, clinic_id,
                doctors ( id, full_name, profile_picture_url, specialties ( name ), doctor_clinics ( clinic_id, max_wait_time ) ),
                clinics ( id, name, address )
              ''')
              .eq('user_id', userId)
              .isFilter('deleted_at', null)
              .inFilter('status', ['confirmed', 'waiting'])
              .order('schedule_date', ascending: true);
          return List<Map<String, dynamic>>.from(response);
        },
      );

      return data.map((json) => Appointment.fromJson(json)).toList();
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to load appointments right now.',
      );
    }
  }

  Future<void> cancelAppointment(int appointmentId) async {
    if (NetworkNotifier.instance.isOffline) {
      await _queueAction('cancel_appointment', {'id': appointmentId});
      return;
    }
    await NetworkNotifier.instance.waitForSync(); // PRO FIX

    try {
      final response =
          await _client
              .from('appointments')
              .update({'status': 'canceled'})
              .eq('id', appointmentId)
              .select();

      final userId = currentUserId;
      if (userId != null) {
        final box = await _getCacheBox();
        await box.delete('appointments_$userId');
      }

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
      throw AppFailure.fromError(
        e,
        fallbackUserMessage:
            'Unable to cancel this appointment right now. Please try again.',
      );
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage:
            'An unexpected error occurred while canceling the appointment.',
      );
    }
  }

  Future<void> completeAppointment(int appointmentId) async {
    if (NetworkNotifier.instance.isOffline) {
      await _queueAction('complete_appointment', {'id': appointmentId});
      return;
    }
    await NetworkNotifier.instance.waitForSync(); // PRO FIX

    try {
      await _client
          .from('appointments')
          .update({'status': 'completed'})
          .eq('id', appointmentId);

      final userId = currentUserId;
      if (userId != null) {
        final box = await _getCacheBox();
        await box.delete('appointments_$userId');
      }
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
    if (NetworkNotifier.instance.isOffline) {
      throw const AppFailure(
        type: AppFailureType.network,
        userMessage:
            'Cannot check live slots while offline. Please connect to the internet.',
        technicalMessage: 'offline',
      );
    }

    await NetworkNotifier.instance.waitForSync(); // PRO FIX

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
      return List<dynamic>.from(response).map((record) {
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
    if (NetworkNotifier.instance.isOffline) {
      await _queueAction('create_appointment', appointmentData);
      return -DateTime.now().millisecondsSinceEpoch.remainder(100000);
    }
    await NetworkNotifier.instance.waitForSync(); // PRO FIX

    try {
      final inserted =
          await _client
              .from('appointments')
              .insert(appointmentData)
              .select('id')
              .single();
      final idValue = inserted['id'];

      final userId = currentUserId;
      if (userId != null) {
        final box = await _getCacheBox();
        await box.delete('appointments_$userId');
      }

      if (idValue is int) return idValue;

      final parsed = int.tryParse(idValue.toString());
      if (parsed == null) {
        throw const AppFailure(
          type: AppFailureType.backend,
          userMessage: 'Booking created but appointment ID could not be read.',
          technicalMessage: 'appointments.insert returned an invalid id.',
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
          technicalMessage: 'Duplicate idempotency key detected.',
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
    if (NetworkNotifier.instance.isOffline) {
      await _queueAction('update_appointment', {
        'id': appointmentId,
        'data': appointmentData,
      });
      return;
    }
    await NetworkNotifier.instance.waitForSync(); // PRO FIX

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

  Future<void> submitReview({
    required int appointmentId,
    required int doctorId,
    required int rating,
    String? comment,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception("User not logged in.");

    final payload = {
      'appointment_id': appointmentId,
      'doctor_id': doctorId,
      'user_id': userId,
      'rating': rating,
      'comment': comment,
    };

    final box = await _getCacheBox();

    // Update Activity Log Cache
    final logCacheKey = 'activity_log_complete_$userId';
    final logData = box.get(logCacheKey);
    if (logData != null) {
      final List<dynamic> decoded = jsonDecode(logData);
      for (var item in decoded) {
        if (item['id'] == appointmentId) item['has_review'] = true;
      }
      await box.put(logCacheKey, jsonEncode(decoded));
    }

    // PRO FIX 4: Immediately remove the item from the Pending Reviews cache
    final pendingCacheKey = 'pending_reviews_$userId';
    final pendingData = box.get(pendingCacheKey);
    if (pendingData != null) {
      final List<dynamic> decodedPending = jsonDecode(pendingData);
      decodedPending.removeWhere((item) => item['id'] == appointmentId);
      await box.put(pendingCacheKey, jsonEncode(decodedPending));
    }

    if (NetworkNotifier.instance.isOffline) {
      await _queueAction('submit_review', payload);
      return;
    }
    await NetworkNotifier.instance.waitForSync();

    try {
      await _client.from('reviews').insert(payload);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
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

  Future<void> submitComplaint({
    int? appointmentId,
    int? doctorId,
    required String description,
    required String recipient,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception("User not logged in.");

    final payload = {
      'user_id': userId,
      if (appointmentId != null) 'appointment_id': appointmentId,
      if (doctorId != null) 'doctor_id': doctorId,
      'description': description,
      'recipient': recipient,
    };

    if (appointmentId != null) {
      final box = await _getCacheBox();

      // Update Activity Log Cache
      final logCacheKey = 'activity_log_complete_$userId';
      final logData = box.get(logCacheKey);
      if (logData != null) {
        final List<dynamic> decoded = jsonDecode(logData);
        for (var item in decoded) {
          if (item['id'] == appointmentId) item['has_complaint'] = true;
        }
        await box.put(logCacheKey, jsonEncode(decoded));
      }

      // PRO FIX 5: Immediately remove the item from the Pending Complaints cache
      final pendingCacheKey = 'pending_complaints_$userId';
      final pendingData = box.get(pendingCacheKey);
      if (pendingData != null) {
        final List<dynamic> decodedPending = jsonDecode(pendingData);
        decodedPending.removeWhere((item) => item['id'] == appointmentId);
        await box.put(pendingCacheKey, jsonEncode(decodedPending));
      }
    }

    if (NetworkNotifier.instance.isOffline) {
      await _queueAction('submit_complaint', payload);
      return;
    }
    await NetworkNotifier.instance.waitForSync();

    try {
      await _client.from('complaints').insert(payload);
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage:
            'Unable to submit your complaint right now. Please try again.',
      );
    }
  }

  // ─── Read-Only Fallbacks ───────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchActivityLog(String userId) async {
    try {
      return await _fetchWithCache(
        cacheKey: 'activity_log_complete_$userId',
        fetcher: () async {
          final response = await _client
              .from('appointment_history')
              .select(
                '*, doctors ( full_name, profile_picture_url, specialties ( name ) ), clinics ( name )',
              )
              .eq('user_id', userId)
              .order('archived_at', ascending: false);
          final historyList = List<Map<String, dynamic>>.from(response);

          final reviewsResponse = await _client
              .from('reviews')
              .select('appointment_id')
              .eq('user_id', userId);
          final complaintsResponse = await _client
              .from('complaints')
              .select('appointment_id')
              .eq('user_id', userId);

          final reviewedIds =
              reviewsResponse.map((r) => r['appointment_id']).toSet();
          final complainedIds =
              complaintsResponse.map((c) => c['appointment_id']).toSet();

          for (var item in historyList) {
            item['has_review'] = reviewedIds.contains(item['id']);
            item['has_complaint'] = complainedIds.contains(item['id']);
          }

          return historyList;
        },
      );
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to load activity log right now.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchPendingReviews(String userId) async {
    try {
      final data = await _fetchWithCache(
        cacheKey: 'pending_reviews_$userId',
        fetcher: () async {
          final response = await _client
              .from('appointments')
              .select(
                '*, doctors ( id, full_name, profile_picture_url, specialties ( name ) ), clinics ( id, name ), reviews ( id ) ',
              )
              .eq('user_id', userId)
              .eq('status', 'completed')
              .isFilter('deleted_at', null)
              .order('schedule_date', ascending: false);
          return List<Map<String, dynamic>>.from(response);
        },
      );
      return data.where((appt) {
        final reviews = appt['reviews'];
        if (reviews is List) return reviews.isEmpty;
        return reviews == null;
      }).toList();
    } catch (error) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchPendingComplaints(
    String userId,
  ) async {
    try {
      final data = await _fetchWithCache(
        cacheKey: 'pending_complaints_$userId',
        fetcher: () async {
          final response = await _client
              .from('appointments')
              .select(
                '*, doctors ( id, full_name, profile_picture_url, specialties ( name ) ), clinics ( id, name ), complaints ( id ) ',
              )
              .eq('user_id', userId)
              .eq('status', 'missed')
              .isFilter('deleted_at', null)
              .order('schedule_date', ascending: false);
          return List<Map<String, dynamic>>.from(response);
        },
      );
      return data.where((appt) {
        final complaints = appt['complaints'];
        if (complaints is List) return complaints.isEmpty;
        return complaints == null;
      }).toList();
    } catch (error) {
      return [];
    }
  }

  // ─── Realtime ─────────────────────────────────────────────────────────────

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
