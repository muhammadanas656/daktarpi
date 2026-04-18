import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../profile/presentation/profile_notifier.dart';
import '../data/doctor_repository.dart';

class DoctorsNotifier extends ChangeNotifier {
  DoctorsNotifier._();
  static final DoctorsNotifier instance = DoctorsNotifier._();

  final _doctorRepo = DoctorRepository();
  final _profileNotifier = ProfileNotifier.instance;

  List<Map<String, dynamic>> _doctors = [];
  List<Map<String, dynamic>> _hospitals = [];
  List<Map<String, dynamic>> _clinics = [];

  // PRO FIX: Centralized data points for HomeScreen and Specialty Lists
  List<Map<String, dynamic>> _homePopularDoctors = [];
  List<Map<String, dynamic>> _explorePopularDoctors = [];
  List<Map<String, dynamic>> _homeFeaturedDoctors = [];
  List<Map<String, dynamic>> _exploreFeaturedDoctors = [];
  List<Map<String, dynamic>> _specialties = [];

  bool _isLoading = false;
  int _activeRequests = 0; // Concurrency lock

  Future<void> prehydrateHomeFeed() async {
    final countryIso = _profileNotifier.profile?.countryIso ?? 'US';
    
    final specials = await _doctorRepo.getDirectCache('specialties_list');
    if (specials != null && _specialties.isEmpty) _specialties = specials;

    final pops = await _doctorRepo.getDirectCache('popular_docs_' + countryIso + '_fAll');
    if (pops != null && _homePopularDoctors.isEmpty) _homePopularDoctors = pops;

    final feats = await _doctorRepo.getDirectCache('featured_docs_' + countryIso + '_fAll');
    if (feats != null && _homeFeaturedDoctors.isEmpty) _homeFeaturedDoctors = feats;
    
    notifyListeners();
  }

  void _startNetworkRequest() {
    _activeRequests++;
    _isLoading = true;
    notifyListeners();
  }

  void _endNetworkRequest() {
    _activeRequests--;
    if (_activeRequests <= 0) {
      _activeRequests = 0;
      _isLoading = false;
      notifyListeners();
    }
  }

  // Track parameters to prevent re-fetching the same data
  String _lastQuery = '';
  String _lastFilter = 'All';
  double? _lastMaxRadiusKm;

  List<Map<String, dynamic>> get doctors => _doctors;
  List<Map<String, dynamic>> get hospitals => _hospitals;
  List<Map<String, dynamic>> get clinics => _clinics;

  List<Map<String, dynamic>> get homePopularDoctors => _homePopularDoctors;
  List<Map<String, dynamic>> get explorePopularDoctors => _explorePopularDoctors;
  List<Map<String, dynamic>> get homeFeaturedDoctors => _homeFeaturedDoctors;
  List<Map<String, dynamic>> get exploreFeaturedDoctors => _exploreFeaturedDoctors;
  List<Map<String, dynamic>> get specialties => _specialties;

  bool get isLoading => _isLoading;

  /// Applies a guaranteed client-side sort overlay on top of whatever the RPC returned.
  /// This ensures consistent ordering regardless of backend category combinations.
  List<Map<String, dynamic>> _sorted(List<Map<String, dynamic>> list, String filter) {
    final out = List<Map<String, dynamic>>.from(list);
    if (filter == 'All') {
      out.sort((a, b) =>
          ((b['views_count'] as int?) ?? 0).compareTo((a['views_count'] as int?) ?? 0));
    } else if (filter == 'Top Rated') {
      out.sort((a, b) {
        final ra = (a['rating'] as num?)?.toDouble() ?? 0.0;
        final rb = (b['rating'] as num?)?.toDouble() ?? 0.0;
        return rb.compareTo(ra);
      });
    }
    // Nearest / Available Today: trust the RPC's spatial/temporal ordering.
    return out;
  }

  /// Returns a strictly filtered list if local density meets the threshold.
  List<Map<String, dynamic>> getStrictPopularList({
    required List<Map<String, dynamic>> rawDoctors,
    required double? activeRadius,
    required double highlightRange,
    required double threshold,
  }) {
    // 1. If we are within the local range limit...
    final bool isLocalZone = (activeRadius ?? 500.0) <= highlightRange;

    // 2. Count how many high-quality (Popular or Rated) doctors are in the list
    final localPopular = rawDoctors.where((doc) {
      final rating = double.tryParse(doc['rating']?.toString() ?? '0') ?? 0.0;
      return rating > 0.0 || doc['is_popular'] == true;
    }).toList();

    // 3. THE TRIGGER: If we are local AND have enough doctors, show ONLY the popular ones.
    if (isLocalZone && localPopular.length >= threshold) {
      return localPopular;
    }

    // 4. Otherwise, return the full list as "Recommended"
    return rawDoctors;
  }

