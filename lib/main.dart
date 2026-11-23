import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ride App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'SF Pro Text',
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  // Example locations for start and end points (San Francisco)
  final LatLng _startPoint = const LatLng(37.7749, -122.4194);
  final LatLng _destinationPoint = const LatLng(37.7839, -122.4194);

  List<LatLng> _routePoints = [];
  bool _routeLoaded = false;

  LatLng _vehiclePosition = const LatLng(37.7749, -122.4194);
  double _vehicleRotation = 0.0;
  Timer? _timer;
  int _currentRouteIndex = 0;
  double _progress = 0.0;
  bool _isFollowingVehicle = true;
  Timer? _followTimer;

  final double _constantSpeed = 40.0; // km/h
  double _totalRouteDistance = 0.0;
  double _distanceTraveled = 0.0;

  final String _vehicleType = 'Sedan';
  final String _driverName = 'Raihan Islam';
  String _estimatedTime = 'Calculating...';
  String _distance = 'Calculating...';
  final String _rating = '4.9';
  final String _plateNumber = 'ABC1234';
  final String _carModel = 'Toyota Camry';

  late AnimationController _vehicleAnimationController;
  late AnimationController _bottomSheetController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _vehicleAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _bottomSheetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _bottomSheetController.forward();
    _vehiclePosition = _startPoint;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchRealRoute();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _followTimer?.cancel();
    _vehicleAnimationController.dispose();
    _bottomSheetController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchRealRoute() async {
    // First, immediately set a fallback route so polyline shows right away
    _fallBackToSimulatedRoute();

    // Then try to fetch real route from OSRM
    try {
      final String url =
          'https://router.project-osrm.org/route/v1/driving/${_startPoint.longitude},${_startPoint.latitude};${_destinationPoint.longitude},${_destinationPoint.latitude}?overview=full&geometries=geojson';
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'Flutter Map Ride Tracker'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final coordinates = route['geometry']['coordinates'] as List;

          _routePoints = coordinates.map<LatLng>((coord) {
            return LatLng(coord[1].toDouble(), coord[0].toDouble());
          }).toList();

          debugPrint('OSRM Route loaded: ${_routePoints.length} points');
          debugPrint('First point: ${_routePoints.first}');
          debugPrint('Last point: ${_routePoints.last}');

          final double distance = route['distance'] / 1000.0;
          final double duration = route['duration'] / 60.0;

          if (mounted) {
            setState(() {
              _vehiclePosition = _routePoints.first;
              _routeLoaded = true;
              _distance = '${distance.toStringAsFixed(1)} km';
              _estimatedTime = '${math.max(1, duration.round())} min';
              _totalRouteDistance = distance;
              _distanceTraveled = 0.0;
            });
          }

          _startVehicleTracking();
          _fitRouteBounds();
        } else {
          debugPrint('No routes found in OSRM response, using fallback');
        }
      } else {
        debugPrint('OSRM returned status ${response.statusCode}, using fallback');
      }
    } catch (e) {
      debugPrint('OSRM error (using fallback): $e');
    }
  }

  void _fitRouteBounds() {
    if (_routePoints.isEmpty) return;
    _isFollowingVehicle = false; // শুরুতে পুরো পলিলাইন দেখানোর জন্য
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        try {
          double minLat = _routePoints.map((p) => p.latitude).reduce(math.min);
          double maxLat = _routePoints.map((p) => p.latitude).reduce(math.max);
          double minLng = _routePoints.map((p) => p.longitude).reduce(math.min);
          double maxLng = _routePoints.map((p) => p.longitude).reduce(math.max);

          LatLng center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);

          _mapController.move(center, 14.5);

          // ২.৫ সেকেন্ড পর আবার গাড়ি ফলো করা শুরু করবে
          _followTimer?.cancel();
          _followTimer = Timer(const Duration(milliseconds: 2500), () {
            if (mounted) {
              setState(() {
                _isFollowingVehicle = true;
              });
            }
          });
        } catch (e) {
          debugPrint('Map move error: $e');
        }
      }
    });
  }

  // Simulated route for fallback - creates a visible polyline
  void _fallBackToSimulatedRoute() {
    // Create a more visible route with more points
    _routePoints = [
      _startPoint,
      const LatLng(37.7760, -122.4180),
      const LatLng(37.7770, -122.4170),
      const LatLng(37.7780, -122.4185),
      const LatLng(37.7790, -122.4200),
      const LatLng(37.7800, -122.4190),
      const LatLng(37.7810, -122.4195),
      const LatLng(37.7820, -122.4185),
      _destinationPoint,
    ];

    debugPrint('Fallback route set: ${_routePoints.length} points');

    double totalDistance = 0.0;
    for (int i = 0; i < _routePoints.length - 1; i++) {
      totalDistance += _calculateDistanceBetween(
        _routePoints[i],
        _routePoints[i + 1],
      );
    }

    if (mounted) {
      setState(() {
        _vehiclePosition = _routePoints.first;
        _routeLoaded = true;
        _distance = '${totalDistance.toStringAsFixed(1)} km';
        _estimatedTime =
            '${math.max(1, ((totalDistance / _constantSpeed) * 60).round())} min';
        _totalRouteDistance = totalDistance;
        _distanceTraveled = 0.0;
      });
    }

    _startVehicleTracking();
    _fitRouteBounds();
  }

  double _calculateDistanceBetween(LatLng start, LatLng end) {
    const double earthRadius = 6371.0;
    double lat1Rad = start.latitude * (math.pi / 180);
    double lat2Rad = end.latitude * (math.pi / 180);
    double deltaLatRad = (end.latitude - start.latitude) * (math.pi / 180);
    double deltaLngRad = (end.longitude - start.longitude) * (math.pi / 180);

    double a =
        math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLngRad / 2) *
            math.sin(deltaLngRad / 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  void _startVehicleTracking() {
    if (!_routeLoaded || _routePoints.isEmpty) return;

    _timer?.cancel();

    setState(() {
      _currentRouteIndex = 0;
      _progress = 0.0;
      _vehiclePosition = _routePoints.first;
    });

    _timer = Timer.periodic(const Duration(milliseconds: 33), (timer) {
      if (_currentRouteIndex < _routePoints.length - 1) {
        _updateVehiclePosition();
      } else {
        _timer?.cancel();
        _showRideCompleted();
      }
    });
  }

  void _updateVehiclePosition() {
    if (_currentRouteIndex >= _routePoints.length - 1) return;

    double totalDistanceSoFar = 0.0;
    for (int i = 0; i < _currentRouteIndex; i++) {
      totalDistanceSoFar += _calculateDistanceBetween(
        _routePoints[i],
        _routePoints[i + 1],
      );
    }

    if (_currentRouteIndex < _routePoints.length - 1) {
      double currentSegmentDistance = _calculateDistanceBetween(
        _routePoints[_currentRouteIndex],
        _routePoints[_currentRouteIndex + 1],
      );

      totalDistanceSoFar += currentSegmentDistance * _progress;
    }

    double speedPerUpdate = (_constantSpeed / 3600) * 0.033;
    final double newTotalDistance = totalDistanceSoFar + speedPerUpdate;

    double accumulatedDistance = 0.0;
    int newSegmentIndex = 0;
    double progressInNewSegment = 0.0;

    for (int i = 0; i < _routePoints.length - 1; i++) {
      double segmentDistance = _calculateDistanceBetween(
        _routePoints[i],
        _routePoints[i + 1],
      );

      if (accumulatedDistance + segmentDistance >= newTotalDistance) {
        newSegmentIndex = i;
        double distanceIntoSegment = newTotalDistance - accumulatedDistance;
        progressInNewSegment = segmentDistance > 0
            ? distanceIntoSegment / segmentDistance
            : 0.0;
        break;
      }
      accumulatedDistance += segmentDistance;
      newSegmentIndex = i + 1;
    }

    if (newSegmentIndex >= _routePoints.length - 1) {
      setState(() {
        _vehiclePosition = _routePoints.last;
        if (_routePoints.length >= 2) {
          _vehicleRotation = _calculateBearing(
            _routePoints[_routePoints.length - 2],
            _routePoints.last,
          );
        }
      });

      _timer?.cancel();
      _showRideCompleted();
      return;
    }

    LatLng startPoint = _routePoints[newSegmentIndex];
    LatLng endPoint = _routePoints[newSegmentIndex + 1];

    progressInNewSegment = progressInNewSegment.clamp(0.0, 1.0);

    double lat =
        startPoint.latitude +
        (progressInNewSegment * (endPoint.latitude - startPoint.latitude));

    double lng =
        startPoint.longitude +
        (progressInNewSegment * (endPoint.longitude - startPoint.longitude));

    LatLng newPosition = LatLng(lat, lng);
    double rotation = _calculateBearing(startPoint, endPoint);

    setState(() {
      _currentRouteIndex = newSegmentIndex;
      _progress = progressInNewSegment;
      _vehiclePosition = newPosition;
      _vehicleRotation = rotation;
      _distanceTraveled = newTotalDistance;
      _updateRideDetails();
    });

    if (mounted && _isFollowingVehicle) {
      try {
        _mapController.move(newPosition, _mapController.camera.zoom);
      } catch (e) {
        debugPrint('Camera follow error: $e');
      }
    }
  }

  double _calculateBearing(LatLng start, LatLng end) {
    final dLng = (end.longitude - start.longitude) * (math.pi / 180);
    final lat1 = start.latitude * math.pi / 180;
    final lat2 = end.latitude * math.pi / 180;

    final y = math.sin(dLng) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  void _stopFollowingTemporarily() {
    setState(() {
      _isFollowingVehicle = false;
    });

    _followTimer?.cancel();
    _followTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _isFollowingVehicle = true;
        });
      }
    });
  }

  void _updateRideDetails() {
    double remainingDistance = _totalRouteDistance - _distanceTraveled;
    remainingDistance = math.max(0.0, remainingDistance);

    int remainingTimeInMinutes = (remainingDistance / _constantSpeed * 60)
        .round();
    remainingTimeInMinutes = math.max(1, remainingTimeInMinutes);

    setState(() {
      _distance = '${remainingDistance.toStringAsFixed(1)} km';
      _estimatedTime = '$remainingTimeInMinutes min';
    });
  }

  void _showActionMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showRideCompleted() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 80,
                width: 80,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Ride Completed!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'Thank you for riding with us.',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showActionMessage('Thanks for rating your trip!');
                        _resetRide();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Colors.green),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Rate Trip',
                        style: TextStyle(color: Colors.green),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _resetRide();
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _resetRide() {
    setState(() {
      _currentRouteIndex = 0;
      _progress = 0.0;
      _vehiclePosition = _routePoints.isNotEmpty
          ? _routePoints.first
          : _startPoint;
      _vehicleRotation = 0.0;
      _distanceTraveled = 0.0;
      _isFollowingVehicle = true;
    });

    _fetchRealRoute();
  }

  Widget _buildRideDetails({
    required IconData icon,
    required String label,
    required String value,
    Color? iconColor,
  }) {
    final Color effectiveColor = iconColor ?? Colors.blue;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: effectiveColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: effectiveColor, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            if (_routeLoaded)
              Container(
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                clipBehavior: Clip.hardEdge,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _vehiclePosition,
                    initialZoom: 15.0,
                    onPositionChanged: (MapCamera camera, bool hasGesture) {
                      if (hasGesture) {
                        _stopFollowingTemporarily();
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.ride_app',
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePoints.isNotEmpty ? _routePoints : [_vehiclePosition],
                          color: Colors.blue,
                          strokeWidth: 6.0,
                          borderStrokeWidth: 2.0,
                          borderColor: Colors.white,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          width: 40,
                          height: 40,
                          point: _startPoint,
                          child: AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: 1.0 + (_pulseController.value * 0.15),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.green.withOpacity(0.35),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.my_location,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Marker(
                          width: 40,
                          height: 40,
                          point: _destinationPoint,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                        Marker(
                          width: 60,
                          height: 60,
                          point: _vehiclePosition,
                          child: Transform.rotate(
                            angle: (_vehicleRotation - 180) * math.pi / 180,
                            child: Image.asset(
                              'assets/white_car.png',
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.blueAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.directions_car,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.blue[50]!, Colors.white],
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Fetching Route...',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.grey[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please wait while we calculate the best route for your ride.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            if (_routeLoaded)
              Container(
                height: 82,
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.directions_car,
                        color: Colors.green,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Ride is on the way',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Arrives in $_estimatedTime',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            if (_routeLoaded)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(_bottomSheetController),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    constraints: BoxConstraints(
                      minHeight: 250,
                      maxHeight: MediaQuery.of(context).size.height * 0.7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.blue[400]!,
                                      Colors.blue[600]!,
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _driverName,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _carModel,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 2,
                                            horizontal: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green[100],
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.star,
                                                color: Colors.green[700],
                                                size: 14,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                _rating,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.green[700],
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          _plateNumber,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[700],
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      onPressed: () => _showActionMessage(
                                        'Calling $_driverName...',
                                      ),
                                      icon: Icon(
                                        Icons.phone,
                                        color: Colors.green[700],
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      onPressed: () => _showActionMessage(
                                        'Opening chat with $_driverName...',
                                      ),
                                      icon: Icon(
                                        Icons.message,
                                        color: Colors.blue[700],
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildRideDetails(
                              icon: Icons.access_time_filled,
                              label: 'Duration',
                              value: _estimatedTime,
                              iconColor: Colors.blue,
                            ),
                            _buildRideDetails(
                              icon: Icons.route,
                              label: 'Distance',
                              value: _distance,
                              iconColor: Colors.orange,
                            ),
                            _buildRideDetails(
                              icon: Icons.directions_car,
                              label: 'Vehicle',
                              value: _vehicleType,
                              iconColor: Colors.purple,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _showActionMessage(
                                  'Ride link copied to clipboard!',
                                ),
                                label: const Text(
                                  'Share',
                                  style: TextStyle(color: Colors.blue),
                                ),
                                icon: const Icon(
                                  Icons.share,
                                  color: Colors.blue,
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  side: BorderSide(color: Colors.grey[300]!),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _showActionMessage(
                                  'Emergency alert triggered!',
                                ),
                                label: const Text('Emergency'),
                                icon: const Icon(Icons.warning),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            if (_routeLoaded)
              Positioned(
                top: 108,
                right: 15,
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: FloatingActionButton(
                        heroTag: 'follow_btn',
                        mini: true,
                        onPressed: () {
                          setState(() {
                            _isFollowingVehicle = !_isFollowingVehicle;
                          });

                          if (_isFollowingVehicle) {
                            try {
                              _mapController.move(_vehiclePosition, 16);
                            } catch (e) {
                              debugPrint('Map move error: $e');
                            }
                          }
                        },
                        backgroundColor: Colors.white,
                        elevation: 0,
                        child: Icon(
                          _isFollowingVehicle
                              ? Icons.gps_fixed
                              : Icons.gps_not_fixed,
                          color: _isFollowingVehicle ? Colors.blue : Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: FloatingActionButton(
                        heroTag: 'zoom_out_btn',
                        mini: true,
                        onPressed: () {
                          if (_routePoints.isNotEmpty) {
                            try {
                              double minLat = _routePoints
                                  .map((p) => p.latitude)
                                  .reduce(math.min);
                              double maxLat = _routePoints
                                  .map((p) => p.latitude)
                                  .reduce(math.max);
                              double minLng = _routePoints
                                  .map((p) => p.longitude)
                                  .reduce(math.min);
                              double maxLng = _routePoints
                                  .map((p) => p.longitude)
                                  .reduce(math.max);

                              LatLng center = LatLng(
                                (minLat + maxLat) / 2,
                                (minLng + maxLng) / 2,
                              );

                              _mapController.move(center, 15.0);
                              _stopFollowingTemporarily();
                            } catch (e) {
                              debugPrint('Zoom out error: $e');
                            }
                          }
                        },
                        backgroundColor: Colors.white,
                        elevation: 0,
                        child: Icon(
                          Icons.zoom_out_map,
                          color: Colors.grey[700],
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
