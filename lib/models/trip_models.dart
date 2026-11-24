import 'package:latlong2/latlong.dart';

/// Status of the current ride.
enum TripStatus {
  idle, // Destination not set yet / ride not started
  pickingUp, // Rider is en route to the user's live location
  inProgress, // Rider picked up the user, heading to destination
  arrived, // Rider reached the destination
  completed, // Ride finished
}

/// A single leg of an OSRM route (between two consecutive waypoints).
class OsrmLeg {
  final double distanceMeters;
  final double durationSeconds;

  OsrmLeg({
    required this.distanceMeters,
    required this.durationSeconds,
  });

  double get distanceKm => distanceMeters / 1000.0;
  double get durationMin => durationSeconds / 60.0;
}

/// Parsed OSRM driving route.
class OsrmRoute {
  final List<LatLng> geometry; // Full road polyline (lat/lng)
  final double distanceMeters; // Total route distance
  final double durationSeconds; // Total estimated duration
  final List<OsrmLeg> legs; // Per-leg distance/duration

  OsrmRoute({
    required this.geometry,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.legs,
  });

  double get distanceKm => distanceMeters / 1000.0;
  double get durationMin => durationSeconds / 60.0;

  /// Cumulative distance (km) at the end of each leg,
  /// e.g. [leg0Km, leg0Km + leg1Km, ...].
  List<double> get legBoundariesKm {
    final boundaries = <double>[];
    var accumulated = 0.0;
    for (final leg in legs) {
      accumulated += leg.distanceKm;
      boundaries.add(accumulated);
    }
    return boundaries;
  }

  factory OsrmRoute.fromJson(Map<String, dynamic> json) {
    final coordinates = (json['geometry']['coordinates'] as List)
        .map<LatLng>((c) => LatLng(
            (c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();
    final legs = (json['legs'] as List)
        .map<OsrmLeg>((l) => OsrmLeg(
            distanceMeters: (l['distance'] as num).toDouble(),
            durationSeconds: (l['duration'] as num).toDouble()))
        .toList();
    return OsrmRoute(
      geometry: coordinates,
      distanceMeters: (json['distance'] as num).toDouble(),
      durationSeconds: (json['duration'] as num).toDouble(),
      legs: legs,
    );
  }
}

/// A place suggestion returned by Nominatim geocoding.
class PlaceSuggestion {
  final String displayName;
  final String? address;
  final double lat;
  final double lon;

  PlaceSuggestion({
    required this.displayName,
    this.address,
    required this.lat,
    required this.lon,
  });

  LatLng get latLng => LatLng(lat, lon);

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    return PlaceSuggestion(
      displayName: json['display_name'] ?? 'Unknown place',
      address: json['display_name'],
      lat: double.tryParse(json['lat']?.toString() ?? '') ?? 0.0,
      lon: double.tryParse(json['lon']?.toString() ?? '') ?? 0.0,
    );
  }
}