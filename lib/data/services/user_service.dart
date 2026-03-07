import 'package:flutter/foundation.dart';
import '../../features/profile/data/profile_repository.dart';

class UserService {
  // 1. Singleton Pattern
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  // 2. Memory Cache
  final ProfileRepository _profileRepository = ProfileRepository();
  Map<String, dynamic>? _cachedProfile;
  bool _isFetching = false;

  // 3. Safe Getters (UI uses these)
  // These return default values if cache is empty, preventing null errors.
  String get name => _cachedProfile?['full_name'] ?? "Handwerker";
  String get phone => _cachedProfile?['phone_number'] ?? "01303-527300";
  String? get avatarUrl => _cachedProfile?['profile_picture_url'];

  bool get hasData => _cachedProfile != null;

  /// Fetches profile from Supabase
  Future<void> fetchUserProfile() async {
    if (hasData || _isFetching) return;

    final userId = _profileRepository.currentUserId;
    if (userId == null) return;

    _isFetching = true;

    try {
      final profile = await _profileRepository.getProfile(userId);
      if (profile != null) {
        _cachedProfile = {
          'full_name': profile.fullName,
          'profile_picture_url': profile.profilePictureUrl,
          'phone_number':
              (profile.countryCode != null && profile.phoneNumber != null)
                  ? '${profile.countryCode} ${profile.phoneNumber}'
                  : profile.phoneNumber,
        };
      }
    } catch (e) {
      debugPrint("UserService Error: $e");
    } finally {
      _isFetching = false;
    }
  }

  /// Clears data on Logout
  void clearCache() {
    _cachedProfile = null;
    _isFetching = false;
  }
}
