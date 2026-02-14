import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_profile.dart';

class ProfileRepository {
  final SupabaseClient _client;

  ProfileRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Returns the current user's ID, or null if not logged in.
  String? get currentUserId => _client.auth.currentUser?.id;

  /// Signs the current user out.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<UserProfile?> getProfile(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        return UserProfile.fromJson(response);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch profile: $e');
    }
  }

  Future<String> uploadProfilePicture(String userId, File imageFile) async {
    try {
      final fileExt = imageFile.path.split('.').last;
      final fileName = '$userId/avatar.$fileExt';

      await _client.storage.from('profile_pictures').upload(
            fileName,
            imageFile,
            fileOptions: const FileOptions(upsert: true),
          );

      final String publicUrl =
          _client.storage.from('profile_pictures').getPublicUrl(fileName);

      // Append timestamp to force refresh
      return Uri.parse(publicUrl).replace(
        queryParameters: {
          't': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      ).toString();
    } on StorageException catch (e) {
      throw Exception('Storage Error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  Future<void> deleteOldProfilePic(String userId, String? currentUrl) async {
    if (currentUrl != null && currentUrl.contains('profile_pictures')) {
      try {
        final uri = Uri.parse(currentUrl);
        final bucketIndex = uri.pathSegments.indexOf('profile_pictures');
        if (bucketIndex != -1 && bucketIndex + 2 < uri.pathSegments.length) {
          final pathToDelete =
              uri.pathSegments.sublist(bucketIndex + 1).join('/');
          await _client.storage.from('profile_pictures').remove([pathToDelete]);
          return;
        }
      } catch (e) {
        // Ignore parsing errors, fallback to listing
      }
    }

    try {
      final List<FileObject> objects =
          await _client.storage.from('profile_pictures').list(path: userId);
      if (objects.isNotEmpty) {
        final List<String> paths =
            objects.map((e) => '$userId/${e.name}').toList();
        await _client.storage.from('profile_pictures').remove(paths);
      }
    } catch (e) {
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
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }
}
