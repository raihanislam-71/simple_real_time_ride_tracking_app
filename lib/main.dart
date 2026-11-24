import 'package:material_ui/material_ui.dart';
import 'widgets/ride_tracking_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RideTrackingApp());
}

class RideTrackingApp extends StatelessWidget {
  const RideTrackingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Real-Time Ride Tracking',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF007AFF)),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const RideTrackingScreen(),
    );
  }
}
