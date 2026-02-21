import 'dart:async';

import 'package:flutter/foundation.dart';
import '../data/user_profile.dart';
import '../data/profile_repository.dart';
import '../data/profile_secure_cache_repository.dart';

/// Singleton ChangeNotifier that holds the current user's profile.
/// All screens listen to this instead of fetching profile data independently.
class ProfileNotifier extends ChangeNotifier {
  ProfileNotifier._();
  static final ProfileNotifier instance = ProfileNotifier._();

  final _profileRepo = ProfileRepository();
  final _cacheRepo = ProfileSecureCacheRepository();
  UserProfile? _profile;
  bool _loaded = false;

  UserProfile? get profile => _profile;
  bool get isLoaded => _loaded;

  String get fullName => _profile?.fullName ?? 'User';
  String? get avatarUrl => _profile?.profilePictureUrl;
  String? get phoneNumber => _profile?.phoneNumber;

  String get currencySymbol {
    final loc = _profile?.location?.toLowerCase() ?? '';
    if (loc.contains('bangladesh') || loc.contains(' bd')) return '৳';
    if (loc.contains('pakistan') || loc.contains(' pk')) return 'Rs';
    if (loc.contains('india') || loc.contains(' in')) return '₹';
    if (loc.contains('united kingdom') || loc.contains(' uk')) return '£';
    if (loc.contains('euro') ||
        loc.contains('germany') ||
        loc.contains('france') ||
        loc.contains('italy') ||
        loc.contains('spain')) {
      return '€';
    }
    return '\$';
  }

  /// Load profile from database. Safe to call multiple times.
  Future<void> loadProfile() async {
    final userId = _profileRepo.currentUserId;
    if (userId == null) return;

    final cachedProfile = await _cacheRepo.loadProfile();
    if (cachedProfile != null) {
      _profile = cachedProfile;
      _loaded = true;
      notifyListeners();
    }

    try {
      _profile = await _profileRepo.getProfile(userId);
      if (_profile != null) {
        await _cacheRepo.saveProfile(_profile!);
      }
      _loaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('ProfileNotifier: error loading profile: $e');
    }
  }

  /// Called after profile edits are saved to update all listeners immediately.
  void updateProfile(UserProfile updated) {
    _profile = updated;
    unawaited(_cacheRepo.saveProfile(updated));
    notifyListeners();
  }

  /// Update just the name and avatar (lightweight update after profile edit).
  void updateNameAndAvatar({String? fullName, String? avatarUrl}) {
    if (_profile == null) return;
    _profile = UserProfile(
      id: _profile!.id,
      fullName: fullName ?? _profile!.fullName,
      phoneNumber: _profile!.phoneNumber,
      dateOfBirth: _profile!.dateOfBirth,
      location: _profile!.location,
      profilePictureUrl: avatarUrl ?? _profile!.profilePictureUrl,
      updatedAt: DateTime.now(),
    );
    unawaited(_cacheRepo.saveProfile(_profile!));
    notifyListeners();
  }

  /// Clear state on logout.
  void clear() {
    _profile = null;
    _loaded = false;
    unawaited(_cacheRepo.clear());
    notifyListeners();
  }
}
