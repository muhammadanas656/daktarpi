import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../data/doctor_repository.dart';

class FavoritesNotifier extends ChangeNotifier with WidgetsBindingObserver {
  FavoritesNotifier._() {
    WidgetsBinding.instance.addObserver(this);
  }
  static final FavoritesNotifier instance = FavoritesNotifier._();

  final _doctorRepo = DoctorRepository();

  // PRO FIX: Now holds the FULL doctor objects, completely replacing FutureBuilders!
  List<Map<String, dynamic>> _favoriteDoctors = [];
  Set<int> _favoriteIds = {};
  bool _loaded = false;

  List<Map<String, dynamic>> get favoriteDoctors => _favoriteDoctors;
  bool get isLoaded => _loaded;

  bool isFavorite(int doctorId) => _favoriteIds.contains(doctorId);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // PRO FIX: Force an immediate sync of any pending "Favorite" actions when app backgrounds
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _doctorRepo.syncOfflineQueue();
    }
  }

  Future<void> _updateLocalCache() async {
    final userId = _doctorRepo.currentUserId;
    if (userId == null) return;
    try {
      // PRO FIX: Immediate flush to Hive to prevent data wipe on unexpected close
      if (!Hive.isBoxOpen('doctor_cache')) {
        await Hive.openBox('doctor_cache');
      }
      final box = Hive.box('doctor_cache');
      await box.put('favorites_$userId', jsonEncode(_favoriteDoctors));
      await box.put('favorites_${userId}_time', DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('Failed to update local favorites cache: $e');
    }
  }

  Future<void> loadFavorites() async {
    // PRO FIX: If we are already loaded, DO NOT fetch again and wipe RAM.
    if (_loaded) return; 

    final userId = _doctorRepo.currentUserId;
    if (userId == null) return;

    try {
      _favoriteDoctors = await _doctorRepo.fetchFavoriteDoctors();
      _favoriteIds = _favoriteDoctors.map((d) => d['id'] as int).toSet();
      _loaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('FavoritesNotifier: error loading favorites: $e');
    }
  }

  // PRO FIX: Toggle now accepts the full doctor object to instantly populate the MyDoctorsScreen!
  void toggle(Map<String, dynamic> doctor) {
    final userId = _doctorRepo.currentUserId;
    if (userId == null) return;

    final doctorId = doctor['id'] as int;
    final wasFavorite = _favoriteIds.contains(doctorId);

    // 1. Optimistic UI (Instant)
    if (wasFavorite) {
      _favoriteIds.remove(doctorId);
      _favoriteDoctors.removeWhere((d) => d['id'] == doctorId);
    } else {
      _favoriteIds.add(doctorId);
      _favoriteDoctors.insert(0, doctor); // Puts the newest favorite at the top
    }
    notifyListeners();

    // PRO FIX: Immediate Block Flush
    unawaited(_updateLocalCache());

    // 2. Background Sync
    unawaited(
      _doctorRepo.toggleFavorite(doctorId, userId, wasFavorite).catchError((e) {
        // Revert if database explicitly rejects it
        if (wasFavorite) {
          _favoriteIds.add(doctorId);
          _favoriteDoctors.insert(0, doctor);
        } else {
          _favoriteIds.remove(doctorId);
          _favoriteDoctors.removeWhere((d) => d['id'] == doctorId);
        }
        notifyListeners();
        unawaited(_updateLocalCache());
      }),
    );
  }

  void clear() {
    _favoriteDoctors = [];
    _favoriteIds = {};
    _loaded = false;
    notifyListeners();
  }
}

