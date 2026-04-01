import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/network/network_notifier.dart';
import 'doctor.dart';

class DoctorRepository {
  final SupabaseClient _client;

  // Phase 2 & 3: Cache and Queue Boxes
  static const String _boxName = 'doctor_cache';
  static const String _queueBoxName = 'doctor_offline_queue';
  static const _cacheDuration = Duration(minutes: 60);

  DoctorRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  String? get currentUserId => _client.auth.currentUser?.id;

  // ─── Smart Hive Caching Engine ─────────────────────────────────────────────

  Future<Box> _getCacheBox() async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box(_boxName);
    return await Hive.openBox(_boxName);
  }

  bool _isCacheValid(DateTime? lastFetch) {
    if (lastFetch == null) return false;
    return DateTime.now().difference(lastFetch) < _cacheDuration;
  }

  Future<List<Map<String, dynamic>>> _fetchWithCache({
    String? cacheKey,
    required Future<List<Map<String, dynamic>>> Function() fetcher,
    bool forceRefresh = false,
    void Function(List<Map<String, dynamic>>)? onFreshData,
  }) async {
    if (cacheKey == null) {
      if (NetworkNotifier.instance.isOffline) {
        throw const AppFailure(
          type: AppFailureType.network,
          userMessage:
              'You are offline. Please connect to the internet to search.',
          technicalMessage: 'offline',
        );
      }
      return await fetcher().timeout(const Duration(seconds: 8));
    }

    final box = await _getCacheBox();
    final isOffline = NetworkNotifier.instance.isOffline;
    final lastFetchKey = '${cacheKey}_time';

    final cachedData = box.get(cacheKey);
    final lastFetchStr = box.get(lastFetchKey);
    DateTime? lastFetch =
        lastFetchStr != null ? DateTime.tryParse(lastFetchStr) : null;

    // --- PRO FIX: Instant Cache-First Return with Silent Background Sync ---
    if (cachedData != null) {
      final List<dynamic> decoded = jsonDecode(cachedData);
      final cache = decoded.map((e) => Map<String, dynamic>.from(e)).toList();

      if (!isOffline && !forceRefresh) {
        unawaited(() async {
          try {
            await NetworkNotifier.instance.waitForSync();
            final fresh = await fetcher().timeout(const Duration(seconds: 8));
            final freshStr = jsonEncode(fresh);
            
            // Only notify UI and write to disk if data ACTUALLY changed
            if (freshStr != cachedData) {
              await box.put(cacheKey, freshStr);
              await box.put(lastFetchKey, DateTime.now().toIso8601String());
              if (onFreshData != null) onFreshData(fresh);
            }
          } catch (_) {}
        }());
      }

      // Rule 2: NEVER block the UI if we have cache!
      if (isOffline || !forceRefresh) {
        return cache;
      }
    }

    await NetworkNotifier.instance.waitForSync();

    try {
      final data = await fetcher().timeout(const Duration(seconds: 8));
      await box.put(cacheKey, jsonEncode(data));
      await box.put(lastFetchKey, DateTime.now().toIso8601String());
      return data;
    } catch (e) {
      if (cachedData != null) {
        final List<dynamic> decoded = jsonDecode(cachedData);
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      rethrow;
    }
  }

  // ─── PRO FIX: Offline Action Queue ─────────────────────────────────────────

  Future<Box> _getQueueBox() async {
    if (Hive.isBoxOpen(_queueBoxName)) return Hive.box(_queueBoxName);
    return await Hive.openBox(_queueBoxName);
  }

  Future<void> _queueAction(
    String actionType,
    Map<String, dynamic> payload,
  ) async {
    final box = await _getQueueBox();
    await box.add({
      'action': actionType,
      'payload': jsonEncode(payload),
      'timestamp': DateTime.now().toIso8601String(),
    });
    debugPrint('⚡ [Doctor Offline Queue] Action saved: $actionType');
  }

  /// Processes all pending offline actions when the internet is restored
  Future<void> syncOfflineQueue() async {
    if (NetworkNotifier.instance.isOffline) return;

    final box = await _getQueueBox();
    if (box.isEmpty) return;

    debugPrint('🔄 [Doctor Sync] Processing ${box.length} offline actions...');
    final keys = box.keys.toList();

    for (var key in keys) {
      final item = box.get(key);
      if (item != null) {
        try {
          final action = item['action'];
          final payload = jsonDecode(item['payload']);

          if (action == 'toggle_favorite') {
            final isFavorite = payload['isFavorite'];
            if (isFavorite) {
              await _client.from('favorite_doctors').delete().match({
                'user_id': payload['user_id'],
                'doctor_id': payload['doctor_id'],
              });
            } else {
              // Upsert prevents crashing if the user tapped like twice while offline
              await _client.from('favorite_doctors').upsert({
                'user_id': payload['user_id'],
                'doctor_id': payload['doctor_id'],
              });
            }
          }
          await box.delete(key);
          debugPrint('✅ [Doctor Sync] Action completed: $action');
        } catch (e) {
          debugPrint('❌ [Doctor Sync] Failed to process action: $e');
        }
      }
    }
  }

  Future<String?> fetchSpecialtyIcon(String specialtyId) async {
    try {
      final response = await _client
          .from('specialties')
          .select('icon_url')
          .eq('id', specialtyId)
          .maybeSingle();
      return response?['icon_url'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ─── Single Doctor ─────────────────────────────────────────────────────────

  Future<Doctor> fetchDoctorDetails(String doctorId) async {
    try {
      final idParam = int.tryParse(doctorId) ?? doctorId;
      final response =
          await _client
              .from('doctors')
              .select('*, specialties(name)')
              .eq('id', idParam)
              .single();
      return Doctor.fromJson(response);
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to load doctor details right now.',
      );
    }
  }

  Future<void> incrementDoctorViewCount(String doctorId) async {
    if (NetworkNotifier.instance.isOffline) return;
    final userId = currentUserId;
    if (userId == null) return;
    try {
      final idParam = int.tryParse(doctorId);
      if (idParam == null) return;
      await _client.rpc(
        'increment_doctor_views_smart',
        params: {'doc_id': idParam, 'v_user_id': userId},
      );
    } catch (error) {
      debugPrint('Failed to increment doctor view count: $error');
    }
  }

  // ─── Micro-RPC: Smart Cluster Radius ──────────────────────────────────────

  /// Calculates the optimal search radius (in km) to capture roughly
  /// [targetClusterSize] unique doctors near the user's location.
  /// Returns a value clamped between 2.0 and [maxAllowedRadius] km.
  Future<double> fetchSmartClusterRadius({
    required double userLat,
    required double userLng,
    required String countryIso,
    int targetClusterSize = 6,
    double maxAllowedRadius = 50.0,
  }) async {
    if (NetworkNotifier.instance.isOffline) return maxAllowedRadius;
    try {
      final result = await _client.rpc('get_smart_cluster_radius', params: {
        'p_user_lat': userLat,
        'p_user_lng': userLng,
        'p_user_country': countryIso,
        'p_target_cluster_size': targetClusterSize,
        'p_max_allowed_radius': maxAllowedRadius,
      });
      return (result as num?)?.toDouble() ?? maxAllowedRadius;
    } catch (e) {
      debugPrint('Smart cluster radius failed: $e');
      return maxAllowedRadius;
    }
  }

  // ─── Master RPC: Production Doctor Fetcher ────────────────────────────────

  /// The unified RPC gateway. All doctor fetching flows through here.
  /// PostgREST's foreign-key embedding on SETOF return type allows
  /// `.select('*, specialties(name), ...')` to work natively on top.
  Future<List<Map<String, dynamic>>> fetchProductionDoctors({
    String? query,
    String filterType = 'All',
    String? category,        // 'Popular', 'Featured', or null
    String? countryIso,
    String? userLocation,
    double? userLat,
    double? userLng,
    double? maxRadiusKm,     // From micro-RPC or user slider
    String? localDay,
    String? localTime,
    int? specialtyId,
    int? clinicId,
    int limit = 50,
    int offset = 0,
    bool forceRefresh = false,
    void Function(List<Map<String, dynamic>>)? onFreshData,
  }) async {
    final isSearch = query != null && query.isNotEmpty;

    // Build a stable cache key for non-search, non-filtered requests
    String? cacheKey;
    if (!isSearch && filterType == 'All' && offset == 0 && maxRadiusKm == null) {
      if (category != null) {
        cacheKey = '${category.toLowerCase()}_doctors_$countryIso';
      } else if (specialtyId != null) {
        cacheKey = 'specialty_${specialtyId}_$countryIso';
      } else if (clinicId != null) {
        cacheKey = 'clinic_$clinicId';
      } else {
        cacheKey = 'all_doctors_$countryIso';
      }
    }

    return _fetchWithCache(
      cacheKey: cacheKey,
      forceRefresh: forceRefresh,
      onFreshData: onFreshData,
      fetcher: () async {
        // Build the RPC params map — only include non-null values
        final Map<String, dynamic> params = {
          'p_filter_type': filterType,
          'p_limit': limit,
          'p_offset': offset,
        };
        if (query != null && query.isNotEmpty) params['p_search_query'] = query;
        if (category != null) params['p_category'] = category;
        if (countryIso != null) params['p_user_country'] = countryIso;
        if (userLocation != null) params['p_user_location'] = userLocation;
        if (userLat != null) params['p_user_lat'] = userLat;
        if (userLng != null) params['p_user_lng'] = userLng;
        if (maxRadiusKm != null) params['p_max_radius_km'] = maxRadiusKm;
        if (localDay != null) params['p_local_day'] = localDay;
        if (localTime != null) params['p_local_time'] = localTime;
        if (specialtyId != null) params['p_specialty_id'] = specialtyId;
        if (clinicId != null) params['p_clinic_id'] = clinicId;

        // The magic: PostgREST embeds foreign keys on SETOF returns
        final response = await _client
            .rpc('get_production_doctors', params: params)
            .select('*, specialties(name), doctor_clinics(clinics(latitude, longitude))');

        return List<Map<String, dynamic>>.from(response);
      },
    );
  }

  // ─── Convenience Wrappers (Preserve existing API surface) ─────────────────

  Future<List<Map<String, dynamic>>> fetchAllDoctors({
    String? query,
    String filterType = 'All',
    double? userLat,
    double? userLng,
    double? maxRadiusKm,
    String? userLocation,
    String? countryIso,
    bool forceRefresh = false,
  }) {
    final now = DateTime.now();
    return fetchProductionDoctors(
      query: query,
      filterType: filterType,
      countryIso: countryIso,
      userLocation: userLocation,
      userLat: userLat,
      userLng: userLng,
      maxRadiusKm: maxRadiusKm,
      localDay: DateFormat('EEEE').format(now),
      localTime: DateFormat('HH:mm:ss').format(now),
      forceRefresh: forceRefresh,
      limit: 100,
    );
  }

  Future<List<Map<String, dynamic>>> fetchPopularDoctors({
    String? query,
    String filterType = 'All',
    int? limit,
    bool forceRefresh = false,
    String? userLocation,
    String? countryIso,
    double? userLat,
    double? userLng,
    double? maxRadiusKm,
    void Function(List<Map<String, dynamic>>)? onFreshData,
  }) async {
    final now = DateTime.now();
    final data = await fetchProductionDoctors(
      query: query,
      filterType: filterType,
      category: 'Popular',
      countryIso: countryIso,
      userLocation: userLocation,
      userLat: userLat,
      userLng: userLng,
      maxRadiusKm: maxRadiusKm,
      localDay: DateFormat('EEEE').format(now),
      localTime: DateFormat('HH:mm:ss').format(now),
      forceRefresh: forceRefresh,
      limit: limit ?? 50,
      onFreshData: onFreshData != null && limit != null
          ? (fresh) => onFreshData(fresh.take(limit).toList())
          : onFreshData,
    );
    return limit != null ? data.take(limit).toList() : data;
  }

  Future<List<Map<String, dynamic>>> fetchFeaturedDoctors({
    String? query,
    String filterType = 'All',
    int? limit,
    bool forceRefresh = false,
    String? userLocation,
    String? countryIso,
    double? userLat,
    double? userLng,
    double? maxRadiusKm,
    void Function(List<Map<String, dynamic>>)? onFreshData,
  }) async {
    final now = DateTime.now();
    final data = await fetchProductionDoctors(
      query: query,
      filterType: filterType,
      category: 'Featured',
      countryIso: countryIso,
      userLocation: userLocation,
      userLat: userLat,
      userLng: userLng,
      maxRadiusKm: maxRadiusKm,
      localDay: DateFormat('EEEE').format(now),
      localTime: DateFormat('HH:mm:ss').format(now),
      forceRefresh: forceRefresh,
      limit: limit ?? 50,
      onFreshData: onFreshData != null && limit != null
          ? (fresh) => onFreshData(fresh.take(limit).toList())
          : onFreshData,
    );
    return limit != null ? data.take(limit).toList() : data;
  }

  Future<List<Map<String, dynamic>>> fetchDoctorsBySpecialty(
    String specialtyId, {
    String? query,
    String filterType = 'All',
    String? userLocation,
    String? countryIso,
    double? userLat,
    double? userLng,
    double? maxRadiusKm,
  }) {
    final now = DateTime.now();
    return fetchProductionDoctors(
      query: query,
      filterType: filterType,
      specialtyId: int.tryParse(specialtyId),
      countryIso: countryIso,
      userLocation: userLocation,
      userLat: userLat,
      userLng: userLng,
      maxRadiusKm: maxRadiusKm,
      localDay: DateFormat('EEEE').format(now),
      localTime: DateFormat('HH:mm:ss').format(now),
      limit: 100,
    );
  }

  Future<List<Map<String, dynamic>>> fetchDoctorsByClinic(
    int clinicId, {
    String? query,
    String filterType = 'All',
    double? userLat,
    double? userLng,
    double? maxRadiusKm,
  }) {
    final now = DateTime.now();
    return fetchProductionDoctors(
      query: query,
      filterType: filterType,
      clinicId: clinicId,
      userLat: userLat,
      userLng: userLng,
      maxRadiusKm: maxRadiusKm,
      localDay: DateFormat('EEEE').format(now),
      localTime: DateFormat('HH:mm:ss').format(now),
      limit: 100,
    );
  }

  Future<List<Map<String, dynamic>>> fetchGlobalSearch({
    required String query,
    double? userLat,
    double? userLng,
    String? userLocation,
    String? countryIso,
  }) {
    if (NetworkNotifier.instance.isOffline) {
      throw const AppFailure(
        type: AppFailureType.network,
        userMessage: 'Global Search is an online-only feature.',
        technicalMessage: 'offline',
      );
    }
    return fetchProductionDoctors(
      query: query,
      countryIso: countryIso,
      userLocation: userLocation,
      userLat: userLat,
      userLng: userLng,
      limit: 50,
    );
  }

  Future<Map<String, List<Map<String, dynamic>>>> fetchSearchHints({
    required String query,
  }) async {
    if (NetworkNotifier.instance.isOffline) {
      return {'doctors': [], 'clinics': []};
    }
    try {
      final doctorFuture = _client
          .from('doctors')
          .select('id, full_name, profile_picture_url, specialties!inner(name)')
          .ilike('full_name', '%$query%')
          .limit(3);
      final clinicFuture = _client
          .from('clinics')
          .select('id, name, address')
          .ilike('name', '%$query%')
          .limit(2);
      final results = await Future.wait([doctorFuture, clinicFuture]);
      return {
        'doctors': List<Map<String, dynamic>>.from(results[0]),
        'clinics': List<Map<String, dynamic>>.from(results[1]),
      };
    } catch (error) {
      return {'doctors': [], 'clinics': []};
    }
  }

  Future<List<Map<String, dynamic>>> fetchSpecialties({
    int limit = 10,
    bool forceRefresh = false,
    void Function(List<Map<String, dynamic>>)? onFreshData,
  }) async {
    final data = await _fetchWithCache(
      cacheKey: 'specialties_list',
      forceRefresh: forceRefresh,
      onFreshData: onFreshData != null ? ((fresh) => onFreshData(fresh.take(limit).toList())) : null,
      fetcher: () async {
        final response = await _client.from('specialties').select();
        return List<Map<String, dynamic>>.from(response);
      },
    );
    return data.take(limit).toList();
  }

  // ─── Clinics & Schedules ───────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchClinics(String doctorId) async {
    return _fetchWithCache(
      cacheKey: 'doctor_clinics_$doctorId',
      fetcher: () async {
        final idParam = int.tryParse(doctorId) ?? doctorId;
        final response = await _client
            .from('doctor_clinics')
            .select(
              'id, clinic_id, visit_price, min_wait_time, max_wait_time, clinics(id, name, address, latitude, longitude)',
            )
            .eq('doctor_id', idParam)
            .order('visit_price', ascending: true);
        return List<dynamic>.from(response).map((e) {
          final clinicData = e['clinics'] as Map<String, dynamic>;
          final min = e['min_wait_time'] ?? 20;
          final max = e['max_wait_time'] ?? 30;
          return {
            ...clinicData,
            'junction_id': e['id'],
            'visit_price': e['visit_price'],
            'min_wait_time': min,
            'max_wait_time': max,
            'avg_wait_time': "$min-$max mins",
          };
        }).toList();
      },
    );
  }

  Future<List<Map<String, dynamic>>> fetchSchedules(String doctorId) async {
    final idParam = int.tryParse(doctorId) ?? doctorId;
    final response = await _client
        .from('doctor_schedules')
        .select('*')
        .eq('doctor_id', idParam);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> fetchFacilities({
    required String type,
    String? query,
    double? userLat,
    double? userLng,
    double? maxRadiusKm,
    String sortBy = 'views_count',
  }) async {
    final isSearch = query != null && query.isNotEmpty;
    // We only fetch facilities from DB/Cache globally.
    // Spatial mapping, sorting, and bounding must occur AFTER the cache retrieves data.
    final List<Map<String, dynamic>> rawFacilities = await _fetchWithCache(
      cacheKey: isSearch ? null : 'facilities_$type', // Base cache key
      fetcher: () async {
        var dbQuery = _client.from('clinics').select().eq('type', type);
        if (isSearch) dbQuery = dbQuery.ilike('name', '%$query%');
        final response = await dbQuery;
        return List<Map<String, dynamic>>.from(response);
      },
    );

    // Apply native boundary isolation independently of network layer
    if (userLat == null || userLng == null) {
      return rawFacilities;
    }

    return await compute(_isolateFacilityDistanceSort, {
      'data': rawFacilities,
      'userLat': userLat,
      'userLng': userLng,
      'maxRadiusKm': maxRadiusKm,
    });
  }

  Future<List<Map<String, dynamic>>> fetchHospitals({String? query, double? userLat, double? userLng, double? maxRadiusKm}) async =>
      fetchFacilities(type: 'hospital', query: query, userLat: userLat, userLng: userLng, maxRadiusKm: maxRadiusKm);
  Future<List<Map<String, dynamic>>> fetchClinicsList({String? query, double? userLat, double? userLng, double? maxRadiusKm}) async =>
      fetchFacilities(type: 'clinic', query: query, userLat: userLat, userLng: userLng, maxRadiusKm: maxRadiusKm);

  Future<List<Map<String, dynamic>>> fetchSchedulesByClinic(
    String doctorId,
    String clinicId,
  ) async {
    final response = await _client
        .from('doctor_schedules')
        .select()
        .eq('doctor_id', doctorId)
        .eq('clinic_id', clinicId);
    return List<Map<String, dynamic>>.from(response);
  }

  // ─── Favorites ─────────────────────────────────────────────────────────────

  Future<bool> isFavorite(String doctorId, String userId) async {
    if (NetworkNotifier.instance.isOffline) return false;

    // PRO FIX: Added Sync Guard to individual queries too
    await NetworkNotifier.instance.waitForSync();

    try {
      final response =
          await _client
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

  Future<Set<int>> fetchFavoriteIds(String userId) async {
    if (NetworkNotifier.instance.isOffline) return {};

    // PRO FIX: Sync Guard
    await NetworkNotifier.instance.waitForSync();

    try {
      final response = await _client
          .from('favorite_doctors')
          .select('doctor_id')
          .eq('user_id', userId);
      return List<Map<String, dynamic>>.from(
        response,
      ).map((e) => e['doctor_id'] as int).toSet();
    } catch (e) {
      return {};
    }
  }

  Future<void> toggleFavorite(
    int doctorId,
    String userId,
    bool isFavorite,
  ) async {
    // PRO FIX: Intercept offline actions so they don't crash and cause a UI Rebound!
    if (NetworkNotifier.instance.isOffline) {
      await _queueAction('toggle_favorite', {
        'doctor_id': doctorId,
        'user_id': userId,
        'isFavorite': isFavorite,
      });
      return; // Crucial: Returns immediately so no error is thrown!
    }

    // PRO FIX: Added Sync Guard here as well. If the user hits "like" the moment
    // internet returns, this pauses the action so it doesn't conflict with the queue!
    await NetworkNotifier.instance.waitForSync();

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

      final box = await _getCacheBox();
      await box.delete('favorites_$userId');
    } catch (error) {
      // PRO FIX: Catch "Lie-Fi" connection issues and queue them instead of reverting the UI!
      final errStr = error.toString().toLowerCase();
      if (errStr.contains('socketexception') ||
          errStr.contains('clientexception') ||
          errStr.contains('failed host lookup') ||
          errStr.contains('connection closed')) {
        
        debugPrint('⚠️ Network error during like toggle. Queueing offline action.');
        await _queueAction('toggle_favorite', {
          'doctor_id': doctorId,
          'user_id': userId,
          'isFavorite': isFavorite, 
        });
        return; // Return normally so FavoritesNotifier keeps the optimistic UI
      }

      // If it's a real database error (not a network issue), throw it to revert UI
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Failed to update favorite.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchFavoriteDoctors() async {
    final userId = currentUserId;
    if (userId == null) return [];
    return _fetchWithCache(
      cacheKey: 'favorites_$userId',
      forceRefresh: true,
      fetcher: () async {
        final response = await _client
            .from('favorite_doctors')
            .select('doctors(*, specialties(name))')
            .eq('user_id', userId);
        return List<Map<String, dynamic>>.from(
          response.map((e) => e['doctors']),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> fetchRecentDoctors() async {
    final userId = currentUserId;
    if (userId == null) return [];
    return _fetchWithCache(
      cacheKey: 'recent_doctors_$userId',
      forceRefresh: true,
      fetcher: () async {
        final response = await _client
            .from('appointments')
            .select('doctors(*, specialties(name))')
            .eq('user_id', userId)
            .eq('status', 'completed')
            .order('schedule_date', ascending: false);
        final seenIds = <int>{};
        final uniqueDoctors = <Map<String, dynamic>>[];
        for (var item in response) {
          final doctor = item['doctors'] as Map<String, dynamic>;
          final id = doctor['id'] as int;
          if (!seenIds.contains(id)) {
            seenIds.add(id);
            uniqueDoctors.add(doctor);
          }
        }
        return uniqueDoctors;
      },
    );
  }
}



List<Map<String, dynamic>> _isolateFacilityDistanceSort(Map<String, dynamic> params) {
  // Isolate maps deeply unbox over execution boundaries, we must safely decode
  final rawList = params['data'] as List<dynamic>;
  final data = rawList.map((e) => Map<String, dynamic>.from(e)).toList();
  
  final userLat = params['userLat'] as double;
  final userLng = params['userLng'] as double;
  final maxRadiusKm = params['maxRadiusKm'] as double?;

  final distances = <Map<String, dynamic>, double>{};

  // Pure dart math to heavily bypass Geolocator MethodChannel crash in isolated memory threads
  double haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371; // km
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) * math.cos(lat2 * math.pi / 180.0) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    // 1.3x Heuristic to convert straight-line map displacement to estimated driving commute
    return 1.3 * (R * c);
  }

  for (var item in data) {
    if (item['latitude'] != null && item['longitude'] != null) {
      final double lat = (item['latitude'] as num).toDouble();
      final double lng = (item['longitude'] as num).toDouble();
      distances[item] = haversineDistance(userLat, userLng, lat, lng);
    }
  }

  var filteredList = data;
  if (maxRadiusKm != null) {
    filteredList = data.where((item) {
      if (!distances.containsKey(item)) return false; 
      return distances[item]! <= maxRadiusKm;
    }).toList();
  }

  filteredList.sort((a, b) {
    if (!distances.containsKey(a)) return 1;
    if (!distances.containsKey(b)) return -1;
    return distances[a]!.compareTo(distances[b]!);
  });

  return filteredList;
}
