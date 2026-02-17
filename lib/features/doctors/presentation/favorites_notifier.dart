import 'package:flutter/foundation.dart';
import '../data/doctor_repository.dart';

/// Singleton ChangeNotifier that holds the set of favorite doctor IDs.
/// All screens listen to this instead of maintaining their own sets.
class FavoritesNotifier extends ChangeNotifier {
  FavoritesNotifier._();
  static final FavoritesNotifier instance = FavoritesNotifier._();

  final _doctorRepo = DoctorRepository();
  Set<int> _favoriteIds = {};
  bool _loaded = false;

  Set<int> get favoriteIds => _favoriteIds;
  bool get isLoaded => _loaded;

  bool isFavorite(int doctorId) => _favoriteIds.contains(doctorId);

  /// Synchronize a single doctor's favorite status from an external source
  /// (e.g. detailed screen fetch) without triggering a DB call.
  void syncSingle(int doctorId, bool isFavorite) {
    if (isFavorite) {
      if (_favoriteIds.add(doctorId)) notifyListeners();
    } else {
      if (_favoriteIds.remove(doctorId)) notifyListeners();
    }
  }

  /// Load favorites from the database. Safe to call multiple times —
  /// subsequent calls refresh the set.
  Future<void> loadFavorites() async {
    final userId = _doctorRepo.currentUserId;
    if (userId == null) return;

    try {
      _favoriteIds = await _doctorRepo.fetchFavoriteIds(userId);
      _loaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('FavoritesNotifier: error loading favorites: $e');
    }
  }

  /// Toggle a doctor's favorite status with optimistic UI update.
  /// Reverts on error.
  Future<void> toggle(int doctorId) async {
    final userId = _doctorRepo.currentUserId;
    if (userId == null) return;

    final wasFavorite = _favoriteIds.contains(doctorId);

    // 1. Optimistic update
    if (wasFavorite) {
      _favoriteIds.remove(doctorId);
    } else {
      _favoriteIds.add(doctorId);
    }
    notifyListeners();

    try {
      // 2. Database sync
      await _doctorRepo.toggleFavorite(
        doctorId, userId, wasFavorite,
      );
    } catch (e) {
      debugPrint('FavoritesNotifier: error toggling favorite: $e');
      // 3. Revert on error
      if (wasFavorite) {
        _favoriteIds.add(doctorId);
      } else {
        _favoriteIds.remove(doctorId);
      }
      notifyListeners();
    }
  }

  /// Clear state on logout.
  void clear() {
    _favoriteIds = {};
    _loaded = false;
    notifyListeners();
  }
}
