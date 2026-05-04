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

  Future<Box> _getCacheBox() async {
    if (Hive.isBoxOpen(_cacheBoxName)) return Hive.box(_cacheBoxName);
    return await Hive.openBox(_cacheBoxName);
  }

  Future<void> _invalidateCaches(String userId) async {
    final box = await _getCacheBox();
    await box.delete('appointments_$userId');
    
    // --- PRO FIX: Invalidate Medical Records Cache ---
    // Attached records are locked/unlocked, so we must force a fetch!
    if (Hive.isBoxOpen('medical_cache')) {
      await Hive.box('medical_cache').delete('medical_records_$userId');
      await Hive.box('medical_cache').delete('medical_records_${userId}_time');
    } else {
      final mrBox = await Hive.openBox('medical_cache');
      await mrBox.delete('medical_records_$userId');
      await mrBox.delete('medical_records_${userId}_time');
    }
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

    await NetworkNotifier.instance.waitForSync();

    try {
      final data = await fetcher().timeout(const Duration(seconds: 8));
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
              // Sync offline bookings using the new RPC too!
              await _client.rpc('book_appointment_safe', params: {
                'p_user_id': payload['user_id'],
                'p_doctor_id': payload['doctor_id'],
                'p_clinic_id': payload['clinic_id'],
                'p_schedule_date': payload['schedule_date'],
                'p_start_time': payload['start_time'],
                'p_end_time': payload['end_time'],
                'p_status': payload['status'],
                'p_patient_name': payload['patient_name'],
                'p_patient_phone': payload['patient_phone'],
                'p_patient_email': payload['patient_email'],
                'p_patient_gender': payload['patient_gender'],
                'p_patient_dob': payload['patient_dob'],
                'p_patient_image_url': payload['patient_image_url'],
                'p_idempotency_key': payload['idempotency_key'],
                'p_attached_record_ids': payload['attached_record_ids'] ?? [],
              });
              break;
            case 'cancel_appointment':
              await _client.from('appointments').update({
                'status': 'canceled',
                'cancel_reason': payload['reason'],
              }).eq('id', payload['id']);
              break;
            case 'complete_appointment':
              await _client.from('appointments').update({'status': 'completed'}).eq('id', payload['id']);
              break;
            case 'update_appointment':
              await _client.from('appointments').update(payload['data']).eq('id', payload['id']);
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
                doctor_id, clinic_id, attached_record_ids,
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

  Future<void> cancelAppointment(int appointmentId, String reason) async {
    if (NetworkNotifier.instance.isOffline) {
      await _queueAction('cancel_appointment', {
        'id': appointmentId,
        'reason': reason,
      });
      return;
    }
    await NetworkNotifier.instance.waitForSync();

    try {
      final response = await _client
          .from('appointments')
          .update({
            'status': 'canceled',
            'cancel_reason': reason,
          })
          .eq('id', appointmentId)
          .select();

      final userId = currentUserId;
      if (userId != null) {
        await _invalidateCaches(userId);
      }

      if (response.isEmpty) {
        throw const AppFailure(
          type: AppFailureType.backend,
          userMessage: 'Unable to cancel appointment. It may have already been removed.',
          technicalMessage: 'RLS blocked the cancellation, or appointment not found.',
          code: 'cancel_failed_empty',
        );
      }
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage:
            'Unable to cancel this appointment right now. Please try again.',
      );
    }
  }

  Future<void> completeAppointment(int appointmentId) async {
    if (NetworkNotifier.instance.isOffline) {
      await _queueAction('complete_appointment', {'id': appointmentId});
      return;
    }
    await NetworkNotifier.instance.waitForSync(); 

    try {
      await _client.from('appointments').update({'status': 'completed'}).eq('id', appointmentId);
      final userId = currentUserId;
      if (userId != null) {
        await _invalidateCaches(userId);
      }
    } catch (error) {
      throw AppFailure.fromError(error, fallbackUserMessage: 'Unable to update appointment status right now.');
    }
  }

  // --- LEGACY BRIDGE: Keeps DoctorDetailsScreen from crashing ---
  Future<List<String>> fetchBookedSlots({
    required String doctorId,
    required String clinicId,
    required String date,
    int? excludeAppointmentId,
  }) async {
    if (NetworkNotifier.instance.isOffline) return [];
    await NetworkNotifier.instance.waitForSync();

    try {
      var query = _client
          .from('appointments')
          .select('start_time, end_time')
          .eq('doctor_id', doctorId)
          .eq('clinic_id', clinicId)
          .eq('schedule_date', date)
          .isFilter('deleted_at', null)
          .neq('status', 'canceled')
          .neq('status', 'missed');

      if (excludeAppointmentId != null) {
        query = query.neq('id', excludeAppointmentId);
      }

      final response = await query;
      return List<dynamic>.from(response).map((record) {
        final start = record['start_time'].toString().substring(0, 5);
        final end = record['end_time'].toString().substring(0, 5);
        return '$start - $end';
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // --- PRO FIX: Fetch counts instead of a flat list! ---
  Future<Map<String, int>> fetchSlotBookingCounts({
    required String doctorId,
    required String clinicId,
    required String date,
    int? excludeAppointmentId,
  }) async {
    if (NetworkNotifier.instance.isOffline) {
      throw const AppFailure(
        type: AppFailureType.network,
        userMessage: 'Cannot check live slots while offline.',
        technicalMessage: 'offline',
      );
    }
    await NetworkNotifier.instance.waitForSync();

    try {
      var query = _client.from('appointments').select('start_time, end_time')
          .eq('doctor_id', doctorId)
          .eq('clinic_id', clinicId)
          .eq('schedule_date', date)
          .isFilter('deleted_at', null)
          .neq('status', 'canceled')
          .neq('status', 'missed'); // Ensure we don't count inactive ones
          
      if (excludeAppointmentId != null) {
        query = query.neq('id', excludeAppointmentId);
      }

      final response = await query;
      Map<String, int> counts = {};
      
      for (var record in List<dynamic>.from(response)) {
        final start = record['start_time'].toString().substring(0, 5);
        final end = record['end_time'].toString().substring(0, 5);
        final key = "$start - $end";
        counts[key] = (counts[key] ?? 0) + 1;
      }
      return counts;
    } catch (error) {
      throw AppFailure.fromError(error, fallbackUserMessage: 'Unable to load booked slots right now.');
    }
  }

  Future<int> createAppointment(Map<String, dynamic> appointmentData) async {
    if (NetworkNotifier.instance.isOffline) {
      await _queueAction('create_appointment', appointmentData);
      return -DateTime.now().millisecondsSinceEpoch.remainder(100000);
    }
    await NetworkNotifier.instance.waitForSync();

    try {
      // --- PRO FIX: Use the secure RPC to completely eliminate double bookings ---
      final insertedId = await _client.rpc('book_appointment_safe', params: {
        'p_user_id': appointmentData['user_id'],
        'p_doctor_id': appointmentData['doctor_id'],
        'p_clinic_id': appointmentData['clinic_id'],
        'p_schedule_date': appointmentData['schedule_date'],
        'p_start_time': appointmentData['start_time'],
        'p_end_time': appointmentData['end_time'],
        'p_status': appointmentData['status'],
        'p_patient_name': appointmentData['patient_name'],
        'p_patient_phone': appointmentData['patient_phone'],
        'p_patient_email': appointmentData['patient_email'],
        'p_patient_gender': appointmentData['patient_gender'],
        'p_patient_dob': appointmentData['patient_dob'],
        'p_patient_image_url': appointmentData['patient_image_url'],
        'p_idempotency_key': appointmentData['idempotency_key'],
        'p_attached_record_ids': appointmentData['attached_record_ids'] ?? [],
      });

      final userId = currentUserId;
      if (userId != null) {
        await _invalidateCaches(userId);
      }

      return int.parse(insertedId.toString());
      
    } on PostgrestException catch (error) {
      // --- PRO FIX: Catch the custom exception we raised in SQL! ---
      if (error.message.contains('Slot is fully booked')) {
        throw const AppFailure(
          type: AppFailureType.validation,
          userMessage: 'We are sorry, but someone just booked the last spot for this time. Please select another slot.',
          technicalMessage: 'RPC locked and rejected booking.',
          code: 'slot_full',
        );
      }
      if (error.code == '23505') {
        throw const AppFailure(
          type: AppFailureType.validation,
          userMessage: 'This booking request was already submitted. Please wait for confirmation.',
          technicalMessage: 'Duplicate idempotency key detected.',
          code: 'duplicate_idempotency_key',
        );
      }
      throw AppFailure.fromError(error, fallbackUserMessage: 'Unable to create appointment right now.');
    } catch (error) {
      throw AppFailure.fromError(error, fallbackUserMessage: 'Unable to create appointment right now.');
    }
  }

  Future<void> updateAppointment(int appointmentId, Map<String, dynamic> appointmentData) async {
    if (NetworkNotifier.instance.isOffline) {
      await _queueAction('update_appointment', {'id': appointmentId, 'data': appointmentData});
      return;
    }
    await NetworkNotifier.instance.waitForSync();
    try {
      await _client.from('appointments').update(appointmentData).eq('id', appointmentId);
    } catch (error) {
      throw AppFailure.fromError(error, fallbackUserMessage: 'Unable to update appointment right now.');
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
    final logCacheKey = 'activity_log_complete_$userId';
    final logData = box.get(logCacheKey);
    if (logData != null) {
      final List<dynamic> decoded = jsonDecode(logData);
      for (var item in decoded) {
        if (item['id'] == appointmentId) item['has_review'] = true;
      }
      await box.put(logCacheKey, jsonEncode(decoded));
    }

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
    } catch (error) {
      throw AppFailure.fromError(error, fallbackUserMessage: 'Unable to submit review right now.');
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
      final logCacheKey = 'activity_log_complete_$userId';
      final logData = box.get(logCacheKey);
      if (logData != null) {
        final List<dynamic> decoded = jsonDecode(logData);
        for (var item in decoded) {
          if (item['id'] == appointmentId) item['has_complaint'] = true;
        }
        await box.put(logCacheKey, jsonEncode(decoded));
      }

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
      throw AppFailure.fromError(error, fallbackUserMessage: 'Unable to submit your complaint right now.');
    }
  }

  Future<List<Map<String, dynamic>>> fetchActivityLog(String userId) async {
    try {
      return await _fetchWithCache(
        cacheKey: 'activity_log_complete_$userId',
        fetcher: () async {
          final response = await _client
              .from('appointment_history')
              .select('*, doctors ( full_name, profile_picture_url, specialties ( name ) ), clinics ( name )')
              .eq('user_id', userId)
              .order('archived_at', ascending: false);
          final historyList = List<Map<String, dynamic>>.from(response);

          final reviewsResponse = await _client.from('reviews').select('appointment_id').eq('user_id', userId);
          final complaintsResponse = await _client.from('complaints').select('appointment_id').eq('user_id', userId);

          final reviewedIds = reviewsResponse.map((r) => r['appointment_id']).toSet();
          final complainedIds = complaintsResponse.map((c) => c['appointment_id']).toSet();

          for (var item in historyList) {
            item['has_review'] = reviewedIds.contains(item['id']);
            item['has_complaint'] = complainedIds.contains(item['id']);
          }
          return historyList;
        },
      );
    } catch (error) {
      throw AppFailure.fromError(error, fallbackUserMessage: 'Unable to load activity log right now.');
    }
  }

  Future<List<Map<String, dynamic>>> fetchPendingReviews(String userId) async {
    try {
      final data = await _fetchWithCache(
        cacheKey: 'pending_reviews_$userId',
        fetcher: () async {
          final response = await _client
              .from('appointments')
              .select('*, doctors ( id, full_name, profile_picture_url, specialties ( name ) ), clinics ( id, name ), reviews ( id ) ')
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

  Future<List<Map<String, dynamic>>> fetchPendingComplaints(String userId) async {
    try {
      final data = await _fetchWithCache(
        cacheKey: 'pending_complaints_$userId',
        fetcher: () async {
          final response = await _client
              .from('appointments')
              .select('*, doctors ( id, full_name, profile_picture_url, specialties ( name ) ), clinics ( id, name ), complaints ( id ) ')
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
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
          callback: onChange,
        ).subscribe();
  }

  Future<void> removeChannel(RealtimeChannel channel) async {
    try {
      await _client.removeChannel(channel);
    } catch (error) {
      throw AppFailure.fromError(error, fallbackUserMessage: 'Unable to refresh realtime updates right now.');
    }
  }
}
