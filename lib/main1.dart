// import 'dart:async';
// import 'dart:convert';
// import 'dart:math' as math;

// import 'package:flutter_map/flutter_map.dart';
// import 'package:http/http.dart' as http;
// import 'package:latlong2/latlong.dart';
// import 'package:material_ui/material_ui.dart';

// void main() {
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       title: 'Ride App',
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//         visualDensity: VisualDensity.adaptivePlatformDensity,
//         fontFamily: 'SF Pto Text',
//       ),
//       home: const HomeScreen(),
//     );
//   }
// }

// class HomeScreen extends StatefulWidget {
//   const new({super.key});

//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }

// class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
//   final MapController _mapController = MapController();
//   //example locations for start and end points
//   final LatLng _startPoint = LatLng(37.7749, -122.4194);
//   final LatLng _destinationPoint = LatLng(37.7839, -122.4194);

//   List<LatLng> _routePoints = [];
//   bool _routeLoaded = false;

//   LatLng _vehiclePosition = LatLng(37.7749, -122.4194);
//   double _vehicleRotation = 0.0;
//   Timer? _timer;
//   int _currentRouteIndex = 0;
//   double _progress = 0.0;
//   bool _isFollowingVehicle = true;
//   Timer? _followTimer;

//   double _constantSpeed = 40.0;
//   double _totalRouteDistance = 0.0;
//   double _distanceTraveled = 0.0;

//   String _vehicleType = 'Sedan';
//   String _driverName = 'Raihan islam';
//   String _estimatedTime = 'Calculate..';
//   String _distance = 'Calculate..';
//   String _rating = '4.9';
//   String _plateNUmber = 'ABC1234';
//   String _carModel = 'Toyota Camry';

//   late AnimationController _vehicleAnimationController;
//   late AnimationController _bottomSheetController;
//   late AnimationController _pulseController;

//   @override
//   void initState() {
//     super.initState();
//     _vehicleAnimationController = AnimationController(
//       vsync: this,
//       duration: const Duration(microseconds: 500),
//     );

//     _bottomSheetController = AnimationController(
//       vsync: this,
//       duration: Duration(microseconds: 300),
//     );

//     _pulseController = AnimationController(
//       vsync: this,
//       duration: Duration(seconds: 2),
//     );

//     _bottomSheetController.forward();

//     setState(() {
//       _vehiclePosition = _startPoint;
//     });

//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _fetchRealRoute();
//     });
//   }

//   @override
//   void dispose() {
//     _timer?.cancel();
//     _followTimer?.cancel();
//     _vehicleAnimationController.dispose();
//     _bottomSheetController.dispose();
//     _pulseController.dispose();
//     super.dispose();
//   }

//   Future<void> _fetchRealRoute() async {
//     try {
//       final String url =
//           'https://router.project-osrm.org/route/v1/driving/${_startPoint.longitude},${_startPoint.latitude};${_destinationPoint.longitude},${_destinationPoint.latitude}?overview=full&geometries=geojson';
//       final response = await http.get(
//         Uri.parse(url),
//         headers: {'User-Agent': 'Flutter Map Example'},
//       );

//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);

//         if (data['routes'] != null && data['routes'].isNotEmpty) {
//           final route = data['routes'][0];
//           final coordinates = route['geometry']['coordinates'] as List;
//           print("${coordinates}-------------------");

//           _routePoints = coordinates.map<LatLng>((coord) {
//             return LatLng(coord[1].toDouble(), coord[0].toDouble());
//           }).toList();

//           final distance = route['distance'] / 1000.0;
//           final duration = route['duration'] / 60.0;

//           setState(() {
//             _vehiclePosition = _routePoints.first;
//             _routeLoaded = true;
//             _distance = '${distance.toStringAsFixed(1)} km';
//             _estimatedTime = '${duration.round()} min';
//             _totalRouteDistance = distance;
//             _distanceTraveled = 0.0;
//           });

//           _startVehicleTracking();

