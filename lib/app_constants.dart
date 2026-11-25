import 'package:latlong2/latlong.dart';

/// Centralized constants for the ride tracking feature.
class AppConstants {
  AppConstants._();

  /// Fixed rider (driver) starting location — Dhaka, Bangladesh.
  static const LatLng riderStart = LatLng(23.837507, 90.369993);

  /// OpenStreetMap tile layer.
  static const String osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String osmUserAgent = 'RideTrackingApp';

  /// OSRM public routing server.
  static const String osrmBaseUrl = 'https://router.project-osrm.org';
  static const String osrmUserAgent = 'RideTrackingApp';

  /// Nominatim geocoding server.
  static const String nominatimBaseUrl =
      'https://nominatim.openstreetmap.org/search';
  static const String nominatimUserAgent = 'RideTrackingApp/1.0';

  /// Rider animation speed along the route.
  static const double riderSpeedKmh = 25.0;
  static const Duration animationInterval = Duration(milliseconds: 33);

  /// Map zoom levels.
  static const double initialZoom = 14.5;

  /// Default driver / trip details shown in the bottom info sheet.
  static const String driverName = 'Sarah Wilson';
  static const String carModel = 'Sedan';
  static const String plateNumber = 'ABC1234';
  static const String rating = '4.9';
}