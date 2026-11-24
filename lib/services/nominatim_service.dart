import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/trip_models.dart';

/// Client for Nominatim OpenStreetMap geocoding search.
class NominatimService {
  NominatimService._();

  static const String _baseUrl =
      'https://nominatim.openstreetmap.org/search';
  static const String _userAgent = 'RideTrackingApp/1.0';

  /// Searches for places matching [query].
  ///
  /// Results should be debounced by the caller to respect Nominatim's usage policy.
  static Future<List<PlaceSuggestion>> search(String query) async {
    if (query.trim().isEmpty) return const [];

    final url = Uri.parse(_baseUrl).replace(queryParameters: {
      'format': 'json',
      'q': query.trim(),
      'limit': '10',
      'addressdetails': '1',
      'accept-language': 'en',
    });

    try {
      final response = await http.get(
        url,
        headers: {
          'User-Agent': _userAgent,
          'Accept-Language': 'en',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return const [];

      final list = jsonDecode(response.body) as List?;
      if (list == null) return const [];

      return list
          .map((json) => PlaceSuggestion.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}