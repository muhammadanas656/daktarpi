import 'dart:async';
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

  // Track parameters to prevent re-fetching the same data
  String _lastQuery = '';
  String _lastFilter = 'All';

  List<Map<String, dynamic>> get doctors => _doctors;
  List<Map<String, dynamic>> get hospitals => _hospitals;
  List<Map<String, dynamic>> get clinics => _clinics;

  List<Map<String, dynamic>> get homePopularDoctors => _homePopularDoctors;
  List<Map<String, dynamic>> get explorePopularDoctors => _explorePopularDoctors;
  List<Map<String, dynamic>> get homeFeaturedDoctors => _homeFeaturedDoctors;
  List<Map<String, dynamic>> get exploreFeaturedDoctors => _exploreFeaturedDoctors;
  List<Map<String, dynamic>> get specialties => _specialties;

  bool get isLoading => _isLoading;

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

  /// Fetch all required data once. Safe to be called by multiple screens.

  Future<Position?> getUserPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
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
        _doctors.isNotEmpty) {
      return;
    }

    _lastQuery = query;
    _lastFilter = filter;
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
        _doctors = results[0] as List<Map<String, dynamic>>;
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
    if (!forceRefresh && currentList.isNotEmpty && query.isEmpty && filter == 'All') return;

    if (currentList.isEmpty) {
      _isLoading = true;
      notifyListeners();
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

      final fetchedData = await _doctorRepo.fetchPopularDoctors(
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
          if (isHomeFeed) {
            _homePopularDoctors = fresh;
          } else {
            _explorePopularDoctors = fresh;
          }
          notifyListeners();
        },
      );
      
      if (isHomeFeed) {
        _homePopularDoctors = fetchedData;
      } else {
        _explorePopularDoctors = fetchedData;
      }
    } catch (e) {
      debugPrint("DoctorsNotifier Popular Fetch Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
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
    if (!forceRefresh && currentList.isNotEmpty && query.isEmpty && filter == 'All') return;

    if (currentList.isEmpty) {
      _isLoading = true;
      notifyListeners();
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

      final fetchedData = await _doctorRepo.fetchFeaturedDoctors(
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
          if (isHomeFeed) {
            _homeFeaturedDoctors = fresh;
          } else {
            _exploreFeaturedDoctors = fresh;
          }
          notifyListeners();
        },
      );
      
      if (isHomeFeed) {
        _homeFeaturedDoctors = fetchedData;
      } else {
        _exploreFeaturedDoctors = fetchedData;
      }
    } catch (e) {
      debugPrint("DoctorsNotifier Featured Fetch Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }



  Future<void> fetchSpecialties({bool forceRefresh = false}) async {
    // PRO FIX: The RAM Cache Guard!
    if (!forceRefresh && _specialties.isNotEmpty) return;

    if (_specialties.isEmpty) {
      _isLoading = true;
      notifyListeners();
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
      _isLoading = false;
      notifyListeners();
    }
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