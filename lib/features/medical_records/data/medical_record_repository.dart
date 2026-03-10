import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/network/network_notifier.dart';
import 'medical_record.dart';

class MedicalRecordRepository {
  final SupabaseClient _client;

  static const String _cacheBoxName = 'medical_cache';
  static const String _queueBoxName = 'medical_offline_queue';
  static const _cacheDuration = Duration(minutes: 60);

  MedicalRecordRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<Box> _getCacheBox() async {
    if (Hive.isBoxOpen(_cacheBoxName)) return Hive.box(_cacheBoxName);
    return await Hive.openBox(_cacheBoxName);
  }

  Future<Box> _getQueueBox() async {
    if (Hive.isBoxOpen(_queueBoxName)) return Hive.box(_queueBoxName);
    return await Hive.openBox(_queueBoxName);
  }

  bool _isCacheValid(DateTime? lastFetch) {
    if (lastFetch == null) return false;
    return DateTime.now().difference(lastFetch) < _cacheDuration;
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
  }

  Future<void> syncOfflineQueue() async {
    if (NetworkNotifier.instance.isOffline) return;

    final box = await _getQueueBox();
    if (box.isEmpty) return;

    final keys = box.keys.toList();
    for (var key in keys) {
      final item = box.get(key);
      if (item != null) {
        try {
          final action = item['action'];
          final payload = jsonDecode(item['payload']);

          switch (action) {
            case 'add_record':
              await _client.from('medical_records').insert(payload);
              break;
            case 'update_record':
              await _client
                  .from('medical_records')
                  .update(payload['data'])
                  .eq('id', payload['id'])
                  .eq('user_id', payload['user_id']);
              break;
            case 'delete_record':
              if (payload['filePaths'] != null &&
                  (payload['filePaths'] as List).isNotEmpty) {
                await _client.storage
                    .from('medical_docs')
                    .remove(List<String>.from(payload['filePaths']));
              }
              await _client
                  .from('medical_records')
                  .update({'deleted_at': DateTime.now().toIso8601String()})
                  .eq('id', payload['id'])
                  .eq('user_id', payload['user_id']);
              break;
          }
          await box.delete(key);
        } catch (e) {
          debugPrint('❌ [Sync] Failed to process medical action: $e');
        }
      }
    }
  }

