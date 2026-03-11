import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:geolocator/geolocator.dart';

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
      return await fetcher();
    }

    final box = await _getCacheBox();
    final isOffline = NetworkNotifier.instance.isOffline;
    final lastFetchKey = '${cacheKey}_time';

    final cachedData = box.get(cacheKey);
    final lastFetchStr = box.get(lastFetchKey);
    DateTime? lastFetch =
        lastFetchStr != null ? DateTime.tryParse(lastFetchStr) : null;

    if (isOffline ||
        (!forceRefresh && _isCacheValid(lastFetch) && cachedData != null)) {
      if (cachedData != null) {
        final List<dynamic> decoded = jsonDecode(cachedData);
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      if (isOffline) return [];
    }

    // --- PRO FIX: The Sync Guard ---
    // This stops fetchRecentDoctors() and fetchFavoriteDoctors() from blinking!
    // It forces them to wait until the background offline queue finishes uploading.
    await NetworkNotifier.instance.waitForSync();

    try {
      final data = await fetcher();
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

  // ─── Doctor Lists ──────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchAllDoctors({
    String? query,
    String sortBy = 'rating',
    bool ascending = false,
    double? userLat,
    double? userLng,
    String? userLocation,
    String? countryIso,
  }) async {
    final isSearch = query != null && query.isNotEmpty;
    final cacheKey =
        (isSearch || userLat != null) ? null : 'all_doctors_$countryIso';

    return _fetchWithCache(
      cacheKey: cacheKey,
      fetcher: () async {
        // PRO FIX: Removed !inner so doctors without a specialty don't disappear
        var dbQuery = _client
            .from('doctors')
            .select(
              '*, specialties(name), doctor_clinics(clinics(latitude, longitude))',
            );

        if (isSearch) {
          // PRO FIX: Safe Relational Search - Step 1: Find matching specialties
          final specResponse = await _client
              .from('specialties')
              .select('id')
              .ilike('name', '%$query%');

          final specIds =
              List<Map<String, dynamic>>.from(
                specResponse,
              ).map((e) => e['id']).toList();

          // PRO FIX: Safe Relational Search - Step 2: Apply secure OR filter
          if (specIds.isNotEmpty) {
            // Double quotes ("%$query%") prevent spaces from crashing the Supabase parser!
            dbQuery = dbQuery.or(
              'full_name.ilike."%$query%",specialty_id.in.(${specIds.join(',')})',
            );
          } else {
            dbQuery = dbQuery.ilike('full_name', '%$query%');
          }
        }

        if (countryIso != null && countryIso.isNotEmpty) {
          dbQuery = dbQuery.eq('country_iso', countryIso);
        } else if (userLocation != null && userLocation.isNotEmpty) {
          dbQuery = dbQuery.eq('location', userLocation);
        }

        if (userLat == null || userLng == null) {
          final response = await dbQuery.order(sortBy, ascending: ascending);
          return List<Map<String, dynamic>>.from(response);
        } else {
          final response = await dbQuery;
          var data = List<Map<String, dynamic>>.from(response);
          data.sort(
            (a, b) => _getMinDistance(
              a,
              userLat,
              userLng,
            ).compareTo(_getMinDistance(b, userLat, userLng)),
          );
          return data;
        }
      },
    );
  }

  double _getMinDistance(
    Map<String, dynamic> doctor,
    double userLat,
    double userLng,
  ) {
    final clinicsJunction = doctor['doctor_clinics'] as List<dynamic>? ?? [];
    if (clinicsJunction.isEmpty) return double.maxFinite;
    double minParamsDiff = double.maxFinite;
    for (var junction in clinicsJunction) {
      final clinic = junction['clinics'];
      if (clinic != null &&
          clinic['latitude'] != null &&
          clinic['longitude'] != null) {
        final dist = Geolocator.distanceBetween(
          userLat,
          userLng,
          (clinic['latitude'] as num).toDouble(),
          (clinic['longitude'] as num).toDouble(),
        );
        if (dist < minParamsDiff) minParamsDiff = dist;
      }
    }
    return minParamsDiff;
  }

  Future<List<Map<String, dynamic>>> fetchGlobalSearch({
    required String query,
    double? userLat,
    double? userLng,
    String? userLocation,
    String? countryIso,
  }) async {
    if (NetworkNotifier.instance.isOffline) {
      throw const AppFailure(
        type: AppFailureType.network,
        userMessage: 'Global Search is an online-only feature.',
        technicalMessage: 'offline',
      );
    }
    try {
      var dbQuery = _client
          .from('doctors')
          .select(
            '*, specialties(name), doctor_clinics(clinics(name, latitude, longitude))',
          );

      if (query.isNotEmpty) {
        // PRO FIX: 1. Safely find matching specialties
        final specResponse = await _client
            .from('specialties')
            .select('id')
            .ilike('name', '%$query%');
        final specIds =
            List<Map<String, dynamic>>.from(
              specResponse,
            ).map((e) => e['id']).toList();

        // PRO FIX: 2. Safely find matching clinics
        final clinicResponse = await _client
            .from('clinics')
            .select('id')
            .ilike('name', '%$query%');
        final clinicIds =
            List<Map<String, dynamic>>.from(
              clinicResponse,
            ).map((e) => e['id']).toList();

        // PRO FIX: 3. Find doctors that work in those clinics
        List<int> docIdsFromClinics = [];
        if (clinicIds.isNotEmpty) {
          final junctionResponse = await _client
              .from('doctor_clinics')
              .select('doctor_id')
              .inFilter('clinic_id', clinicIds);
          docIdsFromClinics =
              List<Map<String, dynamic>>.from(
                junctionResponse,
              ).map((e) => e['doctor_id'] as int).toList();
        }

        // PRO FIX: 4. Construct the ultimate safe OR query using ONLY local doctor table columns
        List<String> orConditions = ['full_name.ilike."%$query%"'];
        if (specIds.isNotEmpty) {
          orConditions.add('specialty_id.in.(${specIds.join(',')})');
        }
        if (docIdsFromClinics.isNotEmpty) {
          orConditions.add('id.in.(${docIdsFromClinics.join(',')})');
        }

        dbQuery = dbQuery.or(orConditions.join(','));
      }

      if (countryIso != null && countryIso.isNotEmpty) {
        dbQuery = dbQuery.eq('country_iso', countryIso);
      } else if (userLocation != null && userLocation.isNotEmpty) {
        dbQuery = dbQuery.eq('location', userLocation);
      }

      if (userLat == null || userLng == null) {
        final response = await dbQuery.order('rating', ascending: false);
        return List<Map<String, dynamic>>.from(response);
      } else {
        final response = await dbQuery;
        var data = List<Map<String, dynamic>>.from(response);
        data.sort(
          (a, b) => _getMinDistance(
            a,
            userLat,
            userLng,
          ).compareTo(_getMinDistance(b, userLat, userLng)),
        );
        return data;
      }
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to perform global search right now.',
      );
    }
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

  Future<List<Map<String, dynamic>>> fetchPopularDoctors({
    String? query,
    int? limit,
    bool forceRefresh = false,
    String? userLocation,
    String? countryIso,
  }) async {
    final isSearch = query != null && query.isNotEmpty;
    final data = await _fetchWithCache(
      cacheKey: isSearch ? null : 'popular_doctors_$countryIso',
      forceRefresh: forceRefresh,
      fetcher: () async {
        var dbQuery = _client
            .from('doctors')
            .select('*, specialties(name)')
            .eq('is_popular', true);
        if (isSearch) {
          dbQuery = dbQuery.ilike('full_name', '%$query%');
        }

        if (countryIso != null && countryIso.isNotEmpty) {
          dbQuery = dbQuery.eq('country_iso', countryIso);
        } else if (userLocation != null && userLocation.isNotEmpty) {
          dbQuery = dbQuery.eq('location', userLocation);
        }

        final response = await dbQuery.order('rating', ascending: false);
        return List<Map<String, dynamic>>.from(response);
      },
    );
    return limit != null ? data.take(limit).toList() : data;
  }

  Future<List<Map<String, dynamic>>> fetchFeaturedDoctors({
    String? query,
    int? limit,
    bool forceRefresh = false,
    String? userLocation,
    String? countryIso,
  }) async {
    final isSearch = query != null && query.isNotEmpty;
    final data = await _fetchWithCache(
      cacheKey: isSearch ? null : 'featured_doctors_$countryIso',
      forceRefresh: forceRefresh,
      fetcher: () async {
        var dbQuery = _client
            .from('doctors')
            .select('*, specialties(name)')
            .eq('is_featured', true);
        if (isSearch) {
          dbQuery = dbQuery.ilike('full_name', '%$query%');
        }

        if (countryIso != null && countryIso.isNotEmpty) {
          dbQuery = dbQuery.eq('country_iso', countryIso);
        } else if (userLocation != null && userLocation.isNotEmpty) {
          dbQuery = dbQuery.eq('location', userLocation);
        }

        final response = await dbQuery.order('rating', ascending: false);
        return List<Map<String, dynamic>>.from(response);
      },
    );
    return limit != null ? data.take(limit).toList() : data;
  }

  Future<List<Map<String, dynamic>>> fetchDoctorsBySpecialty(
    String specialtyId, {
    String? query,
    String? userLocation,
    String? countryIso,
  }) async {
    final isSearch = query != null && query.isNotEmpty;
    return _fetchWithCache(
      cacheKey: isSearch ? null : 'specialty_${specialtyId}_$countryIso',
      fetcher: () async {
        var dbQuery = _client
            .from('doctors')
            .select('*, specialties(name)')
            .eq('specialty_id', specialtyId);
        if (isSearch) {
          dbQuery = dbQuery.ilike('full_name', '%$query%');
        }

        if (countryIso != null && countryIso.isNotEmpty) {
          dbQuery = dbQuery.eq('country_iso', countryIso);
        } else if (userLocation != null && userLocation.isNotEmpty) {
          dbQuery = dbQuery.eq('location', userLocation);
        }

        final response = await dbQuery.order('rating', ascending: false);
        return List<Map<String, dynamic>>.from(response);
      },
    );
  }

  Future<List<Map<String, dynamic>>> fetchDoctorsByClinic(
    int clinicId, {
    String? query,
  }) async {
    final isSearch = query != null && query.isNotEmpty;
    return _fetchWithCache(
      cacheKey: isSearch ? null : 'clinic_$clinicId',
      fetcher: () async {
        var dbQuery = _client
            .from('doctors')
            .select('*, specialties(name), doctor_clinics!inner(*)')
            .eq('doctor_clinics.clinic_id', clinicId);
        if (isSearch) dbQuery = dbQuery.ilike('full_name', '%$query%');
        final response = await dbQuery;
        return List<Map<String, dynamic>>.from(response);
      },
    );
  }

  Future<List<Map<String, dynamic>>> fetchSpecialties({
    int limit = 10,
    bool forceRefresh = false,
  }) async {
    final data = await _fetchWithCache(
      cacheKey: 'specialties_list',
      forceRefresh: forceRefresh,
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
  }) async {
    final isSearch = query != null && query.isNotEmpty;
    return _fetchWithCache(
      cacheKey: isSearch ? null : 'facilities_$type',
      fetcher: () async {
        var dbQuery = _client.from('clinics').select().eq('type', type);
        if (isSearch) dbQuery = dbQuery.ilike('name', '%$query%');
        final response = await dbQuery;
        return List<Map<String, dynamic>>.from(response);
      },
    );
  }

  Future<List<Map<String, dynamic>>> fetchHospitals({String? query}) async =>
      fetchFacilities(type: 'hospital', query: query);
  Future<List<Map<String, dynamic>>> fetchClinicsList({String? query}) async =>
      fetchFacilities(type: 'clinic', query: query);

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
    if (NetworkNotifier.instance.isOffline) {
      await _queueAction('toggle_favorite', {
        'doctor_id': doctorId,
        'user_id': userId,
        'isFavorite': isFavorite,
      });
      return;
    }

    // PRO FIX: Added Sync Guard here as well. If the user hits "like" the moment
    // internet returns, this pauses the action so it doesn't conflict with the queue!
    await NetworkNotifier.instance.waitForSync();

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
