import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'doctor.dart';
import 'package:geolocator/geolocator.dart';

class DoctorRepository {
  final SupabaseClient _client;

  DoctorRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  // ─── Caching ─────────────────────────────────────────────────
  
  List<Map<String, dynamic>> _cachedSpecialties = [];
  DateTime? _lastSpecialtiesFetch;
  
  List<Map<String, dynamic>> _cachedPopularDoctors = [];
  DateTime? _lastPopularDoctorsFetch;

  List<Map<String, dynamic>> _cachedFeaturedDoctors = [];
  DateTime? _lastFeaturedDoctorsFetch;

  static const _cacheDuration = Duration(minutes: 5);

  bool _isCacheValid(DateTime? lastFetch) {
    if (lastFetch == null) return false;
    return DateTime.now().difference(lastFetch) < _cacheDuration;
  }

  // ─── Single Doctor ───────────────────────────────────────────

  Future<Doctor> fetchDoctorDetails(String doctorId) async {
    try {
      final idParam = int.tryParse(doctorId) ?? doctorId;
      final response = await _client
          .from('doctors')
          .select('*, specialties(name)')
          .eq('id', idParam)
          .single();

      return Doctor.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch doctor details: $e');
    }
  }

  // ─── Doctor Lists ────────────────────────────────────────────

  /// Fetches all doctors with optional search and sort.
  /// Fetches all doctors with optional search and sort.
  Future<List<Map<String, dynamic>>> fetchAllDoctors({
    String? query,
    String sortBy = 'rating',
    bool ascending = false,
    double? userLat,
    double? userLng,
  }) async {
    try {
      // 1. Fetch doctors AND their clinics to get location data
      var dbQuery = _client.from('doctors').select('''
        *, 
        specialties(name),
        doctor_clinics(
          clinics(latitude, longitude)
        )
      ''');

      if (query != null && query.isNotEmpty) {
        dbQuery = dbQuery.ilike('full_name', '%$query%');
      }

      // If sorting by distance, we fetch generic list first, then sort in Dart.
      // Otherwise, we let Supabase sort.
      final isSortingByDistance = userLat != null && userLng != null;

      if (!isSortingByDistance) {
        // Standard DB Sort
        final response = await dbQuery.order(sortBy, ascending: ascending);
        return List<Map<String, dynamic>>.from(response);
      } else {
        // Nearest Filter: Fetch unsorted, then sort by distance client-side
        final response = await dbQuery;
        var data = List<Map<String, dynamic>>.from(response);

        data.sort((a, b) {
          final distA = _getMinDistance(a, userLat, userLng);
          final distB = _getMinDistance(b, userLat, userLng);
          return distA.compareTo(distB);
        });

        return data;
      }
    } catch (e) {
      throw Exception('Failed to fetch doctors: $e');
    }
  }

  /// Helper to find the nearest clinic distance for a doctor
  double _getMinDistance(Map<String, dynamic> doctor, double userLat, double userLng) {
    final clinicsJunction = doctor['doctor_clinics'] as List<dynamic>? ?? [];
    if (clinicsJunction.isEmpty) return double.maxFinite;

    double minParamsDiff = double.maxFinite;

    for (var junction in clinicsJunction) {
      final clinic = junction['clinics'];
      if (clinic != null && clinic['latitude'] != null && clinic['longitude'] != null) {
        final double lat = (clinic['latitude'] as num).toDouble();
        final double lng = (clinic['longitude'] as num).toDouble();
        
        final double distanceInMeters = Geolocator.distanceBetween(
          userLat, userLng, lat, lng
        );
        
        if (distanceInMeters < minParamsDiff) {
          minParamsDiff = distanceInMeters;
        }
      }
    }
    return minParamsDiff;
  }

