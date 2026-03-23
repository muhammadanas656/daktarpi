import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/network/network_notifier.dart';
import 'user_profile.dart';

class ProfileRepository {
  final SupabaseClient _client;

  // ─── Hive Cache & Queue Config ───
  static const String _cacheBoxName = 'profile_cache';
  static const String _queueBoxName = 'profile_offline_queue';
  static const _cacheDuration = Duration(minutes: 60);

  ProfileRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  String? get currentUserId => _client.auth.currentUser?.id;
  String? get currentUserEmail => _client.auth.currentUser?.email;

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // ─── Core Hive Engines ───────────────────────────────────────────────────

  Future<Box> _getCacheBox() async {
    if (Hive.isBoxOpen(_cacheBoxName)) {
      return Hive.box(_cacheBoxName);
    }
    return await Hive.openBox(_cacheBoxName);
  }

  Future<Box> _getQueueBox() async {
    if (Hive.isBoxOpen(_queueBoxName)) {
      return Hive.box(_queueBoxName);
    }
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
    debugPrint('⚡ [Profile Queue] Action saved: $actionType');
  }

  Future<void> syncOfflineQueue() async {
    if (NetworkNotifier.instance.isOffline) return;

    final box = await _getQueueBox();
    if (box.isEmpty) return;

    debugPrint('🔄 [Sync] Processing ${box.length} offline profile actions...');
    final keys = box.keys.toList();

    for (var key in keys) {
      final item = box.get(key);
      if (item != null) {
        try {
          final action = item['action'];
          final payload = jsonDecode(item['payload']);

          switch (action) {
            case 'update_profile':
              await _client.from('profiles').upsert(payload);
              break;
            case 'save_patient':
              await _client
                  .from('saved_patients')
                  .upsert(payload, onConflict: 'user_id, relation');
              break;
            case 'remove_patient':
              await _client
                  .from('saved_patients')
                  .delete()
                  .eq('user_id', payload['user_id'])
                  .eq('relation', payload['relation']);
              break;
          }
          await box.delete(key);
          debugPrint('✅ [Sync] Profile action completed: $action');
        } catch (e) {
          debugPrint('❌ [Sync] Failed to process profile action: $e');
        }
      }
    }
  }

  // ─── Profile Logic ───────────────────────────────────────────────────────

