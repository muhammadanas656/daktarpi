import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';

class RouteRepository {
  final SupabaseClient _client;

  RouteRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  Future<List<LatLng>> fetchDrivingRoute({
    required LatLng start,
    required LatLng end,
  }) async {
    try {
      // First attempt direct public OSRM lookup with maximum geometry precision
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?geometries=geojson&overview=full',
      );

      try {
        final httpResp = await http
            .get(uri)
            .timeout(const Duration(seconds: 10));
        if (httpResp.statusCode == 200) {
          final data = jsonDecode(httpResp.body);
          final routes = data['routes'] as List<dynamic>? ?? [];
          if (routes.isNotEmpty) {
            final geometry = (routes.first as Map<String, dynamic>)['geometry'];
            final coordinates =
                (geometry as Map<String, dynamic>)['coordinates']
                    as List<dynamic>;
            return coordinates.map((coord) {
              final pair = coord as List<dynamic>;
              return LatLng(
                (pair[1] as num).toDouble(),
                (pair[0] as num).toDouble(),
              );
            }).toList();
          }
        }
      } catch (_) {
        // Fallback to proxy on failure
      }

      final response = await _client.functions.invoke(
        'route-proxy',
        body: {
          'start': {'lat': start.latitude, 'lng': start.longitude},
          'end': {'lat': end.latitude, 'lng': end.longitude},
        },
      );

      if (response.status != 200 || response.data == null) {
        throw const AppFailure(
          type: AppFailureType.backend,
          userMessage: 'Unable to fetch route securely right now.',
          technicalMessage: 'route-proxy function returned non-200 response.',
          code: 'route_proxy_failed',
        );
      }

      final payload = _asMap(response.data!);
      final routes = payload['routes'] as List<dynamic>? ?? const [];
      if (routes.isEmpty) {
        throw const AppFailure(
          type: AppFailureType.validation,
          userMessage: 'No drivable route found for this clinic.',
          technicalMessage: 'route-proxy returned empty routes array.',
          code: 'route_not_found',
        );
      }

      final geometry = (routes.first as Map<String, dynamic>)['geometry'];
      final coordinates = (geometry as Map<String, dynamic>)['coordinates'];
      final points =
          (coordinates as List<dynamic>).map((coord) {
            final pair = coord as List<dynamic>;
            final lng = (pair[0] as num).toDouble();
            final lat = (pair[1] as num).toDouble();
            return LatLng(lat, lng);
          }).toList();

      if (points.isEmpty) {
        throw const AppFailure(
          type: AppFailureType.validation,
          userMessage: 'No drivable route found for this clinic.',
          technicalMessage: 'route-proxy returned empty coordinates.',
          code: 'route_points_empty',
        );
      }

      return points;
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Secure route lookup failed. Please try again.',
      );
    }
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    }
    throw const AppFailure(
      type: AppFailureType.backend,
      userMessage: 'Invalid route response received.',
      technicalMessage: 'Unable to parse route-proxy payload.',
      code: 'route_payload_invalid',
    );
  }
}