  /// Fetches popular doctors (is_popular = true).
  /// Uses in-memory cache if available and [forceRefresh] is false.
  Future<List<Map<String, dynamic>>> fetchPopularDoctors({
    String? query,
    int? limit,
    bool forceRefresh = false,
  }) async {
    // Return cached if valid and no query (queries override cache for simplicity)
    if (!forceRefresh &&
        query == null &&
        _isCacheValid(_lastPopularDoctorsFetch) &&
        _cachedPopularDoctors.isNotEmpty) {
      if (limit != null) return _cachedPopularDoctors.take(limit).toList();
      return _cachedPopularDoctors;
    }

    try {
      var dbQuery = _client
          .from('doctors')
          .select('*, specialties(name)')
          .eq('is_popular', true);

      if (query != null && query.isNotEmpty) {
        dbQuery = dbQuery.ilike('full_name', '%$query%');
      }

      // Order by rating descending
      var finalQuery = dbQuery.order('rating', ascending: false);
      
      // If caching, fetch ALL popular items to cache them, then limit locally if needed.
      // If strict limit requested without cache concern, we could limit DB query.
      // Strategy: Fetch all popular (usually small set) to cache, then return slice.
      
      final response = await finalQuery;
      final data = List<Map<String, dynamic>>.from(response);

      if (query == null) {
        _cachedPopularDoctors = data;
        _lastPopularDoctorsFetch = DateTime.now();
      }

      if (limit != null) {
        return data.take(limit).toList();
      }
      return data;
    } catch (e) {
      throw Exception('Failed to fetch popular doctors: $e');
    }
  }

  /// Fetches featured doctors (is_featured = true).
  /// Uses in-memory cache if available and [forceRefresh] is false.
  Future<List<Map<String, dynamic>>> fetchFeaturedDoctors({
    String? query,
    int? limit,
    bool forceRefresh = false,
  }) async {
     if (!forceRefresh &&
        query == null &&
        _isCacheValid(_lastFeaturedDoctorsFetch) &&
        _cachedFeaturedDoctors.isNotEmpty) {
      if (limit != null) return _cachedFeaturedDoctors.take(limit).toList();
      return _cachedFeaturedDoctors;
    }

    try {
      var dbQuery = _client
          .from('doctors')
          .select('*, specialties(name)')
          .eq('is_featured', true);

      if (query != null && query.isNotEmpty) {
        dbQuery = dbQuery.ilike('full_name', '%$query%');
      }

      var finalQuery = dbQuery.order('rating', ascending: false);
      
      final response = await finalQuery;
      final data = List<Map<String, dynamic>>.from(response);

      if (query == null) {
        _cachedFeaturedDoctors = data;
        _lastFeaturedDoctorsFetch = DateTime.now();
      }

      if (limit != null) {
        return data.take(limit).toList();
      }
      return data;
    } catch (e) {
      throw Exception('Failed to fetch featured doctors: $e');
    }
  }

