import 'package:flutter/material.dart';
import '../../widgets/common_widgets.dart';

/// Trip map screen showing a simple list of trip stop coordinates.
/// Uses coordinate display (no Google Maps API key needed).
class TripMapScreen extends StatelessWidget {
  const TripMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Receive trip data as arguments (list of stops with coordinates)
    final args = ModalRoute.of(context)?.settings.arguments;
    final List<Map<String, dynamic>> stops = args is List
        ? args.cast<Map<String, dynamic>>()
        : [];

    return Scaffold(
      appBar: AppBar(title: const Text('Trip Map')),
      body: stops.isEmpty
          ? const EmptyState(
              icon: Icons.map_outlined,
              message: 'No locations to display',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: stops.length,
              itemBuilder: (context, index) {
                final stop = stops[index];
                return _buildStopCard(stop, index);
              },
            ),
    );
  }

  /// Build a single stop card with coordinates
  Widget _buildStopCard(Map<String, dynamic> stop, int index) {
    // Determine icon based on stop type
    IconData icon;
    Color color;
    switch ((stop['type'] ?? '').toString().toLowerCase()) {
      case 'hotel':
        icon = Icons.hotel;
        color = Colors.amber;
        break;
      case 'tour':
        icon = Icons.landscape;
        color = const Color(0xFF0D9488);
        break;
      case 'transport':
        icon = Icons.commute;
        color = const Color(0xFF7C5CFC);
        break;
      default:
        icon = Icons.location_on;
        color = Colors.red;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          stop['name'] ?? 'Stop ${index + 1}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (stop['type'] != null)
              Text(stop['type'], style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.my_location, size: 14, color: Color(0xFF0D9488)),
                const SizedBox(width: 4),
                Text(
                  'Lat: ${stop['latitude'] ?? 'N/A'}, Lng: ${stop['longitude'] ?? 'N/A'}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        // Order number
        trailing: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF0D9488).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D9488),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
