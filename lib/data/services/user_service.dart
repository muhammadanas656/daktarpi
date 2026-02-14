import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserService {
  // 1. Singleton Pattern
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  // 2. Memory Cache
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

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _isFetching = true;

    try {
      final data =
          await Supabase.instance.client
              .from('profiles')
              .select('full_name, profile_picture_url, phone_number')
              .eq('id', user.id)
              .maybeSingle();

      if (data != null) {
        _cachedProfile = data;
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