  Future<UserProfile?> getProfile(String userId) async {
    final cacheKey = 'profile_$userId';
    final box = await _getCacheBox();
    final isOffline = NetworkNotifier.instance.isOffline;

    final cachedData = box.get(cacheKey);
    final lastFetchStr = box.get('${cacheKey}_time');
    DateTime? lastFetch =
        lastFetchStr != null ? DateTime.tryParse(lastFetchStr) : null;

    if (isOffline || (_isCacheValid(lastFetch) && cachedData != null)) {
      if (cachedData != null) {
        return UserProfile.fromJson(jsonDecode(cachedData));
      }
      if (isOffline) {
        return null;
      }
    }

    // --- PRO FIX: SYNC GUARD ---
    await NetworkNotifier.instance.waitForSync();

    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 8));
      if (response != null) {
        await box.put(cacheKey, jsonEncode(response));
        await box.put('${cacheKey}_time', DateTime.now().toIso8601String());
        return UserProfile.fromJson(response);
      }
      return null;
    } catch (error) {
      if (cachedData != null) {
        return UserProfile.fromJson(jsonDecode(cachedData));
      }
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to load profile right now.',
      );
    }
  }

  Future<void> updateProfile(UserProfile profile, {String? utcOffset}) async {
    final Map<String, dynamic> data = profile.toJson();
    if (utcOffset != null) {
      data['utc_offset'] = utcOffset;
    }

    if (NetworkNotifier.instance.isOffline) {
      await _queueAction('update_profile', data);

      final box = await _getCacheBox();
      await box.put('profile_${profile.id}', jsonEncode(data));
      return;
    }

    // --- PRO FIX: SYNC GUARD ---
    await NetworkNotifier.instance.waitForSync();

    try {
      await _client.from('profiles').upsert(data);
      await _client.auth.updateUser(
        UserAttributes(
          data: {
            'full_name': profile.fullName,
            'dob': profile.dateOfBirth?.toIso8601String(),
          },
        ),
      );
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to update profile right now.',
      );
    }
  }

  Future<String> uploadProfilePicture(String userId, File imageFile) async {
    if (NetworkNotifier.instance.isOffline) {
      throw const AppFailure(
        type: AppFailureType.network,
        userMessage: 'You must be online to upload a profile picture.',
        technicalMessage: 'offline',
      );
    }

    try {
      final fileExt = imageFile.path.split('.').last;
      final fileName = '$userId/avatar.$fileExt';

      await _client.storage
          .from('profile_pictures')
          .upload(
            fileName,
            imageFile,
            fileOptions: const FileOptions(upsert: true),
          );

      final String publicUrl = _client.storage
          .from('profile_pictures')
          .getPublicUrl(fileName);
      return Uri.parse(publicUrl)
          .replace(
            queryParameters: {
              't': DateTime.now().millisecondsSinceEpoch.toString(),
            },
          )
          .toString();
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to upload profile image right now.',
      );
    }
  }

  Future<String> uploadPatientPicture(String userId, String relation, File imageFile) async {
    if (NetworkNotifier.instance.isOffline) {
      throw const AppFailure(
        type: AppFailureType.network,
        userMessage: 'You must be online to upload a category picture.',
        technicalMessage: 'offline',
      );
    }

    try {
      final fileExt = imageFile.path.split('.').last;
      final sanitizedRelation = relation.replaceAll(' ', '_').toLowerCase();
      final fileName = '$userId/${sanitizedRelation}_avatar.$fileExt';

      await _client.storage
          .from('profile_pictures')
          .upload(
            fileName,
            imageFile,
            fileOptions: const FileOptions(upsert: true),
          );

      final String publicUrl = _client.storage
          .from('profile_pictures')
          .getPublicUrl(fileName);
      return Uri.parse(publicUrl)
          .replace(
            queryParameters: {
              't': DateTime.now().millisecondsSinceEpoch.toString(),
            },
          )
          .toString();
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to upload category image right now.',
      );
    }
  }

  Future<void> deleteOldProfilePic(String userId, String? currentUrl) async {
    if (NetworkNotifier.instance.isOffline) {
      return;
    }
    if (currentUrl != null && currentUrl.contains('profile_pictures')) {
      try {
        final uri = Uri.parse(currentUrl);
        final bucketIndex = uri.pathSegments.indexOf('profile_pictures');
        if (bucketIndex != -1 && bucketIndex + 2 < uri.pathSegments.length) {
          final pathToDelete = uri.pathSegments
              .sublist(bucketIndex + 1)
              .join('/');
          await _client.storage.from('profile_pictures').remove([pathToDelete]);
          return;
        }
      } catch (e) {
        // Silently ignore parsing errors and fallback to directory listing
      }
    }
    try {
      final List<FileObject> objects = await _client.storage
          .from('profile_pictures')
          .list(path: userId);
      if (objects.isNotEmpty) {
        final List<String> paths =
            objects.map((e) => '$userId/${e.name}').toList();
        await _client.storage.from('profile_pictures').remove(paths);
      }
    } catch (_) {
      // Silently ignore cleanup errors to prevent blocking the user flow
    }
  }

  // ─── Saved Patients ──────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getSavedPatients(
    String userId, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'saved_patients_$userId';
    final box = await _getCacheBox();
    final isOffline = NetworkNotifier.instance.isOffline;

    final cachedData = box.get(cacheKey);
    final lastFetchStr = box.get('${cacheKey}_time');
    DateTime? lastFetch =
        lastFetchStr != null ? DateTime.tryParse(lastFetchStr) : null;

    if (isOffline ||
        (!forceRefresh && _isCacheValid(lastFetch) && cachedData != null)) {
      if (cachedData != null) {
        final List<dynamic> decoded = jsonDecode(cachedData);
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      if (isOffline) {
        return [];
      }
    }

    // --- PRO FIX: SYNC GUARD ---
    await NetworkNotifier.instance.waitForSync();

    try {
      final response = await _client
          .from('saved_patients')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: true);
      final data = List<Map<String, dynamic>>.from(response);

      await box.put(cacheKey, jsonEncode(data));
      await box.put('${cacheKey}_time', DateTime.now().toIso8601String());

      return data;
    } catch (e) {
      if (cachedData != null) {
        final List<dynamic> decoded = jsonDecode(cachedData);
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    }
  }

  Future<void> savePatientDetails(Map<String, dynamic> patientData) async {
    final userId = currentUserId;
    if (userId == null) {
      return;
    }
    patientData['user_id'] = userId;

    if (NetworkNotifier.instance.isOffline) {
      await _queueAction('save_patient', patientData);
      return;
    }

    // --- PRO FIX: SYNC GUARD ---
    await NetworkNotifier.instance.waitForSync();

    try {
      await _client
          .from('saved_patients')
          .upsert(patientData, onConflict: 'user_id, relation');
    } catch (e) {
      debugPrint("Error saving patient details: $e");
    }
  }

  Future<void> removePatientCategory(String relation) async {
    final userId = currentUserId;
    if (userId == null) {
      return;
    }

    if (NetworkNotifier.instance.isOffline) {
      await _queueAction('remove_patient', {
        'user_id': userId,
        'relation': relation,
      });
      return;
    }

    await NetworkNotifier.instance.waitForSync();

    try {
      await _client
          .from('saved_patients')
          .delete()
          .eq('user_id', userId)
          .eq('relation', relation);
          
      // --- PRO FIX: Instant Cache Invalidation ---
      // This stops the "Zombie Category" from reappearing when you go back and forth!
      final cacheKey = 'saved_patients_$userId';
      final box = await _getCacheBox();
      final cachedData = box.get(cacheKey);
      if (cachedData != null) {
        final List<dynamic> decoded = jsonDecode(cachedData);
        decoded.removeWhere((item) => item['relation'] == relation);
        await box.put(cacheKey, jsonEncode(decoded));
      }
      
    } catch (e) {
      throw AppFailure.fromError(
        e,
        fallbackUserMessage: 'Could not remove category.',
      );
    }
  }
}