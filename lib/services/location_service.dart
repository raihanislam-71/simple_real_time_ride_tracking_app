import 'package:geolocator/geolocator.dart';

/// Thrown when location access cannot be granted.
class LocationException implements Exception {
  final String message;
  const LocationException(this.message);

  @override
  String toString() => message;
}

/// Wrapper around [geolocator] for permissions and live GPS updates.
class LocationService {
  /// Whether the device location service (GPS) is enabled.
  Future<bool> isServiceEnabled() async => Geolocator.isLocationServiceEnabled();

  /// Current location permission status.
  Future<LocationPermission> checkPermission() async =>
      Geolocator.checkPermission();

  /// Requests location permission (while-in-use).
  Future<LocationPermission> requestPermission() async =>
      Geolocator.requestPermission();

  /// Ensures location permission is granted; throws [LocationException] otherwise.
  Future<LocationPermission> ensurePermission() async {
    final status = await Geolocator.checkPermission();
    if (status == LocationPermission.deniedForever) {
      throw const LocationException(
        'Location permissions are permanently denied. '
        'Enable them in app settings.',
      );
    }
    if (status == LocationPermission.denied) {
      final requested = await Geolocator.requestPermission();
      if (requested != LocationPermission.whileInUse &&
          requested != LocationPermission.always) {
        throw const LocationException('Location permission was denied.');
      }
    }
    return await Geolocator.checkPermission();
  }

  /// One-shot current position.
  Future<Position> getCurrentPosition() async {
    await ensurePermission();
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  /// Continuous live position stream.
  Stream<Position> positionStream({int distanceFilter = 5}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
      ),
    );
  }

  /// Opens system location settings so the user can enable GPS/permissions.
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  /// Opens app settings so the user can grant permanent permissions.
  Future<void> openAppSettings() => Geolocator.openAppSettings();
}