  /// Delegates to DoctorRepository. Lets SmartFilterBar call this without needing to import
  /// DoctorRepository directly, avoiding circular imports.
  Future<double> fetchSmartClusterRadius({
    required double userLat,
    required double userLng,
    required String countryIso,
  }) {
    return _doctorRepo.fetchSmartClusterRadius(
      userLat: userLat,
      userLng: userLng,
      countryIso: countryIso,
    );
  }

  // --- PLATFORM LIMIT PASSTHROUGHS ---
  Future<double> fetchMaxPlatformRadius() => _doctorRepo.fetchMaxPlatformRadius();
  Future<double> fetchMinPlatformRadius() => _doctorRepo.fetchMinPlatformRadius();
  Future<double> fetchFeaturedPlatformRadius() => _doctorRepo.fetchFeaturedPlatformRadius();
  Future<double> fetchPopularHighlightRange() => _doctorRepo.fetchPopularHighlightRange();
  Future<int> fetchTargetClusterSize() => _doctorRepo.fetchTargetClusterSize();
  Future<double> fetchPopularThreshold() => _doctorRepo.fetchPopularThreshold();
  Future<int> fetchHomePopularLimit() => _doctorRepo.fetchHomePopularLimit();
  Future<int> fetchExplorePopularLimit() => _doctorRepo.fetchExplorePopularLimit();
  Future<int> fetchHomeFeaturedLimit() => _doctorRepo.fetchHomeFeaturedLimit();
  Future<int> fetchExploreFeaturedLimit() => _doctorRepo.fetchExploreFeaturedLimit();

  // THE FIX: Sort utility pushing highlighted local doctors to top of feed
  List<Map<String, dynamic>> sortDoctorsByHighlight(
    List<Map<String, dynamic>> doctors,
    double? userLat,
    double? userLng,
    double highlightRange,
  ) {
    final list = List<Map<String, dynamic>>.from(doctors);
    list.sort((a, b) {
      final aRating = double.tryParse(a['rating']?.toString() ?? '0') ?? 0.0;
      final aPopular = a['is_popular'] == true;
      final aDist = calculateDoctorDistance(a, userLat, userLng);
      final aHigh = (aDist <= highlightRange) && (aRating > 0 || aPopular);

      final bRating = double.tryParse(b['rating']?.toString() ?? '0') ?? 0.0;
      final bPopular = b['is_popular'] == true;
      final bDist = calculateDoctorDistance(b, userLat, userLng);
      final bHigh = (bDist <= highlightRange) && (bRating > 0 || bPopular);

      if (aHigh && !bHigh) return -1;
      if (!aHigh && bHigh) return 1;
      return 0;
    });
    return list;
  }

  // THE FIX: Per-Card Distance Calculator (Matches SQL exactly)
  double calculateDoctorDistance(
    Map<String, dynamic> doctor,
    double? userLat,
    double? userLng,
  ) {
    if (userLat == null || userLng == null) return double.infinity;

    final clinicsList = doctor['doctor_clinics'] as List<dynamic>?;
    if (clinicsList == null || clinicsList.isEmpty) return double.infinity;

    double minDistance = double.infinity;
    const R = 6371; // km

    for (final dc in clinicsList) {
      final clinic = dc['clinics'];
      if (clinic != null &&
          clinic['latitude'] != null &&
          clinic['longitude'] != null) {
        final lat = (clinic['latitude'] as num).toDouble();
        final lng = (clinic['longitude'] as num).toDouble();

        final dLat = (lat - userLat) * math.pi / 180.0;
        final dLon = (lng - userLng) * math.pi / 180.0;
        final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
            math.cos(userLat * math.pi / 180.0) *
                math.cos(lat * math.pi / 180.0) *
                math.sin(dLon / 2) *
                math.sin(dLon / 2);
        final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

        final distance = 1.3 * (R * c); // 1.3x synced driving math
        if (distance < minDistance) minDistance = distance;
      }
    }
    return minDistance;
  }

