import 'dart:async';
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../../doctors/data/specialty.dart';
import '../../doctors/data/doctor_repository.dart';
import '../../../core/network/network_notifier.dart';

class HomeRepository {
  final DoctorRepository _doctorRepo;
  final SupabaseClient _client;

  // PRO FIX: Static variables to hold banners in RAM across the entire app lifecycle
  static List<Map<String, dynamic>>? _ramBanners;
  static DateTime? _lastBannerFetch;

  static List<Map<String, dynamic>> get currentBanners => _ramBanners ?? [];

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

  // PRO FIX: Added forceRefresh parameter to allow pull-to-refresh
  // PRO FIX: Added onFreshData callback to instantly push silent sync results to UI
  Future<List<Map<String, dynamic>>> fetchBanners(
    String? countryIso, {
    bool forceRefresh = false,
    void Function(List<Map<String, dynamic>>)? onFreshData,
  }) async {
    // 1. THE RAM GUARD (0 milliseconds!)
    // If we have banners in RAM and they are less than 10 mins old, return instantly.
    if (!forceRefresh && _ramBanners != null && _lastBannerFetch != null) {
      if (DateTime.now().difference(_lastBannerFetch!).inMinutes < 10) {
        return _ramBanners!;
      }
    }

    final cacheKey = 'banners_$countryIso';
    Box box;
    if (Hive.isBoxOpen('home_cache')) {
      box = Hive.box('home_cache');
    } else {
      box = await Hive.openBox('home_cache');
    }

    final isOffline = NetworkNotifier.instance.isOffline;
    final cachedData = box.get(cacheKey);

    // 2. THE OFFLINE & INSTANT CACHE ENGINE
    if (cachedData != null) {
      final decoded = await compute(_isolateDecodeHomeList, cachedData as String);
      _ramBanners = decoded.map((e) => Map<String, dynamic>.from(e)).toList();

      if (onFreshData != null) {
        scheduleMicrotask(() => onFreshData(_ramBanners!));
      }

      // Fire Silent Sync!
      if (!isOffline && !forceRefresh) {
        unawaited(() async {
          try {
            await NetworkNotifier.instance.waitForSync();
            var dbQuery = _client.from('banners').select().eq('is_active', true);
            if (countryIso != null && countryIso.isNotEmpty) {
              dbQuery = dbQuery.eq('country_iso', countryIso);
            }
            final response = await dbQuery.timeout(const Duration(seconds: 8));
            final data = List<Map<String, dynamic>>.from(response);
            
            final freshStr = jsonEncode(data);
            if (freshStr != cachedData) {
              await box.put(cacheKey, freshStr);
              _ramBanners = data;
              _lastBannerFetch = DateTime.now();
              if (onFreshData != null) onFreshData(data);
            }
          } catch (_) {}
        }());
      }

      // Rule 2: Return Cache Instantly
      if (isOffline || !forceRefresh) {
        return _ramBanners!;
      }
    }

    // 3. THE NETWORK FETCH (Blocking only if no cache or force refresh)
    await NetworkNotifier.instance.waitForSync();
    try {
      var dbQuery = _client.from('banners').select().eq('is_active', true);
      if (countryIso != null && countryIso.isNotEmpty) {
        dbQuery = dbQuery.eq('country_iso', countryIso);
      }
      final response = await dbQuery.timeout(const Duration(seconds: 8));
      final data = List<Map<String, dynamic>>.from(response);
      
      // Save to disk (Hive) and RAM
      await box.put(cacheKey, jsonEncode(data));
      _ramBanners = data;
      _lastBannerFetch = DateTime.now();
      
      if (onFreshData != null) onFreshData(data);
      
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

List<dynamic> _isolateDecodeHomeList(String jsonString) {
  return jsonDecode(jsonString) as List<dynamic>;
}