//           if (_routePoints.isNotEmpty) {
//             Future.delayed(Duration(milliseconds: 500), () {
//               if (mounted) {
//                 try {
//                   double minLat = _routePoints
//                       .map((p) => p.latitude)
//                       .reduce(math.min);
//                   double maxLat = _routePoints
//                       .map((p) => p.latitude)
//                       .reduce(math.max);
//                   double minLng = _routePoints
//                       .map((p) => p.latitude)
//                       .reduce(math.min);
//                   double maxLng = _routePoints
//                       .map((p) => p.latitude)
//                       .reduce(math.max);
//                   LatLng center = LatLng(
//                     (minLat + maxLng) / 2,
//                     (minLng + maxLng) / 2,
//                   );

//                   _mapController.move(center, 13);
//                 } catch (e) {
//                   print(e);
//                 }
//               }
//             });
//           }
//         }
//       } else {
//         _fallBackToSimulatedRoute();
//       }
//     } catch (e) {
//       print('Error fetching route: $e');
//       _fallBackToSimulatedRoute();
//     }
//   }

//   //Simulated route for fallback
//   void _fallBackToSimulatedRoute() {
//     _routePoints = [
//       _startPoint,
//       LatLng(37.7799, -122.4194),
//       LatLng(37.7849, -122.4194),
//       LatLng(37.7899, -122.4194),
//       _destinationPoint,
//     ];

//     double _totalDistance = 0.0;
//     for (int i = 0; i < _routePoints.length - 1; i++) {
//       _totalDistance += _calculateDistanceBetween(
//         _routePoints[i],
//         _routePoints[i + 1],
//       );
//     }

//     setState(() {
//       _vehiclePosition = _routePoints.first;
//       _routeLoaded = true;
//       _distance = '${_totalDistance.toStringAsFixed(1)} km';
//       _estimatedTime =
//           '${((_totalDistance / _constantSpeed) * 60).round()} min';
//       _totalRouteDistance = _totalDistance;
//       _distanceTraveled = 0.0;
//     });

//     _startVehicleTracking();
//   }

//   double _calculateDistanceBetween(LatLng start, LatLng end) {
//     const double earthRadius = 6371.0;
//     double lat1Rad = start.latitude * (math.pi / 180);
//     double lat2Rad = end.latitude * (math.pi / 180);
//     double deltaLatRad = (end.latitude - start.latitude) * (math.pi / 180);
//     double deltaLngRad = (end.longitude - start.longitude) * (math.pi / 180);

//     double a =
//         math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
//         math.cos(lat1Rad) *
//             math.cos(lat2Rad) *
//             math.sin(deltaLngRad / 2) *
//             math.sin(deltaLngRad / 2);
//     double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
//     return earthRadius * c;
//   }

//   void _startVehicleTracking() {
//     if (!_routeLoaded || _routePoints.isEmpty) return;

//     _timer?.cancel();

//     setState(() {
//       _currentRouteIndex = 0;
//       _progress = 0.0;
//       _vehiclePosition = _routePoints.first;
//     });

//     _timer = Timer.periodic(const Duration(milliseconds: 33), (timer) {
//       if (_currentRouteIndex < _routePoints.length - 1) {
//         _updateVehiclePosition();
//       } else {
//         _timer?.cancel();
//         _showRideCompleted();
//       }
//     });
//   }

//   void _updateVehiclePosition() {
//     if (_currentRouteIndex >= _routePoints.length - 1) return;

//     double totalDistanceSoFar = 0.0;
//     for (int i = 0; i < _currentRouteIndex; i++) {
//       totalDistanceSoFar += _calculateDistanceBetween(
//         _routePoints[i],
//         _routePoints[i + 1],
//       );
//     }

//     if (_currentRouteIndex < _routePoints.length - 1) {
//       double currentSegmentDistance = _calculateDistanceBetween(
//         _routePoints[_currentRouteIndex],
//         _routePoints[_currentRouteIndex + 1],
//       );

//       totalDistanceSoFar += currentSegmentDistance * _progress;
//     }

//     double speedPerUpdate = (_constantSpeed / 3600) * 0.033;
//     final mewTotalDistance = totalDistanceSoFar + speedPerUpdate;

//     double accumulatedDistance = 0.0;
//     int newSegmentIndex = 0;
//     double progressInNewSegment = 0.0;

