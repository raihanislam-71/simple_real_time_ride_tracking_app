import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app_constants.dart';
import '../models/trip_models.dart';
import '../services/location_service.dart';
import '../services/osrm_service.dart';
import '../utils/geo_utils.dart';
import 'location_search_sheet.dart';
import 'trip_info_sheet.dart';

class RideTrackingScreen extends StatefulWidget {
  const RideTrackingScreen({super.key});

  @override
  State<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends State<RideTrackingScreen> {
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();

  // Positions
  LatLng _riderPosition = AppConstants.riderStart;
  double _riderBearing = 45.0;

  // Default user location (Dhaka near rider start)
  static const LatLng _defaultUserPosition = LatLng(23.828500, 90.368500);
  LatLng? _userPosition;

  // Destination
  LatLng? _destinationPosition;
  String? _destinationName;

  // Route & Animation
  List<LatLng> _routePoints = [];
  double _totalRouteDistanceKm = 0.0;
  double _totalDurationMin = 0.0;
  double _distanceTraveledKm = 0.0;

  TripStatus _tripStatus = TripStatus.idle;
  Timer? _rideTimer;
  bool _isLoadingRoute = false;

  @override
  void initState() {
    super.initState();
    _userPosition = _defaultUserPosition;
    _initLiveLocation();
  }

  @override
  void dispose() {
    _rideTimer?.cancel();
    super.dispose();
  }

  Future<void> _initLiveLocation() async {
    try {
      final pos = await _locationService.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _userPosition = LatLng(pos.latitude, pos.longitude);
      });
    } catch (_) {
      // Fallback already assigned
    }
  }

  /// Sets destination and fetches the road polyline.
  Future<void> _setDestination(LatLng dest, {String? name}) async {
    setState(() {
      _destinationPosition = dest;
      _destinationName = name ?? 'Selected Location';
      _isLoadingRoute = true;
      _tripStatus = TripStatus.idle;
    });

    _rideTimer?.cancel();
    _distanceTraveledKm = 0.0;

    final userLoc = _userPosition ?? _defaultUserPosition;
    final waypoints = [_riderPosition, userLoc, dest];

    OsrmRoute? route;
    try {
      route = await OsrmService.fetchRoute(waypoints: waypoints);
    } catch (_) {
      route = null;
    }

    if (!mounted) return;

    if (route != null && route.geometry.isNotEmpty) {
      setState(() {
        _routePoints = route!.geometry;
        _totalRouteDistanceKm = route.distanceKm;
        _totalDurationMin = route.durationMin;
        _isLoadingRoute = false;
      });
    } else {
      // Fallback straight lines with intermediate interpolation
      final fallbackPoints = <LatLng>[_riderPosition, userLoc, dest];
      setState(() {
        _routePoints = fallbackPoints;
        _totalRouteDistanceKm = polylineLengthKm(fallbackPoints);
        _totalDurationMin =
            (_totalRouteDistanceKm / AppConstants.riderSpeedKmh) * 60;
        _isLoadingRoute = false;
      });
    }

    _fitRouteBounds();
  }

  /// Starts the rider's smooth animation along the polyline.
  void _startRide() {
    if (_routePoints.length < 2) return;

    setState(() {
      _tripStatus = TripStatus.inProgress;
      _distanceTraveledKm = 0.0;
    });

    _rideTimer?.cancel();

    // Rider travel increment per tick (~33ms)
    // Speed: 28 km/h -> ~0.0077 km/s
    const intervalMs = 33;
    final speedKmh = AppConstants.riderSpeedKmh;
    final deltaKmPerTick = (speedKmh / 3600.0) * (intervalMs / 1000.0);

    _rideTimer = Timer.periodic(
      const Duration(milliseconds: intervalMs),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        final nextDistance = _distanceTraveledKm + deltaKmPerTick;

        if (nextDistance >= _totalRouteDistanceKm) {
          timer.cancel();
          setState(() {
            _distanceTraveledKm = _totalRouteDistanceKm;
            _riderPosition = _routePoints.last;
            _tripStatus = TripStatus.arrived;
          });
          return;
        }

        final interpolated = interpolateAlongPolyline(
          _routePoints,
          distanceKm: nextDistance,
        );

        setState(() {
          _distanceTraveledKm = nextDistance;
          _riderPosition = interpolated.point;
          _riderBearing = interpolated.bearing;
        });
      },
    );
  }

  /// Fits map bounds to encompass all active waypoints.
  void _fitRouteBounds() {
    final pointsToFit = <LatLng>[
      _riderPosition,
      _userPosition ?? _defaultUserPosition,
      ?_destinationPosition,
      ..._routePoints,
    ];

    if (pointsToFit.isEmpty) return;

    try {
      final bounds = LatLngBounds.fromPoints(pointsToFit);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.fromLTRB(40, 100, 40, 320),
        ),
      );
    } catch (_) {
      _mapController.move(_riderPosition, AppConstants.initialZoom);
    }
  }

  /// Centers map directly on current rider / user position.
  void _centerOnUserOrRider() {
    _mapController.move(
      _tripStatus == TripStatus.inProgress
          ? _riderPosition
          : (_userPosition ?? _riderPosition),
      15.5,
    );
  }

  /// Opens destination search dialog.
  Future<void> _openSearch() async {
    final PlaceSuggestion? selected = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const LocationSearchSheet(),
    );

    if (selected != null) {
      _setDestination(selected.latLng, name: selected.displayName);
    }
  }

  double get _remainingDistanceKm =>
      (_totalRouteDistanceKm - _distanceTraveledKm).clamp(0.0, _totalRouteDistanceKm);

  double get _remainingDurationMin {
    if (_totalRouteDistanceKm <= 0) return 0.0;
    final ratio = _remainingDistanceKm / _totalRouteDistanceKm;
    return ratio * _totalDurationMin;
  }

  @override
  Widget build(BuildContext context) {
    final isRideActive = _tripStatus == TripStatus.inProgress ||
        _tripStatus == TripStatus.arrived;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Full-screen OpenStreetMap
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _riderPosition,
              initialZoom: AppConstants.initialZoom,
              onTap: (_, point) {
                if (_tripStatus != TripStatus.inProgress) {
                  _setDestination(point, name: 'Pinned Location');
                }
              },
            ),
            children: [
              // Tile Layer
              TileLayer(
                urlTemplate: AppConstants.osmTileUrl,
                userAgentPackageName: 'com.example.simple_real_time_ride_tracking_app',
              ),

              // Polyline Layer (Blue road route)
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 5.0,
                      color: const Color(0xFF007AFF),
                    ),
                  ],
                ),

              // Marker Layer
              MarkerLayer(
                markers: [
                  // Rider Marker with green ring halo and car icon
                  Marker(
                    point: _riderPosition,
                    width: 54,
                    height: 54,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Light green outer halo
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                const Color(0xFF10B981).withValues(alpha: 0.25),
                            border: Border.all(
                              color: const Color(0xFF10B981),
                              width: 2.2,
                            ),
                          ),
                        ),
                        // Inner white center circle
                        Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                        // White car asset rotated to bearing
                        Transform.rotate(
                          angle: _riderBearing * (math.pi / 180.0),
                          child: Image.asset(
                            'assets/white_car.png',
                            width: 38,
                            height: 38,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // User Pickup Location Marker
                  if (_userPosition != null)
                    Marker(
                      point: _userPosition!,
                      width: 36,
                      height: 36,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF007AFF)
                                  .withValues(alpha: 0.25),
                            ),
                          ),
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF007AFF),
                              border:
                                  Border.all(color: Colors.white, width: 2.5),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Destination Marker
                  if (_destinationPosition != null)
                    Marker(
                      point: _destinationPosition!,
                      width: 44,
                      height: 44,
                      child: const Icon(
                        Icons.location_on,
                        color: Color(0xFFDC2626),
                        size: 40,
                      ),
                    ),
                ],
              ),
            ],
          ),

          // 2. Top Banner or Search Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: isRideActive
                ? _buildTopRideStatusBanner()
                : _buildTopSearchBar(),
          ),

          // 3. Right Side Map Controls (Target & Fullscreen/Recenter)
          Positioned(
            right: 16,
            bottom: isRideActive
                ? 290
                : (_destinationPosition != null ? 140 : 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCircularMapButton(
                  icon: Icons.my_location,
                  iconColor: const Color(0xFF007AFF),
                  onTap: _centerOnUserOrRider,
                ),
                const SizedBox(height: 12),
                _buildCircularMapButton(
                  icon: Icons.fullscreen_rounded,
                  iconColor: const Color(0xFF4B5563),
                  onTap: _fitRouteBounds,
                ),
              ],
            ),
          ),

          // 4. Destination Selected Prompt ("Start Ride" Button before ride begins)
          if (!isRideActive && _destinationPosition != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: _buildStartRideCard(),
            ),

          // 5. Bottom Info Dialog (Matches reference UI exactly when ride starts)
          if (isRideActive)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: TripInfoSheet(
                remainingDurationMin: _remainingDurationMin,
                remainingDistanceKm: _remainingDistanceKm,
                driverName: AppConstants.driverName,
                rating: AppConstants.rating,
                plateNumber: AppConstants.plateNumber,
                vehicleName: AppConstants.carModel,
                onEmergency: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: Colors.red,
                      content: Text('Emergency alert sent to support!'),
                    ),
                  );
                },
                onShare: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ride details link copied to share!'),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  /// Top floating banner: "Your ride is on the way | Arrives in X min"
  Widget _buildTopRideStatusBanner() {
    final min = _remainingDurationMin.round();
    final arrivesText = _tripStatus == TripStatus.arrived
        ? 'Arrived at destination'
        : 'Arrives in ${min < 1 ? 1 : min} min';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F8EE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.directions_car_rounded,
              color: Color(0xFF22C55E),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Your ride is on the way',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      arrivesText,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Top floating search bar before ride begins.
  Widget _buildTopSearchBar() {
    return GestureDetector(
      onTap: _openSearch,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: Color(0xFF007AFF), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _destinationName ?? 'Search destination or tap on map...',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _destinationName != null
                      ? const Color(0xFF1F2937)
                      : Colors.grey[500],
                ),
              ),
            ),
            if (_isLoadingRoute)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.tune, size: 18, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  /// Card with "Start Ride" button when destination has been selected.
  Widget _buildStartRideCard() {
    final estMin = _totalDurationMin.round();
    final distKm = _totalRouteDistanceKm.toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.route_rounded,
                  color: Color(0xFF007AFF),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _destinationName ?? 'Destination Marked',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Est. $estMin min ($distKm km)',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isLoadingRoute ? null : _startRide,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.navigation_rounded, size: 20),
              label: const Text(
                'Start Ride',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Circular white button on the map right side.
  Widget _buildCircularMapButton({
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
      ),
    );
  }
}
