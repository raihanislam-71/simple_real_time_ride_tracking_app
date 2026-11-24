import 'package:material_ui/material_ui.dart';
import '../app_constants.dart';

/// Bottom info sheet matching the design in the reference UI.
class TripInfoSheet extends StatelessWidget {
  final double remainingDurationMin;
  final double remainingDistanceKm;
  final String driverName;
  final String rating;
  final String plateNumber;
  final String vehicleName;
  final VoidCallback? onCall;
  final VoidCallback? onMessage;
  final VoidCallback? onShare;
  final VoidCallback? onEmergency;

  const TripInfoSheet({
    super.key,
    required this.remainingDurationMin,
    required this.remainingDistanceKm,
    this.driverName = AppConstants.driverName,
    this.rating = AppConstants.rating,
    this.plateNumber = AppConstants.plateNumber,
    this.vehicleName = AppConstants.carModel,
    this.onCall,
    this.onMessage,
    this.onShare,
    this.onEmergency,
  });

  String get _formattedDuration {
    if (remainingDurationMin <= 0.2) return 'Arrived';
    if (remainingDurationMin < 1) return '< 1 min';
    return '${remainingDurationMin.round()} min';
  }

  String get _formattedDistance {
    if (remainingDistanceKm < 0.1) return '0.1 km';
    return '${remainingDistanceKm.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Driver row
          Row(
            children: [
              // Avatar
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0084FF),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0084FF).withValues(alpha: 0.35),
                      blurRadius: 10,
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

              // Name, Rating, Plate
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driverName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 14,
                                color: Color(0xFF059669),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                rating,
                                style: const TextStyle(
                                  color: Color(0xFF059669),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          plateNumber,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Call Button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onCall ??
                      () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Calling $driverName...')),
                        );
                      },
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFECFDF5),
                      border: Border.all(
                        color: const Color(0xFFA7F3D0).withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Icon(
                      Icons.phone,
                      color: Color(0xFF10B981),
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Message Button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onMessage ??
                      () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Messaging $driverName...')),
                        );
                      },
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFEFF6FF),
                      border: Border.all(
                        color: const Color(0xFFBFDBFE).withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Icon(
                      Icons.chat_bubble_rounded,
                      color: Color(0xFF3B82F6),
                      size: 19,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // Metrics cards (Duration, Distance, Vehicle)
          Row(
            children: [
              // Duration
              _buildMetricCard(
                icon: Icons.access_time_rounded,
                iconColor: const Color(0xFF0284C7),
                iconBgColor: const Color(0xFFE0F2FE),
                label: 'Duration',
                value: _formattedDuration,
              ),
              const SizedBox(width: 12),

              // Distance
              _buildMetricCard(
                icon: Icons.map_rounded,
                iconColor: const Color(0xFFD97706),
                iconBgColor: const Color(0xFFFEF3C7),
                label: 'Distance',
                value: _formattedDistance,
              ),
              const SizedBox(width: 12),

              // Vehicle
              _buildMetricCard(
                icon: Icons.directions_car_filled_rounded,
                iconColor: const Color(0xFF9333EA),
                iconBgColor: const Color(0xFFF3E8FF),
                label: 'Vehicle',
                value: vehicleName,
              ),
            ],
          ),

          const SizedBox(height: 22),

          // Bottom buttons: Share & Emergency
          Row(
            children: [
              // Share
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: onShare ??
                        () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Sharing ride status...')),
                          );
                        },
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: const Color(0xFFEFF6FF),
                      foregroundColor: const Color(0xFF0284C7),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: const Text(
                      'Share',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Emergency
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: onEmergency ??
                        () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: Colors.red,
                              content: Text('Emergency alert triggered!'),
                            ),
                          );
                        },
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.warning_rounded, size: 18),
                    label: const Text(
                      'Emergency',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: iconColor, size: 23),
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
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}
