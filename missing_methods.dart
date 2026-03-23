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
    bool forceRefresh = false, // PRO FIX: Added missing parameter!
  }) async {
    final isSearch = query != null && query.isNotEmpty;
    final cacheKey =
        (isSearch || userLat != null) ? null : 'all_doctors_$countryIso';

    return _fetchWithCache(
      cacheKey: cacheKey,
      forceRefresh: forceRefresh, // Passed safely down to cache engine
      fetcher: () async {
        var dbQuery = _client
            .from('doctors')
            .select(
              '*, specialties(name), doctor_clinics(clinics(latitude, longitude, logo_url))',
            );

        if (isSearch) {
          final specResponse = await _client
              .from('specialties')
              .select('id')
              .ilike('name', '%$query%');

          final specIds =
              List<Map<String, dynamic>>.from(
                specResponse,
              ).map((e) => e['id']).toList();

          if (specIds.isNotEmpty) {
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
            '*, specialties(name), doctor_clinics(clinics(name, latitude, longitude, logo_url))',
          );

      if (query.isNotEmpty) {
        final specResponse = await _client
            .from('specialties')
            .select('id')
            .ilike('name', '%$query%');
        final specIds =
            List<Map<String, dynamic>>.from(
              specResponse,
            ).map((e) => e['id']).toList();

        final clinicResponse = await _client
            .from('clinics')
            .select('id')
            .ilike('name', '%$query%');
        final clinicIds =
            List<Map<String, dynamic>>.from(
              clinicResponse,
            ).map((e) => e['id']).toList();

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
          .select('id, name, address, logo_url')
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
    void Function(List<Map<String, dynamic>>)? onFreshData,
  }) async {
    final isSearch = query != null && query.isNotEmpty;
    final data = await _fetchWithCache(
      cacheKey: isSearch ? null : 'popular_doctors_$countryIso',
      forceRefresh: forceRefresh,
      onFreshData: onFreshData != null ? ((fresh) => onFreshData(limit != null ? fresh.take(limit).toList() : fresh)) : null,
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
    void Function(List<Map<String, dynamic>>)? onFreshData,
  }) async {
    final isSearch = query != null && query.isNotEmpty;
    final data = await _fetchWithCache(
      cacheKey: isSearch ? null : 'featured_doctors_$countryIso',
      forceRefresh: forceRefresh,
      onFreshData: onFreshData != null ? ((fresh) => onFreshData(limit != null ? fresh.take(limit).toList() : fresh)) : null,
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
