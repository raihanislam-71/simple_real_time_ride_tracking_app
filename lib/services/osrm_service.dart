import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/trip_models.dart';

/// Client for the public OSRM routing service (router.project-osrm.org).
class OsrmService {
  OsrmService._();

  static const String _baseUrl = 'https://router.project-osrm.org';
  static const String _userAgent = 'RideTrackingApp';

  /// Fetches a driving route through [waypoints] in the given order.
  ///
  /// Returns the full road polyline geometry plus per-leg distance/duration,
  /// or `null` if the request fails.
  static Future<OsrmRoute?> fetchRoute({
    required List<LatLng> waypoints,
  }) async {
    if (waypoints.length < 2) return null;

    final coordinates = waypoints
        .map(
          (p) =>
              '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}',
        )
        .join(';');

    final url = Uri.parse('$_baseUrl/route/v1/driving/$coordinates')
        .replace(queryParameters: {
      'overview': 'full',
      'geometries': 'geojson',
      'annotations': 'true',
    });

    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': _userAgent},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;

      return OsrmRoute.fromJson(routes.first as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}