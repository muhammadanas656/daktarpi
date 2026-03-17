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
  List<Map<String, dynamic>> _popularDoctors = [];
  List<Map<String, dynamic>> _featuredDoctors = [];
  List<Map<String, dynamic>> _specialties = [];

  bool _isLoading = false;

  // Track parameters to prevent re-fetching the same data
  String _lastQuery = '';
  String _lastFilter = 'All';

  List<Map<String, dynamic>> get doctors => _doctors;
  List<Map<String, dynamic>> get hospitals => _hospitals;
  List<Map<String, dynamic>> get clinics => _clinics;

  List<Map<String, dynamic>> get popularDoctors => _popularDoctors;
  List<Map<String, dynamic>> get featuredDoctors => _featuredDoctors;
  List<Map<String, dynamic>> get specialties => _specialties;

  bool get isLoading => _isLoading;

  /// Fetch all required data once. Safe to be called by multiple screens.
  Future<void> fetchDoctors({
    String query = '',
    String filter = 'All',
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

      if (filter == 'Nearest') {
        try {
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
          );
          userLat = position.latitude;
          userLng = position.longitude;
        } catch (e) {
          debugPrint(
            "DoctorsNotifier: Location permission denied or unretrievable.",
          );
        }
      }

      final userLocation = _profileNotifier.profile?.location;
      final countryIso = _profileNotifier.profile?.countryIso;

      final results = await Future.wait([
        _doctorRepo.fetchAllDoctors(
          query: query,
          userLat: userLat,
          userLng: userLng,
          userLocation: userLocation,
          countryIso: countryIso,
        ),
        _doctorRepo.fetchHospitals(query: query),
        _doctorRepo.fetchClinicsList(query: query),
      ]);

      // Ensure we only apply this if the user hasn't typed a NEW query while this was loading
      if (_lastQuery == query && _lastFilter == filter) {
        _doctors = results[0];
        _hospitals = results[1];
        _clinics = results[2];
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

  // --- PRO FIX: Centralized Sub-Searches ---

  Future<void> fetchPopularDoctors({
    String query = '',
    int? limit,
    bool forceRefresh = false,
  }) async {
    // PRO FIX: The RAM Cache Guard! If we have data and aren't forcing a refresh, escape instantly!
    if (!forceRefresh && _popularDoctors.isNotEmpty) return;

    if (_popularDoctors.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final userLocation = _profileNotifier.profile?.location;
      final countryIso = _profileNotifier.profile?.countryIso;

      _popularDoctors = await _doctorRepo.fetchPopularDoctors(
        query: query,
        limit: limit,
        forceRefresh: forceRefresh,
        userLocation: userLocation,
        countryIso: countryIso,
      );
    } catch (e) {
      debugPrint("DoctorsNotifier Popular Fetch Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchFeaturedDoctors({
    String query = '',
    int? limit,
    bool forceRefresh = false,
  }) async {
    // PRO FIX: The RAM Cache Guard!
    if (!forceRefresh && _featuredDoctors.isNotEmpty) return;

    if (_featuredDoctors.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final userLocation = _profileNotifier.profile?.location;
      final countryIso = _profileNotifier.profile?.countryIso;

      _featuredDoctors = await _doctorRepo.fetchFeaturedDoctors(
        query: query,
        limit: limit,
        forceRefresh: forceRefresh,
        userLocation: userLocation,
        countryIso: countryIso,
      );
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
    _popularDoctors = [];
    _featuredDoctors = [];
    _specialties = [];
    _isLoading = false;
    _lastQuery = '';
    _lastFilter = 'All';
    notifyListeners();
  }
}
