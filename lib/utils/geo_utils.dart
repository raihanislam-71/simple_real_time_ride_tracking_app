import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

const double _earthRadiusKm = 6371.0;

double _toRadians(double degrees) => degrees * math.pi / 180.0;

/// Great-circle distance between two coordinates in kilometers.
double haversineKm(LatLng a, LatLng b) {
  final lat1 = _toRadians(a.latitude);
  final lat2 = _toRadians(b.latitude);
  final dLat = _toRadians(b.latitude - a.latitude);
  final dLng = _toRadians(b.longitude - a.longitude);

  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLng / 2), 2);
  return 2 * _earthRadiusKm * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}

/// Bearing from [from] to [to] in degrees (0 = North, clockwise).
double bearingDegrees(LatLng from, LatLng to) {
  final dLng = _toRadians(to.longitude - from.longitude);
  final lat1 = _toRadians(from.latitude);
  final lat2 = _toRadians(to.latitude);

  final y = math.sin(dLng) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

/// The position and bearing at [distanceKm] traveled along a polyline.
class InterpolatedPoint {
  final LatLng point;
  final double bearing;
  const InterpolatedPoint({required this.point, required this.bearing});
}

/// Interpolates a [LatLng] + bearing at [distanceKm] along [points].
/// Clamps to the last point when [distanceKm] exceeds the polyline length.
InterpolatedPoint interpolateAlongPolyline(
  List<LatLng> points, {
  required double distanceKm,
}) {
  if (points.isEmpty) {
    throw ArgumentError('points must not be empty');
  }
  if (points.length == 1 || distanceKm <= 0) {
    return InterpolatedPoint(
      point: points.first,
      bearing: points.length > 1
          ? bearingDegrees(points.first, points[1])
          : 0.0,
    );
  }

  double accumulated = 0.0;
  for (int i = 0; i < points.length - 1; i++) {
    final segment = haversineKm(points[i], points[i + 1]);
    final isLast = i == points.length - 2;

    if (accumulated + segment >= distanceKm || isLast) {
      final intoSegment = math.max(0.0, distanceKm - accumulated);
      final t = segment > 0 ? (intoSegment / segment).clamp(0.0, 1.0) : 0.0;
      return InterpolatedPoint(
        point: LatLng(
          points[i].latitude +
              t * (points[i + 1].latitude - points[i].latitude),
          points[i].longitude +
              t * (points[i + 1].longitude - points[i].longitude),
        ),
        bearing: bearingDegrees(points[i], points[i + 1]),
      );
    }
    accumulated += segment;
  }

  return InterpolatedPoint(
    point: points.last,
    bearing: bearingDegrees(points[points.length - 2], points.last),
  );
}

/// Total polyline length in kilometers.
double polylineLengthKm(List<LatLng> points) {
  double total = 0.0;
  for (int i = 0; i < points.length - 1; i++) {
    total += haversineKm(points[i], points[i + 1]);
  }
  return total;
}