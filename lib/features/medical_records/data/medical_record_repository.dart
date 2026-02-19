import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'medical_record.dart';

class Requires2FAException implements Exception {}

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

    // --- 2FA SESSION CHECK ---
    final is2FAEnabled = user?.appMetadata['is_2fa_enabled'] == true;
    final aal = user?.appMetadata['aal'];

    // If 2FA is enabled but session is only Level 1 (Password), block access.
    // This handles the "Session Expired" edge case.
    if (is2FAEnabled && (aal == 'aal1' || aal == null)) {
      throw Requires2FAException();
    }

    try {
      final response = await _client
          .from('medical_records')
          .select()
          .eq('user_id', userId)
          .order('record_date', ascending: false);

      return (response as List)
          .map((e) => MedicalRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch records: $e');
    }
  }

  /// Generates a signed URL for a given file path.
  Future<String> getSignedUrl(String path) async {
    return await _client.storage.from('medical_docs').createSignedUrl(path, 60 * 60); // 1 hour expiry
  }

  /// Uploads files to 'medical_docs' storage bucket and returns their storage paths.
  Future<List<String>> uploadFiles(List<File> files) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('User not logged in');

    List<String> uploadedUrls = [];

    for (var file in files) {
      try {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}';
        final path = '$userId/$fileName';

        await _client.storage.from('medical_docs').upload(path, file);
        
        // Store the path, not public URL (since bucket is private)
        uploadedUrls.add(path);
      } catch (e) {
        // Continue uploading other files even if one fails? 
        // Or throw? Let's throw for now to ensure integrity.
        throw Exception('Failed to upload file: $e');
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
    if (userId == null) throw Exception('User not logged in');

    try {
      await _client.from('medical_records').insert({
        'user_id': userId,
        'record_for': recordFor,
        'record_type': recordType,
        'record_date': recordDate.toIso8601String().split('T')[0],
        'file_urls': fileUrls,
      });
    } catch (e) {
      throw Exception('Failed to add record: $e');
    }
  }

  /// Deletes a record and its associated files.
  Future<void> deleteRecord(int id, List<String> filePaths) async {
    try {
      // 1. Delete files from storage
      if (filePaths.isNotEmpty) {
        await _client.storage.from('medical_docs').remove(filePaths);
      }

      // 2. Delete record from database
      await _client.from('medical_records').delete().eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete record: $e');
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
    if (userId == null) throw Exception('User not logged in');

    try {
      await _client.from('medical_records').update({
        'record_for': recordFor,
        'record_type': recordType,
        'record_date': recordDate.toIso8601String().split('T')[0],
        'file_urls': fileUrls,
      }).eq('id', id);
    } catch (e) {
      throw Exception('Failed to update record: $e');
    }
  }
}
