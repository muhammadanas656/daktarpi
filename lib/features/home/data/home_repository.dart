import 'package:supabase_flutter/supabase_flutter.dart';
import '../../doctors/data/specialty.dart';
import '../../doctors/data/doctor_repository.dart';
import 'package:flutter/foundation.dart';

/// Thin facade that provides home-screen-specific data.
///
/// Delegates to [DoctorRepository] under the hood so the home
/// screen does not couple directly to raw DB queries.
class HomeRepository {
  final DoctorRepository _doctorRepo;
  final SupabaseClient _client;

  HomeRepository({DoctorRepository? doctorRepo, SupabaseClient? client})
    : _doctorRepo = doctorRepo ?? DoctorRepository(),
      _client = client ?? Supabase.instance.client;

  /// Fetches the list of specialties for the home screen.
  Future<List<Specialty>> fetchSpecialties({int limit = 10}) async {
    final raw = await _doctorRepo.fetchSpecialties(limit: limit);
    return raw.map((json) => Specialty.fromJson(json)).toList();
  }

  /// Fetches popular doctors (limited for the home carousel).
  Future<List<Map<String, dynamic>>> fetchPopularDoctors({
    int limit = 5,
    String? userLocation,
    String? countryIso,
  }) async {
    return _doctorRepo.fetchPopularDoctors(limit: limit, userLocation: userLocation, countryIso: countryIso);
  }

  /// Fetches featured doctors (limited for the home carousel).
  Future<List<Map<String, dynamic>>> fetchFeaturedDoctors({
    int limit = 5,
    String? userLocation,
    String? countryIso,
  }) async {
    return _doctorRepo.fetchFeaturedDoctors(limit: limit, userLocation: userLocation, countryIso: countryIso);
  }
  
  /// Fetches banners for the home screen filtered by country.
  Future<List<Map<String, dynamic>>> fetchBanners(String? countryIso) async {
    try {
      var dbQuery = _client.from('banners').select().eq('is_active', true);
      
      if (countryIso != null && countryIso.isNotEmpty) {
        dbQuery = dbQuery.eq('country_iso', countryIso);
      }
      
      final response = await dbQuery;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Error fetching banners: $e");
      return [];
    }
  }
}
