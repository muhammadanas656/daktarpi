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
  DateTime? _lastFetchTime; // PRO FIX: Throttle Timestamp

  UserProfile? get profile => _profile;
  bool get isLoaded => _loaded;

  String get fullName => _profile?.fullName ?? 'User';
  String? get avatarUrl => _profile?.profilePictureUrl;

  String? get phoneNumber {
    if (_profile?.countryCode != null && _profile?.phoneNumber != null) {
      return '${_profile!.countryCode} ${_profile!.phoneNumber}';
    }
    return _profile?.phoneNumber;
  }

  String get currencySymbol {
    final iso = _profile?.countryIso?.toUpperCase() ?? '';

    switch (iso) {
      case 'PK':
        return 'Rs';
      case 'BD':
        return '৳';
      case 'IN':
        return '₹';
      case 'US':
        return '\$';
      case 'GB':
        return '£';
      case 'DE':
      case 'FR':
      case 'IT':
      case 'ES':
      case 'EU':
        return '€';
      default:
        return '\$';
    }
  }

  /// Load profile from database. Throttled to prevent overfetching on resume.
  Future<void> loadProfile({bool forceRefresh = false}) async {
    final userId = _profileRepo.currentUserId;
    if (userId == null) return;

    // --- PRO FIX: The Throttle Guard ---
    if (!forceRefresh && _loaded && _lastFetchTime != null) {
      final diff = DateTime.now().difference(_lastFetchTime!);
      if (diff.inMinutes < 10) {
        return; // Fast escape: Profile is already fresh in RAM!
      }
    }

    final cachedProfile = await _cacheRepo.loadProfile();
    if (cachedProfile != null && !_loaded) {
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
      _lastFetchTime = DateTime.now(); // Mark fresh
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
    _profile = _profile!.copyWith(
      fullName: fullName ?? _profile!.fullName,
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