//     for (int i = 0; i < _routePoints.length - 1; i++) {
//       double segmentDistance = _calculateDistanceBetween(
//         _routePoints[i],
//         _routePoints[i + 1],
//       );

//       if (accumulatedDistance + segmentDistance >= mewTotalDistance) {
//         newSegmentIndex = i;
//         double distanceIntoSegment = mewTotalDistance - accumulatedDistance;
//         progressInNewSegment = distanceIntoSegment / segmentDistance;
//         break;
//       }
//       accumulatedDistance += segmentDistance;
//       newSegmentIndex = i + 1;
//     }

//     if (newSegmentIndex >= _routePoints.length - 1) {
//       setState(() {
//         _vehiclePosition = _routePoints.last;
//         _vehicleRotation = _calculateBearing(
//           _routePoints[_routePoints.length - 2],
//           _routePoints.last,
//         );
//       });

//       _timer?.cancel();
//       _showRideCompleted();
//       return;
//     }

//     LatLng startPoint = _routePoints[newSegmentIndex];
//     LatLng endPoint = _routePoints[newSegmentIndex + 1];

//     progressInNewSegment = progressInNewSegment.clamp(0.0, 1.0);

//     double lat =
//         startPoint.latitude +
//         (progressInNewSegment * (endPoint.latitude - startPoint.latitude));

//     double lng =
//         startPoint.longitude +
//         (progressInNewSegment * (endPoint.longitude - startPoint.longitude));

//     LatLng newPosition = LatLng(lat, lng);
//     double rotation = _calculateBearing(startPoint, endPoint);

//     setState(() {
//       _currentRouteIndex = newSegmentIndex;
//       _progress = progressInNewSegment;
//       _vehiclePosition = newPosition;
//       _vehicleRotation = rotation;
//       _distanceTraveled = mewTotalDistance;
//       _updateRideDetails();
//     });

//     if (mounted && _isFollowingVehicle) {
//       try {
//         _mapController.move(newPosition, _mapController.camera.zoom);
//       } catch (e) {
//         print(e);
//       }
//     }
//   }

//   double _calculateBearing(LatLng start, LatLng end) {
//     final dLng = (end.longitude - start.longitude) * (math.pi / 180);
//     final lat1 = start.latitude * math.pi / 180;
//     final lat2 = end.latitude * math.pi / 180;

//     final y = math.sin(dLng) * math.cos(lat2);
//     final x =
//         math.cos(lat1) * math.sin(lat2) -
//         math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
//     return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
//   }

//   void _stopFollowingTemporarily() {
//     setState(() {
//       _isFollowingVehicle = false;
//     });

//     _followTimer?.cancel();
//     _followTimer = Timer(const Duration(seconds: 5), () {
//       if (mounted) {
//         setState(() {
//           _isFollowingVehicle = true;
//         });
//       }
//     });
//   }

//   void _updateRideDetails() {
//     double remainingDistance = _totalRouteDistance - _distanceTraveled;
//     remainingDistance = math.max(0.0, remainingDistance);

//     int remainingTimeInMinutes = (remainingDistance / _constantSpeed * 60)
//         .round();
//     remainingTimeInMinutes = math.max(1, remainingTimeInMinutes);

//     setState(() {
//       _distance = '${remainingDistance.toStringAsFixed(1)} km';
//       _estimatedTime = '$remainingTimeInMinutes min';
//     });
//   }

