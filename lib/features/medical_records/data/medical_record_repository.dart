import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_failure.dart';
import 'medical_record.dart';

class MedicalRecordRepository {
  final SupabaseClient _client;

  MedicalRecordRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  String? get currentUserId => _client.auth.currentUser?.id;

  /// Fetches medical records for the current user.
  Future<List<MedicalRecord>> fetchRecords() async {
    final user = _client.auth.currentUser;
    final userId = user?.id;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('medical_records')
          .select()
          .eq('user_id', userId)
          .isFilter('deleted_at', null)
          .order('record_date', ascending: false);

      return (response as List)
          .map((e) => MedicalRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to load medical records right now.',
      );
    }
  }

  /// Generates a signed URL for a given file path.
  Future<String> getSignedUrl(String path) async {
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

  /// Uploads files to 'medical_docs' storage bucket and returns their storage paths.
  Future<List<String>> uploadFiles(List<File> files) async {
    final userId = currentUserId;
    if (userId == null) {
      throw const AppFailure(
        type: AppFailureType.auth,
        userMessage: 'Please sign in to continue.',
        technicalMessage: 'Missing current user for medical_docs upload.',
        code: 'not_authenticated',
      );
    }

    List<String> uploadedUrls = [];

    for (var file in files) {
      try {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}';
        final path = '$userId/$fileName';

        await _client.storage.from('medical_docs').upload(path, file);

        // Store the path, not public URL (since bucket is private)
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

  /// Inserts a new medical record into the database.
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
        technicalMessage: 'Missing current user for addRecord.',
        code: 'not_authenticated',
      );
    }

    try {
      await _client.from('medical_records').insert({
        'user_id': userId,
        'record_for': recordFor,
        'record_type': recordType,
        'record_date': recordDate.toIso8601String().split('T')[0],
        'file_urls': fileUrls,
      });
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to save this record right now.',
      );
    }
  }

  /// Deletes a record and its associated files.
  Future<void> deleteRecord(int id, List<String> filePaths) async {
    final userId = currentUserId;
    if (userId == null) {
      throw const AppFailure(
        type: AppFailureType.auth,
        userMessage: 'Please sign in to continue.',
        technicalMessage: 'Missing current user for deleteRecord.',
        code: 'not_authenticated',
      );
    }

    try {
      // 1. Delete files from storage
      if (filePaths.isNotEmpty) {
        await _client.storage.from('medical_docs').remove(filePaths);
      }

      // 2. Soft-delete record from database
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

  /// Updates an existing medical record.
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
        technicalMessage: 'Missing current user for updateRecord.',
        code: 'not_authenticated',
      );
    }

    try {
      await _client
          .from('medical_records')
          .update({
            'record_for': recordFor,
            'record_type': recordType,
            'record_date': recordDate.toIso8601String().split('T')[0],
            'file_urls': fileUrls,
          })
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
