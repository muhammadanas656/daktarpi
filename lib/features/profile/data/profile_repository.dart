import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_failure.dart';
import 'user_profile.dart';

class ProfileRepository {
  final SupabaseClient _client;

  ProfileRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  /// Returns the current user's ID, or null if not logged in.
  String? get currentUserId => _client.auth.currentUser?.id;

  /// Returns the current user's email, or null if not logged in.
  String? get currentUserEmail => _client.auth.currentUser?.email;

  /// Signs the current user out.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<UserProfile?> getProfile(String userId) async {
    try {
      final response =
          await _client
              .from('profiles')
              .select()
              .eq('id', userId)
              .maybeSingle();

      if (response != null) {
        return UserProfile.fromJson(response);
      }
      return null;
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to load profile right now.',
      );
    }
  }

  Future<String> uploadProfilePicture(String userId, File imageFile) async {
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

      // Append timestamp to force refresh
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

  Future<void> deleteOldProfilePic(String userId, String? currentUrl) async {
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
        // Ignore parsing errors, fallback to listing
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
      // Ignore cleanup errors
    }
  }

  Future<void> updateProfile(UserProfile profile) async {
    try {
      await _client.from('profiles').upsert(profile.toJson());

      // Update Auth Metadata as well (optional but good practice)
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

  // --- SAVED PATIENTS (RELATIONAL) LOGIC ---

  // 1. Caching Variables
  List<Map<String, dynamic>> _cachedSavedPatients = [];
  DateTime? _lastSavedPatientsFetch;
  static const _cacheDuration = Duration(minutes: 5);

  bool _isCacheValid(DateTime? lastFetch) {
    if (lastFetch == null) return false;
    return DateTime.now().difference(lastFetch) < _cacheDuration;
  }

  /// Fetches all saved patients for the user as a list of Maps
  Future<List<Map<String, dynamic>>> getSavedPatients(
    String userId, {
    bool forceRefresh = false,
  }) async {
    // 2. Return cached data instantly if valid
    if (!forceRefresh &&
        _isCacheValid(_lastSavedPatientsFetch) &&
        _cachedSavedPatients.isNotEmpty) {
      return _cachedSavedPatients;
    }

    try {
      final response = await _client
          .from('saved_patients')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: true);

      final data = List<Map<String, dynamic>>.from(response);

      // 3. Save to cache
      _cachedSavedPatients = data;
      _lastSavedPatientsFetch = DateTime.now();

      return data;
    } catch (e) {
      debugPrint("Error fetching saved patients: $e");
      return [];
    }
  }

  /// Upserts (Inserts or Updates) a patient category
  Future<void> savePatientDetails(Map<String, dynamic> patientData) async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      patientData['user_id'] = userId;

      await _client
          .from('saved_patients')
          .upsert(patientData, onConflict: 'user_id, relation');

      // 4. INVALIDATE CACHE: Force a fresh fetch next time so the new category shows!
      _lastSavedPatientsFetch = null;
    } catch (e) {
      debugPrint("Error saving patient details: $e");
    }
  }

  /// Deletes a specific patient category
  Future<void> removePatientCategory(String relation) async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      await _client
          .from('saved_patients')
          .delete()
          .eq('user_id', userId)
          .eq('relation', relation);

      // 4. INVALIDATE CACHE: Force a fresh fetch next time
      _lastSavedPatientsFetch = null;
    } catch (e) {
      throw AppFailure.fromError(
        e,
        fallbackUserMessage: 'Could not remove category.',
      );
    }
  }
}