//   void _showRideCompleted() {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) => Dialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//         child: Container(
//           padding: const EdgeInsets.all(24),
//           decoration: BoxDecoration(
//             borderRadius: BorderRadius.circular(20),
//             color: Colors.white,
//           ),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Container(
//                 height: 80,
//                 width: 80,
//                 decoration: BoxDecoration(
//                   shape: BoxShape.circle,
//                   color: Colors.green,
//                 ),
//                 child: const Icon(
//                   Icons.check_circle,
//                   color: Colors.white,
//                   size: 4,
//                 ),
//               ),
//               SizedBox(height: 20),
//               Text(
//                 'Ride Completed!',
//                 style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//               ),
//               SizedBox(height: 10),
//               Text(
//                 'Thank you for riding with us.',
//                 style: TextStyle(fontSize: 16, color: Colors.grey[600]),
//               ),
//               SizedBox(height: 20),
//               Row(
//                 children: [
//                   Expanded(
//                     child: OutlinedButton(
//                       onPressed: () {
//                         Navigator.of(context).pop();
//                       },
//                       style: OutlinedButton.styleFrom(
//                         padding: EdgeInsets.symmetric(vertical: 12),
//                         side: BorderSide(color: Colors.green),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(10),
//                         ),
//                       ),
//                       child: Text(
//                         'Rate Trip',
//                         style: TextStyle(color: Colors.green),
//                       ),
//                     ),
//                   ),
//                   SizedBox(width: 12),
//                   Expanded(
//                     child: ElevatedButton(
//                       onPressed: () {
//                         Navigator.of(context).pop();
//                         _resetRide();
//                       },
//                       style: ElevatedButton.styleFrom(
//                         padding: EdgeInsets.symmetric(vertical: 12),
//                         backgroundColor: Colors.blue,
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                       ),
//                       child: Text('Done'),
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   void _resetRide() {
//     setState(() {
//       _currentRouteIndex = 0;
//       _progress = 0.0;
//       _vehiclePosition = _routePoints.isNotEmpty
//           ? _routePoints.first
//           : _startPoint;
//       _vehicleRotation = 0.0;
//       _distanceTraveled = 0.0;
//       _isFollowingVehicle = true;
//     });

//     _fetchRealRoute();
//   }

//   Widget _buildRideDetails({
//     required IconData icon,
//     required String label,
//     required String value,
//     Color? iconColor,
//   }) {
//     return Column(
//       children: [
//         Container(
//           padding: const EdgeInsets.all(8),
//           decoration: BoxDecoration(
//             color: (iconColor ?? Colors.blue).withOpacity(0.1),
//             borderRadius: BorderRadius.circular(12),
//           ),
//           child: Icon(icon, color: iconColor ?? Colors.blue, size: 24),
//         ),
//         SizedBox(height: 8),
//         Text(
//           label,
//           style: TextStyle(
//             fontSize: 12,
//             color: Colors.grey[600],
//             fontWeight: FontWeight.w500,
//           ),
//         ),
//         SizedBox(height: 4),
//         Text(
//           value,
//           style: TextStyle(
//             fontSize: 14,
//             fontWeight: FontWeight.bold,
//             color: Colors.grey[800],
//           ),
//         ),
//       ],
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: SafeArea(
//         child: Stack(
//           children: [
//             if (_routeLoaded)
//               Container(
//                 decoration: BoxDecoration(
//                   borderRadius: BorderRadius.only(
//                     topLeft: Radius.circular(24),
//                     topRight: Radius.circular(24),
//                   ),
//                 ),
//                 clipBehavior: Clip.hardEdge,
//                 child: FlutterMap(
//                   mapController: _mapController,
//                   options: MapOptions(
//                     initialCenter: _vehiclePosition,
//                     initialZoom: 15.0,
//                     onPositionChanged: (MapCamera camera, bool hasGesture) {
//                       if (hasGesture) {
//                         _stopFollowingTemporarily();
//                       }
//                     },
//                   ),
//                   children: [
//                     TileLayer(
//                       urlTemplate:
//                           'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
//                     ),
//                     PolylineLayer(
//                       polylines: [
//                         Polyline(
//                           points: _routePoints,
//                           color: Colors.blue,
//                           borderStrokeWidth: 2.0,
//                           strokeWidth: 6.0,
//                           borderColor: Colors.white,
//                         ),
//                       ],
//                     ),
//                     MarkerLayer(
//                       markers: [
//                         Marker(
//                           point: _startPoint,
//                           child: Container(
//                             decoration: BoxDecoration(
//                               color: Colors.green,
//                               borderRadius: BorderRadius.circular(8),
//                               boxShadow: [
//                                 BoxShadow(
//                                   color: Colors.black.withOpacity(0.2),
//                                   blurRadius: 4,
//                                   offset: Offset(0, 2),
//                                 ),
//                               ],
//                             ),
//                             child: Icon(
//                               Icons.location_on,
//                               color: Colors.white,
//                               size: 20,
//                             ),
//                           ),
//                         ),

//                         Marker(
//                           point: _destinationPoint,
//                           child: Container(
//                             decoration: BoxDecoration(
//                               color: Colors.red,
//                               borderRadius: BorderRadius.circular(8),
//                               boxShadow: [
//                                 BoxShadow(
//                                   color: Colors.red.withOpacity(0.2),
//                                   blurRadius: 4,
//                                   offset: Offset(0, 2),
//                                 ),
//                               ],
//                             ),
//                             child: Icon(
//                               Icons.location_on,
//                               color: Colors.white,
//                               size: 20,
//                             ),
//                           ),
//                         ),

//                         Marker(
//                           width: 60,
//                           height: 60,
//                           point: _vehiclePosition,
//                           child: Transform.rotate(
//                             angle: (_vehicleRotation - 180) * math.pi / 180,

//                             child: Image.asset(
//                               'assets/white_car.png',
//                               // width: 40,
//                               // height: 40,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               )
//             else
//               Container(
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     begin: Alignment.topCenter,
//                     end: Alignment.bottomCenter,
//                     colors: [Colors.blue[50]!, Colors.white],
//                   ),
//                 ),
//                 child: Center(
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Container(
//                         width: 80,
//                         height: 80,
//                         padding: EdgeInsets.all(20),
//                         decoration: BoxDecoration(
//                           color: Colors.white,
//                           shape: BoxShape.circle,
//                           boxShadow: [
//                             BoxShadow(
//                               color: Colors.black.withOpacity(0.2),
//                               blurRadius: 4,
//                               offset: Offset(0, 2),
//                             ),
//                           ],
//                         ),
//                         child: CircularProgressIndicator(
//                           strokeWidth: 3,
//                           valueColor: AlwaysStoppedAnimation<Color>(
//                             Colors.blue,
//                           ),
//                         ),
//                       ),
//                       SizedBox(height: 24),
//                       Text(
//                         'Fetching Route...',
//                         style: TextStyle(
//                           fontSize: 20,
//                           color: Colors.grey[800],
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       SizedBox(height: 8),
//                       Text(
//                         'Please wait while we calculate the best route for your ride.',
//                         textAlign: TextAlign.center,
//                         style: TextStyle(fontSize: 16, color: Colors.grey[600]),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),

//             if (_routeLoaded)
//               Container(
//                 height: 80,
//                 margin: EdgeInsets.all(8),
//                 padding: EdgeInsets.all(16),
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(16),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.black.withOpacity(0.1),
//                       blurRadius: 4,
//                       offset: Offset(0, 2),
//                     ),
//                   ],
//                 ),
//                 child: Row(
//                   children: [
//                     Container(
//                       width: 50,
//                       height: 50,
//                       decoration: BoxDecoration(
//                         color: Colors.green[50],
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       child: Icon(
//                         Icons.directions_car,
//                         color: Colors.green,
//                         size: 28,
//                       ),
//                     ),
//                     SizedBox(height: 16),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             'Your Ride is on the way',
//                             style: TextStyle(
//                               fontSize: 16,
//                               fontWeight: FontWeight.w600,
//                               color: Colors.grey[800],
//                             ),
//                           ),
//                           SizedBox(height: 4),
//                           Row(
//                             children: [
//                               Icon(
//                                 Icons.access_time,
//                                 size: 14,
//                                 color: Colors.grey[600],
//                               ),
//                               SizedBox(width: 4),
//                               Text(
//                                 'Arrives in $_estimatedTime',
//                                 style: TextStyle(
//                                   fontSize: 12,
//                                   color: Colors.grey[600],
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),

//             if (_routeLoaded)
//               Positioned(
//                 bottom: 0,
//                 left: 0,
//                 right: 0,
//                 child: SlideTransition(
//                   position: Tween<Offset>(
//                     begin: Offset(0, 1),
//                     end: Offset(0, 0),
//                   ).animate(_bottomSheetController),
//                   child: Container(
//                     constraints: BoxConstraints(
//                       minHeight: 250,
//                       maxHeight: MediaQuery.of(context).size.height * 0.7,
//                     ),
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.vertical(
//                         top: Radius.circular(24),
//                       ),
//                       boxShadow: [
//                         BoxShadow(
//                           color: Colors.black.withOpacity(0.1),
//                           blurRadius: 4,
//                           offset: Offset(0, -2),
//                         ),
//                       ],
//                     ),
//                     child: Column(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Container(
//                           padding: EdgeInsets.all(16),
//                           decoration: BoxDecoration(
//                             color: Colors.grey[50],
//                             borderRadius: BorderRadius.circular(16),
//                             border: Border.all(color: Colors.grey[200]!),
//                           ),
//                           child: Row(
//                             children: [
//                               Container(
//                                 width: 50,
//                                 height: 50,
//                                 decoration: BoxDecoration(
//                                   gradient: LinearGradient(
//                                     colors: [
//                                       Colors.blue[400]!,
//                                       Colors.blue[600]!,
//                                     ],
//                                   ),
//                                   shape: BoxShape.circle,
//                                   boxShadow: [
//                                     BoxShadow(
//                                       color: Colors.blue.withOpacity(0.3),
//                                       blurRadius: 8,
//                                       offset: Offset(0, 4),
//                                     ),
//                                   ],
//                                 ),
//                                 child: Icon(
//                                   Icons.person,
//                                   color: Colors.white,
//                                   size: 30,
//                                 ),
//                               ),
//                               SizedBox(width: 16),
//                               Expanded(
//                                 child: Column(
//                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                   children: [
//                                     Text(
//                                       _driverName,
//                                       style: TextStyle(
//                                         fontSize: 18,
//                                         fontWeight: FontWeight.bold,
//                                         color: Colors.grey[800],
//                                       ),
//                                     ),
//                                     SizedBox(height: 4),
//                                     Row(
//                                       children: [
//                                         Container(
//                                           padding: EdgeInsets.symmetric(
//                                             vertical: 2,
//                                             horizontal: 8,
//                                           ),
//                                           decoration: BoxDecoration(
//                                             color: Colors.green[100],
//                                             borderRadius: BorderRadius.circular(
//                                               12,
//                                             ),
//                                           ),
//                                           child: Row(
//                                             mainAxisSize: MainAxisSize.min,
//                                             children: [
//                                               Icon(
//                                                 Icons.star,
//                                                 color: Colors.green[700],
//                                                 size: 14,
//                                               ),
//                                               SizedBox(width: 4),
//                                               Text(
//                                                 _rating.toString(),
//                                                 style: TextStyle(
//                                                   fontSize: 12,
//                                                   color: Colors.green[700],
//                                                   fontWeight: FontWeight.w600,
//                                                 ),
//                                               ),
//                                             ],
//                                           ),
//                                         ),
//                                         SizedBox(height: 12),
//                                         Text(
//                                           _plateNUmber,
//                                           style: TextStyle(
//                                             fontSize: 14,
//                                             color: Colors.grey[600],
//                                             fontWeight: FontWeight.w600,
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ],
//                                 ),
//                               ),

//                               Row(
//                                 children: [
//                                   Container(
//                                     decoration: BoxDecoration(
//                                       color: Colors.green[50],
//                                       shape: BoxShape.circle,
//                                     ),
//                                     child: IconButton(
//                                       onPressed: () {},
//                                       icon: Icon(
//                                         Icons.phone,
//                                         color: Colors.green[700],
//                                         size: 22,
//                                       ),
//                                     ),
//                                   ),
//                                   SizedBox(width: 8),
//                                   Container(
//                                     decoration: BoxDecoration(
//                                       color: Colors.blue[50],
//                                       shape: BoxShape.circle,
//                                     ),
//                                     child: IconButton(
//                                       onPressed: () {},
//                                       icon: Icon(
//                                         Icons.message,
//                                         color: Colors.blue[700],
//                                         size: 22,
//                                       ),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ],
//                           ),
//                         ),

//                         SizedBox(height: 16),

//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceAround,
//                           children: [
//                             _buildRideDetails(
//                               icon: Icons.directions_car,
//                               label: 'Duration',
//                               value: _estimatedTime,
//                               iconColor: Colors.blue[100],
//                             ),
//                             _buildRideDetails(
//                               icon: Icons.directions_car,
//                               label: 'Distance',
//                               value: _distance,
//                               iconColor: Colors.orange[100],
//                             ),
//                             _buildRideDetails(
//                               icon: Icons.directions_car,
//                               label: 'Vehicle',
//                               value: _vehicleType,
//                               iconColor: Colors.purple[100],
//                             ),
//                           ],
//                         ),
//                         SizedBox(height: 16),
//                         Row(
//                           children: [
//                             Expanded(
//                               child: OutlinedButton.icon(
//                                 onPressed: () {},
//                                 label: Text(
//                                   "Share",
//                                   style: TextStyle(color: Colors.blue),
//                                 ),
//                                 icon: Icon(Icons.share, color: Colors.blue),
//                                 style: OutlinedButton.styleFrom(
//                                   padding: EdgeInsets.symmetric(vertical: 12),
//                                   side: BorderSide(color: Colors.grey[300]!),
//                                   shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(12),
//                                   ),
//                                 ),
//                               ),
//                             ),
//                             SizedBox(width: 12),
//                             Expanded(
//                               child: OutlinedButton.icon(
//                                 onPressed: () {},
//                                 label: Text("Emergency"),
//                                 icon: Icon(Icons.warning),
//                                 style: OutlinedButton.styleFrom(
//                                   backgroundColor: Colors.redAccent,
//                                   foregroundColor: Colors.white,
//                                   padding: EdgeInsets.symmetric(vertical: 12),
//                                   side: BorderSide(color: Colors.grey[300]!),
//                                   shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(12),
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),

//             if (_routeLoaded)
//               Positioned(
//                 top: 100,
//                 right: 15,
//                 child: Column(
//                   children: [
//                     Container(
//                       decoration: BoxDecoration(
//                         color: Colors.white,
//                         shape: BoxShape.circle,
//                         boxShadow: [
//                           BoxShadow(
//                             color: Colors.black.withOpacity(0.1),
//                             blurRadius: 4,
//                             offset: Offset(0, 2),
//                           ),
//                         ],
//                       ),
//                       child: FloatingActionButton(
//                         mini: true,
//                         onPressed: () {
//                           setState(() {
//                             _isFollowingVehicle = !_isFollowingVehicle;
//                           });

//                           if (_isFollowingVehicle) {
//                             try {
//                               _mapController.move(_vehiclePosition, 16);
//                             } catch (e) {
//                               print(e);
//                             }
//                           }
//                         },
//                         backgroundColor: Colors.white,
//                         elevation: 0,
//                         child: Icon(
//                           _isFollowingVehicle
//                               ? Icons.gps_fixed
//                               : Icons.gps_not_fixed,
//                           color: _isFollowingVehicle ? Colors.blue : Colors.red,
//                         ),
//                       ),
//                     ),
//                     SizedBox(height: 12),
//                     Container(
//                       decoration: BoxDecoration(
//                         color: Colors.white,
//                         shape: BoxShape.circle,
//                         boxShadow: [
//                           BoxShadow(
//                             color: Colors.black.withOpacity(0.1),
//                             blurRadius: 4,
//                             offset: Offset(0, 2),
//                           ),
//                         ],
//                       ),
//                       child: FloatingActionButton(
//                         mini: true,
//                         onPressed: () {
//                           if (_routePoints.isNotEmpty) {
//                             try {
//                               double minLat = _routePoints
//                                   .map((p) => p.latitude)
//                                   .reduce(math.min);
//                               double maxLat = _routePoints
//                                   .map((p) => p.latitude)
//                                   .reduce(math.max);
//                               double minLng = _routePoints
//                                   .map((p) => p.latitude)
//                                   .reduce(math.min);
//                               double maxLng = _routePoints
//                                   .map((p) => p.latitude)
//                                   .reduce(math.max);

//                               LatLng Center = LatLng(
//                                 (minLat + maxLat) / 2,
//                                 (minLng + maxLng) / 2,
//                               );

//                               _mapController.move(Center, 13);

//                               _stopFollowingTemporarily();
//                             } catch (e) {
//                               print(e);
//                             }
//                           }
//                         },
//                         backgroundColor: Colors.white,
//                         elevation: 0,
//                         child: Icon(
//                           Icons.zoom_out_map,
//                           color: Colors.grey[700],
//                           size: 22,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }
