import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../doctors/data/specialty.dart';
import '../../doctors/data/doctor_repository.dart';
import '../../../core/network/network_notifier.dart';

class HomeRepository {
  final DoctorRepository _doctorRepo;
  final SupabaseClient _client;

  HomeRepository({DoctorRepository? doctorRepo, SupabaseClient? client})
    : _doctorRepo = doctorRepo ?? DoctorRepository(),
      _client = client ?? Supabase.instance.client;

  Future<List<Specialty>> fetchSpecialties({int limit = 10}) async {
    final raw = await _doctorRepo.fetchSpecialties(limit: limit);
    return raw.map((json) => Specialty.fromJson(json)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchPopularDoctors({
    int limit = 5,
    String? userLocation,
    String? countryIso,
  }) async {
    return _doctorRepo.fetchPopularDoctors(
      limit: limit,
      userLocation: userLocation,
      countryIso: countryIso,
    );
  }

  Future<List<Map<String, dynamic>>> fetchFeaturedDoctors({
    int limit = 5,
    String? userLocation,
    String? countryIso,
  }) async {
    return _doctorRepo.fetchFeaturedDoctors(
      limit: limit,
      userLocation: userLocation,
      countryIso: countryIso,
    );
  }

  Future<List<Map<String, dynamic>>> fetchBanners(String? countryIso) async {
    final cacheKey = 'banners_$countryIso';
    Box box;
    if (Hive.isBoxOpen('home_cache')) {
      box = Hive.box('home_cache');
    } else {
      box = await Hive.openBox('home_cache');
    }

    final isOffline = NetworkNotifier.instance.isOffline;
    final cachedData = box.get(cacheKey);

    if (isOffline && cachedData != null) {
      final decoded = jsonDecode(cachedData) as List<dynamic>;
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    }

    try {
      var dbQuery = _client.from('banners').select().eq('is_active', true);
      if (countryIso != null && countryIso.isNotEmpty) {
        dbQuery = dbQuery.eq('country_iso', countryIso);
      }
      final response = await dbQuery;
      final data = List<Map<String, dynamic>>.from(response);
      await box.put(cacheKey, jsonEncode(data));
      return data;
    } catch (e) {
      if (cachedData != null) {
        final decoded = jsonDecode(cachedData) as List<dynamic>;
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    }
  }
}
