import 'dart:io';
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
  // --- PATIENT CATEGORIES LOGIC ---

  Future<List<String>> getPatientCategories(String userId) async {
    try {
      final response =
          await _client
              .from('profiles')
              .select('saved_patient_categories')
              .eq('id', userId)
              .maybeSingle();

      if (response != null && response['saved_patient_categories'] != null) {
        final list = response['saved_patient_categories'] as List<dynamic>;
        return list.map((e) => e.toString()).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<void> savePatientCategory(String category) async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      final currentCategories = await getPatientCategories(userId);
      if (!currentCategories.contains(category)) {
        currentCategories.add(category);
        await _client
            .from('profiles')
            .update({'saved_patient_categories': currentCategories})
            .eq('id', userId);
      }
    } catch (_) {} // Fails silently to not disrupt booking flow
  }

  Future<void> removePatientCategory(String category) async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      final currentCategories = await getPatientCategories(userId);
      currentCategories.remove(category);
      await _client
          .from('profiles')
          .update({'saved_patient_categories': currentCategories})
          .eq('id', userId);
    } catch (e) {
      throw AppFailure.fromError(
        e,
        fallbackUserMessage: 'Could not remove category.',
      );
    }
  }
}
