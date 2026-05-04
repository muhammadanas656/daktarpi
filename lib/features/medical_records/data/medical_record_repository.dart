import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
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

  String _normalizePath(String path) {
    if (path.startsWith('file://')) {
      return Uri.parse(path).toFilePath();
    }
    return path;
  }

  bool isLocalFilePath(String path) {
    final normalizedPath = _normalizePath(path);
    return normalizedPath.startsWith('/') ||
        RegExp(r'^[A-Za-z]:[\\/]').hasMatch(normalizedPath);
  }

  String _fileExtension(String path) {
    final normalizedPath = _normalizePath(path);
    final fileName = normalizedPath.split(RegExp(r'[\\/]')).last;
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1) {
      return '';
    }
    return fileName.substring(dotIndex);
  }

  String _displayFileName(String path) {
    final normalizedPath = _normalizePath(path);
    return normalizedPath.split(RegExp(r'[\\/]')).last;
  }

  String _cachedAttachmentName(String path) {
    final encodedPath = base64Url.encode(utf8.encode(path)).replaceAll('=', '');
    return '$encodedPath${_fileExtension(path)}';
  }

  Future<Directory> _getAttachmentDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final attachmentDir = Directory(
      '${appDir.path}${Platform.pathSeparator}medical_record_attachments',
    );
    if (!await attachmentDir.exists()) {
      await attachmentDir.create(recursive: true);
    }
    return attachmentDir;
  }

  Future<File> _getCachedAttachmentTarget(String path) async {
    final attachmentDir = await _getAttachmentDirectory();
    return File(
      '${attachmentDir.path}${Platform.pathSeparator}${_cachedAttachmentName(path)}',
    );
  }

  Future<File?> getLocalAttachmentFile(String path) async {
    final normalizedPath = _normalizePath(path);
    if (normalizedPath.isEmpty) {
      return null;
    }

    if (isLocalFilePath(normalizedPath)) {
      final localFile = File(normalizedPath);
      if (await localFile.exists()) {
        return localFile;
      }
      return null;
    }

    final cachedFile = await _getCachedAttachmentTarget(normalizedPath);
    if (await cachedFile.exists()) {
      return cachedFile;
    }

    // Backward compatibility with the previous cache location in the app root.
    final appDir = await getApplicationDocumentsDirectory();
    final legacyFile = File(
      '${appDir.path}${Platform.pathSeparator}${_displayFileName(normalizedPath)}',
    );
    if (await legacyFile.exists()) {
      return legacyFile;
    }

    return null;
  }

  Future<File?> cacheRemoteFile(String path, {String? signedUrl}) async {
    if (isLocalFilePath(path)) {
      return getLocalAttachmentFile(path);
    }

    final existingFile = await getLocalAttachmentFile(path);
    if (existingFile != null) {
      return existingFile;
    }

    final resolvedUrl = signedUrl ?? await getSignedUrl(path);
    final response = await http.get(Uri.parse(resolvedUrl));
    if (response.statusCode != 200) {
      return null;
    }

    final targetFile = await _getCachedAttachmentTarget(path);
    await targetFile.writeAsBytes(response.bodyBytes, flush: true);
    return targetFile;
  }

  Future<List<String>> prepareFilesForSave(List<File> files) async {
    if (!NetworkNotifier.instance.isOffline) {
      return uploadFiles(files);
    }

    final attachmentDir = await _getAttachmentDirectory();
    final stagedPaths = <String>[];

    for (final file in files) {
      final originalName = _displayFileName(file.path);
      final stagedName =
          'offline_${DateTime.now().microsecondsSinceEpoch}_$originalName';
      final stagedFile = File(
        '${attachmentDir.path}${Platform.pathSeparator}$stagedName',
      );
      final copiedFile = await file.copy(stagedFile.path);
      stagedPaths.add(copiedFile.path);
    }

    return stagedPaths;
  }

  Future<String> _uploadLocalAttachment(String localPath) async {
    final userId = currentUserId;
    if (userId == null) {
      throw const AppFailure(
        type: AppFailureType.auth,
        userMessage: 'Please sign in to continue.',
        technicalMessage: 'Missing user.',
        code: 'not_authenticated',
      );
    }

    final file = File(_normalizePath(localPath));
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${_displayFileName(localPath)}';
    final storagePath = '$userId/$fileName';
    await _client.storage.from('medical_docs').upload(storagePath, file);
    return storagePath;
  }

  Future<List<String>> _resolveFileUrlsForSync(List<dynamic> rawPaths) async {
    final resolvedPaths = <String>[];

    for (final rawPath in rawPaths) {
      final path = rawPath.toString();
      if (isLocalFilePath(path)) {
        resolvedPaths.add(await _uploadLocalAttachment(path));
      } else {
        resolvedPaths.add(path);
      }
    }

    return resolvedPaths;
  }

  Future<Box> _getCacheBox() async {
    if (Hive.isBoxOpen(_cacheBoxName)) return Hive.box(_cacheBoxName);
    return await Hive.openBox(_cacheBoxName);
  }

  Future<Box> _getQueueBox() async {
    if (Hive.isBoxOpen(_queueBoxName)) return Hive.box(_queueBoxName);
    return await Hive.openBox(_queueBoxName);
  }

  Future<void> _invalidateRecordsCache(String userId) async {
    final cacheKey = 'medical_records_$userId';
    final box = await _getCacheBox();
    await box.delete(cacheKey);
    await box.delete('${cacheKey}_time');
  }

  /// Public cache invalidation — allows external callers (e.g. the UI) to
  /// force the next [fetchRecords] call to hit the network.
  Future<void> invalidateCache() async {
    final userId = currentUserId;
    if (userId == null) return;
    await _invalidateRecordsCache(userId);
  }

  // --- Real-time subscription for medical_records table ---
  RealtimeChannel subscribeToRecords({
    required String userId,
    required void Function(PostgresChangePayload) onChange,
  }) {
    return _client
        .channel('public:medical_records')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'medical_records',
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
    } catch (e) {
      debugPrint('❌ Failed to remove medical records channel: $e');
    }
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
              payload['file_urls'] = await _resolveFileUrlsForSync(
                payload['file_urls'] as List<dynamic>,
              );
              await _client.from('medical_records').insert(payload);
              break;
            case 'update_record':
              payload['data']['file_urls'] = await _resolveFileUrlsForSync(
                payload['data']['file_urls'] as List<dynamic>,
              );
              await _client
                  .from('medical_records')
                  .update(payload['data'])
                  .eq('id', payload['id'])
                  .eq('user_id', payload['user_id']);
              break;
            case 'delete_record':
              if (payload['filePaths'] != null &&
                  (payload['filePaths'] as List).isNotEmpty) {
                final remotePaths =
                    (payload['filePaths'] as List)
                        .map((path) => path.toString())
                        .where((path) => !isLocalFilePath(path))
                        .toList();
                if (remotePaths.isNotEmpty) {
                  await _client.storage.from('medical_docs').remove(remotePaths);
                }
              }
              await _client.from('medical_records').delete().eq('id', payload['id']).eq('user_id', payload['user_id']);
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
          .order('record_date', ascending: false)
          .timeout(const Duration(seconds: 8));
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
    if (userId == null) {
      throw const AppFailure(
        type: AppFailureType.auth,
        userMessage: 'Please sign in to continue.',
        technicalMessage: 'Missing user.',
        code: 'not_authenticated',
      );
    }

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
      final List<dynamic> decoded =
          cachedData != null ? jsonDecode(cachedData) : <dynamic>[];
      final offlineRecord = Map<String, dynamic>.from(payload)
        ..['id'] = -DateTime.now().millisecondsSinceEpoch.remainder(100000)
        ..['created_at'] = DateTime.now().toIso8601String();
      decoded.insert(0, offlineRecord);
      await box.put(cacheKey, jsonEncode(decoded));
      return;
    }

    // --- PRO FIX: SYNC GUARD ---
    await NetworkNotifier.instance.waitForSync();

    try {
      await _client.from('medical_records').insert(payload);
      await _invalidateRecordsCache(userId);
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to save this record right now.',
      );
    }
  }

  // THE FIX: Upgraded to support Offline Queuing and Optimistic Caching!
  Future<void> lockRecordForReview(int recordId, {DateTime? unlockDate}) async {
    final userId = currentUserId;
    if (userId == null) return;

    final lockedUntilDate =
        unlockDate != null
            ? unlockDate.add(const Duration(days: 1)).toIso8601String()
            : DateTime.now().add(const Duration(days: 30)).toIso8601String();

    if (NetworkNotifier.instance.isOffline) {
      await _queueAction('update_record', {
        'id': recordId,
        'user_id': userId,
        'data': {'locked_until': lockedUntilDate},
      });

      final box = await _getCacheBox();
      final cacheKey = 'medical_records_$userId';
      final cachedData = box.get(cacheKey);
      if (cachedData != null) {
        final List<dynamic> decoded = jsonDecode(cachedData);
        final index = decoded.indexWhere((item) => item['id'] == recordId);
        if (index != -1) {
          decoded[index]['locked_until'] = lockedUntilDate;
          await box.put(cacheKey, jsonEncode(decoded));
        }
      }
      return;
    }

    try {
      await _client
          .from('medical_records')
          .update({'locked_until': lockedUntilDate})
          .eq('id', recordId)
          .eq('user_id', userId);

      await _invalidateRecordsCache(userId);
    } catch (e) {
      debugPrint('Failed to lock record: $e');
    }
  }

  Future<void> unlockRecords(List<int> recordIds) async {
    final userId = currentUserId;
    if (userId == null || NetworkNotifier.instance.isOffline || recordIds.isEmpty) return;

    try {
      await _client
          .from('medical_records')
          .update({'locked_until': null})
          .inFilter('id', recordIds)
          .eq('user_id', userId);
      await _invalidateRecordsCache(userId);
    } catch (e) {
      debugPrint('❌ Failed to unlock medical records: $e');
    }
  }

  Future<void> deleteRecord(MedicalRecord record) async {
    final lockedUntil = record.lockedUntil;
    if (lockedUntil != null && lockedUntil.isAfter(DateTime.now())) {
      final remaining = lockedUntil.difference(DateTime.now());
      throw AppFailure(
        type: AppFailureType.validation,
        userMessage:
            'Record is locked for medical review. Unlocks in ${remaining.inDays} days, ${remaining.inHours % 24} hours.',
        technicalMessage: 'Medical record ${record.id} is review locked.',
        code: 'medical_record_locked',
      );
    }

    final id = record.id;
    final filePaths = record.fileUrls;
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
      await _queueAction('delete_record', {
        'id': id,
        'user_id': userId,
        'filePaths': filePaths,
      });
      final box = await _getCacheBox();
      final cacheKey = 'medical_records_$userId';
      final cachedData = box.get(cacheKey);
      if (cachedData != null) {
        final List<dynamic> decoded = jsonDecode(cachedData);
        decoded.removeWhere((item) => item['id'] == id);
        await box.put(cacheKey, jsonEncode(decoded));
      }
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
          .delete()
          .eq('id', id)
          .eq('user_id', userId);
      await _invalidateRecordsCache(userId);
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
    if (userId == null) {
      throw const AppFailure(
        type: AppFailureType.auth,
        userMessage: 'Please sign in to continue.',
        technicalMessage: 'Missing user.',
        code: 'not_authenticated',
      );
    }

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
      final box = await _getCacheBox();
      final cacheKey = 'medical_records_$userId';
      final cachedData = box.get(cacheKey);
      if (cachedData != null) {
        final List<dynamic> decoded = jsonDecode(cachedData);
        final index = decoded.indexWhere((item) => item['id'] == id);
        if (index != -1) {
          decoded[index] = {
            ...Map<String, dynamic>.from(decoded[index] as Map),
            ...payload,
          };
          await box.put(cacheKey, jsonEncode(decoded));
        }
      }
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
      await _invalidateRecordsCache(userId);
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to update this record right now.',
      );
    }
  }
}