  // GPS Hardware Cache
  Position? _cachedPosition;
  DateTime? _lastPosTime;

  Future<Position?> getUserPosition() async {
    // 60-second Micro-Cache to prevent redundant hardware spin-ups
    if (_cachedPosition != null && _lastPosTime != null) {
      if (DateTime.now().difference(_lastPosTime!).inSeconds < 60) {
        return _cachedPosition;
      }
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;
      
      _cachedPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _lastPosTime = DateTime.now();
      
      return _cachedPosition;
    } catch (e) {
      debugPrint("Location sorting failed -> $e");
      return null;
    }
  }

  /// Fetch all required data once. Safe to be called by multiple screens.
  Future<void> fetchDoctors({
    String query = '',
    String filter = 'All',
    double? maxRadiusKm, // Used for boundary constraint
    bool forceRefresh = false,
  }) async {
    // Optimization: Skip fetching if the exact constraints are already hot in RAM, unless forced
    if (!forceRefresh &&
        _lastQuery == query &&
        _lastFilter == filter &&
        _lastMaxRadiusKm == maxRadiusKm &&
        _doctors.isNotEmpty) {
      return;
    }

    _lastQuery = query;
    _lastFilter = filter;
    _lastMaxRadiusKm = maxRadiusKm;
    _isLoading = true;
    notifyListeners();

    try {
      double? userLat;
      double? userLng;

      // GPS is needed for location-based sorting AND whenever a spatial boundary (maxRadiusKm) is enforced
      if (maxRadiusKm != null || filter == 'Nearest' || filter == 'Hospital' || filter == 'Clinic' || filter == 'Available Today') {
        final pos = await getUserPosition();
        if (pos != null) {
          userLat = pos.latitude;
          userLng = pos.longitude;
        }
      }

      final userLocation = _profileNotifier.profile?.location;
      final countryIso = _profileNotifier.profile?.countryIso;

      final results = await Future.wait([
        _doctorRepo.fetchAllDoctors(
          query: query,
          filterType: filter,
          maxRadiusKm: maxRadiusKm, // <--- Passes dynamic boundary payload
          userLat: userLat,
          userLng: userLng,
          userLocation: userLocation,
          countryIso: countryIso,
          forceRefresh: forceRefresh,
        ),
        _doctorRepo.fetchHospitals(
          query: query,
          userLat: userLat,
          userLng: userLng,
          maxRadiusKm: maxRadiusKm,
        ),
        _doctorRepo.fetchClinicsList(
          query: query,
          userLat: userLat,
          userLng: userLng,
          maxRadiusKm: maxRadiusKm,
        ),
      ]);

      if (_lastQuery == query && _lastFilter == filter) {
        _doctors = _sorted(results[0] as List<Map<String, dynamic>>, filter);
        _hospitals = results[1] as List<Map<String, dynamic>>;
        _clinics = results[2] as List<Map<String, dynamic>>;
      }
    } catch (e) {
      debugPrint("DoctorsNotifier Fetch Error: $e");
    } finally {
      if (_lastQuery == query && _lastFilter == filter) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // --- Centralized Sub-Fetchers (RPC-Powered) ---

  Future<void> fetchPopularDoctors({
    String query = '',
    String filter = 'All',
    double? maxRadiusKm,
    int? limit,
    bool forceRefresh = false,
    bool isHomeFeed = false,
  }) async {
    final currentList = isHomeFeed ? _homePopularDoctors : _explorePopularDoctors;
    
    // Only block initial duplicate network calls if the vault explicitly has exactly what we need
    if (!forceRefresh && currentList.isNotEmpty && query.isEmpty && filter == 'All' && currentList.length > 5 && maxRadiusKm == null) {
      // Defer to repository cache checking instead of explicitly returning here unless we are 100% sure it's the base query
    }

    if (currentList.isEmpty) {
      _startNetworkRequest();
    } else {
      _startNetworkRequest();
    }

    try {
      final userLocation = _profileNotifier.profile?.location;
      final countryIso = _profileNotifier.profile?.countryIso;

      double? userLat;
      double? userLng;
      if (maxRadiusKm != null || filter == 'Nearest' || filter == 'Available Today') {
        final pos = await getUserPosition();
        if (pos != null) {
          userLat = pos.latitude;
          userLng = pos.longitude;
        }
      }

      var fetchedData = await _doctorRepo.fetchPopularDoctors(
        query: query,
        filterType: filter,
        maxRadiusKm: maxRadiusKm, // Pass to DB wrapper
        limit: limit,
        forceRefresh: forceRefresh,
        userLocation: userLocation,
        countryIso: countryIso,
        userLat: userLat,
        userLng: userLng,
        onFreshData: (fresh) {
          final sorted = _sorted(fresh, filter);
          if (isHomeFeed) {
            _homePopularDoctors = sorted;
          } else {
            _explorePopularDoctors = sorted;
          }
          notifyListeners();
        },
      );

      // THE FIX: Completely removed the national fallback block here!
      // The app will strictly obey the radius.

      final sorted = _sorted(fetchedData, filter);
      if (isHomeFeed) {
        _homePopularDoctors = sorted;
      } else {
        _explorePopularDoctors = sorted;
      }
    } catch (e) {
      debugPrint("DoctorsNotifier Popular Fetch Error: $e");
    } finally {
      _endNetworkRequest();
    }
  }

  Future<void> fetchFeaturedDoctors({
    String query = '',
    String filter = 'All',
    double? maxRadiusKm,
    int? limit,
    bool forceRefresh = false,
    bool isHomeFeed = false,
  }) async {
    final currentList = isHomeFeed ? _homeFeaturedDoctors : _exploreFeaturedDoctors;
    
    // Only block initial duplicate network calls if the vault explicitly has exactly what we need
    if (!forceRefresh && currentList.isNotEmpty && query.isEmpty && filter == 'All' && currentList.length > 5 && maxRadiusKm == null) {
      // Defer to repository cache checking instead of explicitly returning here unless we are 100% sure it's the base query
    }

    if (currentList.isEmpty) {
      _startNetworkRequest();
    } else {
      _startNetworkRequest();
    }

    try {
      final userLocation = _profileNotifier.profile?.location;
      final countryIso = _profileNotifier.profile?.countryIso;

      double? userLat;
      double? userLng;
      if (maxRadiusKm != null || filter == 'Nearest' || filter == 'Available Today') {
        final pos = await getUserPosition();
        if (pos != null) {
          userLat = pos.latitude;
          userLng = pos.longitude;
        }
      }

      var fetchedData = await _doctorRepo.fetchFeaturedDoctors(
        query: query,
        filterType: filter,
        maxRadiusKm: maxRadiusKm,
        limit: limit,
        forceRefresh: forceRefresh,
        userLocation: userLocation,
        countryIso: countryIso,
        userLat: userLat,
        userLng: userLng,
        onFreshData: (fresh) {
          final sorted = _sorted(fresh, filter);
          if (isHomeFeed) {
            _homeFeaturedDoctors = sorted;
          } else {
            _exploreFeaturedDoctors = sorted;
          }
          notifyListeners();
        },
      );

      // THE FIX: Completely removed the national fallback block here!

      final sorted = _sorted(fetchedData, filter);
      if (isHomeFeed) {
        _homeFeaturedDoctors = sorted;
      } else {
        _exploreFeaturedDoctors = sorted;
      }
    } catch (e) {
      debugPrint("DoctorsNotifier Featured Fetch Error: $e");
    } finally {
      _endNetworkRequest();
    }
  }



  Future<void> fetchSpecialties({bool forceRefresh = false}) async {
    // PRO FIX: The RAM Cache Guard!
    if (!forceRefresh && _specialties.isNotEmpty) return;

    if (_specialties.isEmpty) {
      _startNetworkRequest();
    } else {
      // If we are just silently refreshing in the background
      _startNetworkRequest(); 
    }
    
    try {
      _specialties = await _doctorRepo.fetchSpecialties(
        forceRefresh: forceRefresh,
        onFreshData: (fresh) {
          _specialties = fresh;
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint("DoctorsNotifier Specialties Fetch Error: $e");
    } finally {
      _endNetworkRequest();
    }
  }

  void prepareForRadiusFetch({required bool isHomeFeed}) {
    // Array wiping is disabled to allow smooth visual transitions without loading spinners overlaying.
  }

  void clear() {
    _doctors = [];
    _hospitals = [];
    _clinics = [];
    _homePopularDoctors = [];
    _explorePopularDoctors = [];
    _homeFeaturedDoctors = [];
    _exploreFeaturedDoctors = [];
    _specialties = [];
    _isLoading = false;
    _lastQuery = '';
    _lastFilter = 'All';
    notifyListeners();
  }
}