  /// Fetches doctors by specialty ID.
  Future<List<Map<String, dynamic>>> fetchDoctorsBySpecialty(
    String specialtyId, {
    String? query,
  }) async {
    try {
      var dbQuery = _client
          .from('doctors')
          .select('*, specialties(name)')
          .eq('specialty_id', specialtyId);

      if (query != null && query.isNotEmpty) {
        dbQuery = dbQuery.ilike('full_name', '%$query%');
      }

      final response = await dbQuery.order('rating', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch specialty doctors: $e');
    }
  }

  // ─── Specialties ─────────────────────────────────────────────

  /// Fetches doctors by clinic ID.
  Future<List<Map<String, dynamic>>> fetchDoctorsByClinic(
    int clinicId, {
    String? query,
  }) async {
    try {
      var dbQuery = _client
          .from('doctors')
          .select('*, specialties(name), doctor_clinics!inner(*)')
          .eq('doctor_clinics.clinic_id', clinicId);

      if (query != null && query.isNotEmpty) {
        dbQuery = dbQuery.ilike('full_name', '%$query%');
      }

      final response = await dbQuery;

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch doctors for clinic: $e');
    }
  }

  /// Fetches the list of specialties for the home screen.
  /// Uses in-memory cache if available and [forceRefresh] is false.
  Future<List<Map<String, dynamic>>> fetchSpecialties({
    int limit = 10,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _isCacheValid(_lastSpecialtiesFetch) &&
        _cachedSpecialties.isNotEmpty) {
      return _cachedSpecialties.take(limit).toList();
    }

    try {
      // Fetch all (or reasonable max) to cache, then limit return
      final response = await _client.from('specialties').select();
      final data = List<Map<String, dynamic>>.from(response);
      
      _cachedSpecialties = data;
      _lastSpecialtiesFetch = DateTime.now();

      return data.take(limit).toList();
    } catch (e) {
      throw Exception('Failed to fetch specialties: $e');
    }
  }

  // ─── Clinics & Schedules ─────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchClinics(String doctorId) async {
    try {
      final idParam = int.tryParse(doctorId) ?? doctorId;
      final response = await _client
          .from('doctor_clinics')
          .select(
            'id, clinic_id, visit_price, avg_wait_time, clinics(id, name, address, latitude, longitude)',
          )
          .eq('doctor_id', idParam)
          .order('visit_price', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((e) {
        final clinicData = e['clinics'] as Map<String, dynamic>;
        return {
          ...clinicData,
          'junction_id': e['id'],
          'visit_price': e['visit_price'],
          'avg_wait_time': e['avg_wait_time'] ?? '20-30 mins',
        };
      }).toList();
    } catch (e) {
      debugPrint("Error fetching clinics: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchSchedules(String doctorId) async {
    try {
      final idParam = int.tryParse(doctorId) ?? doctorId;
      final response = await _client
          .from('doctor_schedules')
          .select('*')
          .eq('doctor_id', idParam);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch schedules: $e');
    }
  }

  // ─── Hospitals & Clinics ─────────────────────────────────────

  /// Fetches facilities from the `clinics` table filtered by [type].
  /// Default types: 'hospital', 'clinic'.
  Future<List<Map<String, dynamic>>> fetchFacilities({
    required String type,
    String? query,
  }) async {
    try {
      var dbQuery = _client.from('clinics').select().eq('type', type);

      if (query != null && query.isNotEmpty) {
        dbQuery = dbQuery.ilike('name', '%$query%');
      }

      final response = await dbQuery;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Error fetching facilities (type=$type): $e");
      return [];
    }
  }

  /// Fetches clinics with type 'hospital'.
  Future<List<Map<String, dynamic>>> fetchHospitals({String? query}) async {
    return fetchFacilities(type: 'hospital', query: query);
  }

  /// Fetches clinics with type 'clinic'.
  Future<List<Map<String, dynamic>>> fetchClinicsList({String? query}) async {
    return fetchFacilities(type: 'clinic', query: query);
  }


  /// Fetches schedules filtered by both doctor and clinic.
  Future<List<Map<String, dynamic>>> fetchSchedulesByClinic(
    String doctorId,
    String clinicId,
  ) async {
    try {
      final response = await _client
          .from('doctor_schedules')
          .select()
          .eq('doctor_id', doctorId)
          .eq('clinic_id', clinicId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch clinic schedules: $e');
    }
  }

  // ─── Favorites ───────────────────────────────────────────────

  Future<bool> isFavorite(String doctorId, String userId) async {
    try {
      final response = await _client
          .from('favorite_doctors')
          .select()
          .eq('user_id', userId)
          .eq('doctor_id', doctorId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false; 
    }
  }

  /// Fetches all favorited doctor IDs for a user.
  Future<Set<int>> fetchFavoriteIds(String userId) async {
    try {
      final response = await _client
          .from('favorite_doctors')
          .select('doctor_id')
          .eq('user_id', userId);

      return List<Map<String, dynamic>>.from(response)
          .map((e) => e['doctor_id'] as int)
          .toSet();
    } catch (e) {
      return {};
    }
  }

  Future<void> toggleFavorite(String doctorId, String userId, bool isFavorite) async {
    try {
      if (isFavorite) {
         await _client.from('favorite_doctors').delete().match({
          'user_id': userId,
          'doctor_id': doctorId,
        });
      } else {
         await _client.from('favorite_doctors').insert({
          'user_id': userId,
          'doctor_id': doctorId,
        });
      }
    } catch (e) {
      throw Exception('Failed to toggle favorite: $e');
    }
  }

  // ─── Auth Helper ─────────────────────────────────────────────

  /// Returns the current user's ID, or null if not logged in.
  String? get currentUserId => _client.auth.currentUser?.id;
}
