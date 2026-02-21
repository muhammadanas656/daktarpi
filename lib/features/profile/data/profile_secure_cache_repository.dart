import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'user_profile.dart';

class ProfileSecureCacheRepository {
  static const String _storageKey = 'profile_cache_v1';

  final FlutterSecureStorage _storage;

  ProfileSecureCacheRepository({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  Future<UserProfile?> loadProfile() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    return UserProfile.fromJson(decoded);
  }

  Future<void> saveProfile(UserProfile profile) {
    return _storage.write(
      key: _storageKey,
      value: jsonEncode(profile.toJson()),
    );
  }

  Future<void> clear() => _storage.delete(key: _storageKey);
}
