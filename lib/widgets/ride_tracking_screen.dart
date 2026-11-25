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
import 'pick_on_map_screen.dart';
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

  // In-app notification state
  bool _showInAppNotification = false;
  String _notifTitle = '';
  String _notifSubtitle = '';
  bool _notifiedUserPickup = false;
  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    _userPosition = _defaultUserPosition;
    _initLiveLocation();
  }

  @override
  void dispose() {
    _rideTimer?.cancel();
    _notificationTimer?.cancel();
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
      _notifiedUserPickup = false;
      _showInAppNotification = false;
    });

    _rideTimer?.cancel();

    // Rider travel increment per tick (~33ms)
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
          _triggerInAppNotification(
            title: 'Arrived at Destination!',
            subtitle:
                '${AppConstants.driverName} (${AppConstants.carModel} • ${AppConstants.plateNumber}) has reached your destination.',
          );
          return;
        }

        final interpolated = interpolateAlongPolyline(
          _routePoints,
          distanceKm: nextDistance,
        );

        final userLoc = _userPosition ?? _defaultUserPosition;
        final distToUserKm = haversineKm(interpolated.point, userLoc);

        setState(() {
          _distanceTraveledKm = nextDistance;
          _riderPosition = interpolated.point;
          _riderBearing = interpolated.bearing;
        });

        if (!_notifiedUserPickup && distToUserKm <= 0.06) {
          _notifiedUserPickup = true;
          _triggerInAppNotification(
            title: 'Rider Arrived!',
            subtitle:
                '${AppConstants.driverName} (${AppConstants.carModel} • ${AppConstants.plateNumber}) has arrived at your location.',
          );
        }
      },
    );
  }

  void _triggerInAppNotification({
    required String title,
    required String subtitle,
  }) {
    if (!mounted) return;
    setState(() {
      _notifTitle = title;
      _notifSubtitle = subtitle;
      _showInAppNotification = true;
    });
    _notificationTimer?.cancel();
    _notificationTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) {
        setState(() {
          _showInAppNotification = false;
        });
      }
    });
  }

  void _showCancelConfirmationDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cancel_outlined,
                color: Color(0xFFDC2626),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Cancel Ride?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to close and cancel this ride?',
          style: TextStyle(fontSize: 15, color: Color(0xFF374151)),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'No, Keep Ride',
                    style: TextStyle(
                      color: Color(0xFF1F2937),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _rideTimer?.cancel();
                    _notificationTimer?.cancel();
                    setState(() {
                      _tripStatus = TripStatus.idle;
                      _routePoints = [];
                      _destinationPosition = null;
                      _destinationName = null;
                      _distanceTraveledKm = 0.0;
                      _riderPosition = AppConstants.riderStart;
                      _showInAppNotification = false;
                      _notifiedUserPickup = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ride has been cancelled.'),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Yes, Cancel',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openPickOnMap() async {
    final LatLng? picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PickOnMapScreen(
          initialLocation:
              _destinationPosition ?? _userPosition ?? _riderPosition,
        ),
      ),
    );
    if (picked != null && mounted) {
      _setDestination(
        picked,
        name:
            'Pinned (${picked.latitude.toStringAsFixed(4)}, ${picked.longitude.toStringAsFixed(4)})',
      );
    }
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
                            'assets/red_car.png',
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
                ? 345
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
                onCancel: _showCancelConfirmationDialog,
              ),
            ),

          // 6. In-App Arrival Notification Banner
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            top: _showInAppNotification
                ? MediaQuery.of(context).padding.top + 10
                : -160,
            left: 16,
            right: 16,
            child: _buildInAppNotificationBanner(),
          ),
        ],
      ),
    );
  }

  /// Sleek in-app notification banner when rider arrives at user's location.
  Widget _buildInAppNotificationBanner() {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFF10B981).withValues(alpha: 0.6),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.notifications_active_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _notifTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'NOW',
                          style: TextStyle(
                            color: Color(0xFF34D399),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _notifSubtitle,
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 12.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                setState(() {
                  _showInAppNotification = false;
                });
              },
              icon: Icon(
                Icons.close_rounded,
                color: Colors.grey[400],
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
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

  /// Top floating search bar + "Pick on Map" button before ride begins.
  Widget _buildTopSearchBar() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _openSearch,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  const Icon(Icons.search, color: Color(0xFF007AFF), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _destinationName ?? 'Search destination...',
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
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: const Color(0xFF007AFF),
          borderRadius: BorderRadius.circular(20),
          elevation: 4,
          shadowColor: Colors.black.withValues(alpha: 0.2),
          child: InkWell(
            onTap: _openPickOnMap,
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_outlined, color: Colors.white, size: 19),
                  SizedBox(width: 6),
                  Text(
                    'Pick on Map',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