  Future<List<MedicalRecord>> fetchRecords() async {
    final userId = currentUserId;
    if (userId == null) return [];

    final cacheKey = 'medical_records_$userId';
    final box = await _getCacheBox();
    final isOffline = NetworkNotifier.instance.isOffline;

    final cachedData = box.get(cacheKey);
    final lastFetchStr = box.get('${cacheKey}_time');
    DateTime? lastFetch =
        lastFetchStr != null ? DateTime.tryParse(lastFetchStr) : null;

    if (isOffline || (_isCacheValid(lastFetch) && cachedData != null)) {
      if (cachedData != null) {
        final List<dynamic> decoded = jsonDecode(cachedData);
        return decoded
            .map((e) => MedicalRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (isOffline) {
        return [];
      }
    }

    // --- PRO FIX: SYNC GUARD ---
    // Forces the fetch to wait until any pending deleted/added records are synced!
    await NetworkNotifier.instance.waitForSync();

    try {
      final response = await _client
          .from('medical_records')
          .select()
          .eq('user_id', userId)
          .isFilter('deleted_at', null)
          .order('record_date', ascending: false);
      await box.put(cacheKey, jsonEncode(response));
      await box.put('${cacheKey}_time', DateTime.now().toIso8601String());

      return (response as List)
          .map((e) => MedicalRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (error) {
      if (cachedData != null) {
        final List<dynamic> decoded = jsonDecode(cachedData);
        return decoded
            .map((e) => MedicalRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to load medical records right now.',
      );
    }
  }

  Future<String> getSignedUrl(String path) async {
    if (NetworkNotifier.instance.isOffline) {
      throw const AppFailure(
        type: AppFailureType.network,
        userMessage: 'You must be online to view documents.',
        technicalMessage: 'offline',
      );
    }
    try {
      return await _client.storage
          .from('medical_docs')
          .createSignedUrl(path, 60 * 60);
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to open this file right now.',
      );
    }
  }

  Future<List<String>> uploadFiles(List<File> files) async {
    final userId = currentUserId;
    if (userId == null) {
      throw const AppFailure(
        type: AppFailureType.auth,
        userMessage: 'Please sign in to continue.',
        technicalMessage: 'Missing user.',
        code: 'not_authenticated',
      );
    }
    if (NetworkNotifier.instance.isOffline) {
      throw const AppFailure(
        type: AppFailureType.network,
        userMessage: 'You must be online to upload physical files.',
        technicalMessage: 'offline',
      );
    }

    List<String> uploadedUrls = [];
    for (var file in files) {
      try {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}';
        final path = '$userId/$fileName';
        await _client.storage.from('medical_docs').upload(path, file);
        uploadedUrls.add(path);
      } catch (error) {
        throw AppFailure.fromError(
          error,
          fallbackUserMessage: 'Unable to upload one or more files.',
        );
      }
    }
    return uploadedUrls;
  }

  Future<void> addRecord({
    required String recordFor,
    required String recordType,
    required DateTime recordDate,
    required List<String> fileUrls,
  }) async {
    final userId = currentUserId;
    if (userId == null) return;

    final payload = {
      'user_id': userId,
      'record_for': recordFor,
      'record_type': recordType,
      'record_date': recordDate.toIso8601String().split('T')[0],
      'file_urls': fileUrls,
    };

    if (NetworkNotifier.instance.isOffline) {
      await _queueAction('add_record', payload);
      final box = await _getCacheBox();
      final cacheKey = 'medical_records_$userId';
      final cachedData = box.get(cacheKey);

      if (cachedData != null) {
        final List<dynamic> decoded = jsonDecode(cachedData);
        payload['id'] =
            -DateTime.now().millisecondsSinceEpoch.remainder(100000);
        payload['created_at'] = DateTime.now().toIso8601String();
        decoded.insert(0, payload);
        await box.put(cacheKey, jsonEncode(decoded));
      }
      return;
    }

    // --- PRO FIX: SYNC GUARD ---
    await NetworkNotifier.instance.waitForSync();

    try {
      await _client.from('medical_records').insert(payload);
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to save this record right now.',
      );
    }
  }

  Future<void> deleteRecord(int id, List<String> filePaths) async {
    final userId = currentUserId;
    if (userId == null) return;
    if (NetworkNotifier.instance.isOffline) {
      await _queueAction('delete_record', {
        'id': id,
        'user_id': userId,
        'filePaths': filePaths,
      });
      return;
    }

    // --- PRO FIX: SYNC GUARD ---
    await NetworkNotifier.instance.waitForSync();

    try {
      if (filePaths.isNotEmpty) {
        await _client.storage.from('medical_docs').remove(filePaths);
      }
      await _client
          .from('medical_records')
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', id)
          .eq('user_id', userId);
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to delete this record right now.',
      );
    }
  }

  Future<void> updateRecord({
    required int id,
    required String recordFor,
    required String recordType,
    required DateTime recordDate,
    required List<String> fileUrls,
  }) async {
    final userId = currentUserId;
    if (userId == null) return;

    final payload = {
      'record_for': recordFor,
      'record_type': recordType,
      'record_date': recordDate.toIso8601String().split('T')[0],
      'file_urls': fileUrls,
    };
    if (NetworkNotifier.instance.isOffline) {
      await _queueAction('update_record', {
        'id': id,
        'user_id': userId,
        'data': payload,
      });
      return;
    }

    // --- PRO FIX: SYNC GUARD ---
    await NetworkNotifier.instance.waitForSync();

    try {
      await _client
          .from('medical_records')
          .update(payload)
          .eq('id', id)
          .eq('user_id', userId);
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to update this record right now.',
      );
    }
  }
}
