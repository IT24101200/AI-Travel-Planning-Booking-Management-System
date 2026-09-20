import 'package:flutter/material.dart';
import '../../app_constants.dart';

/// Trip map screen showing geo-located waypoints, attractions, and hotels across Sri Lanka.
class TripMapScreen extends StatelessWidget {
  const TripMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    List<Map<String, dynamic>> stops = [];

    if (args is List) {
      stops = args.cast<Map<String, dynamic>>();
    } else if (args is Map<String, dynamic>) {
      final items = args['items'] as List<dynamic>? ?? [];
      stops = items.map((i) {
        return {
          'name': i['tourName'] ?? 'Attraction Stop',
          'type': 'Tour',
          'latitude': 7.9570,
          'longitude': 80.7603,
          'region': 'Cultural Triangle',
        };
      }).toList();
    }

    // If no custom stops, display the iconic circuit waypoints
    if (stops.isEmpty) {
      stops = [
        {
          'name': 'Sigiriya Lion Rock Fortress',
          'type': 'Heritage',
          'latitude': 7.9570,
          'longitude': 80.7603,
          'region': 'Matale District',
        },
        {
          'name': 'Temple of the Sacred Tooth',
          'type': 'Temple',
          'latitude': 7.2906,
          'longitude': 80.6337,
          'region': 'Kandy',
        },
        {
          'name': 'Nine Arches Colonial Bridge',
          'type': 'Tour',
          'latitude': 6.8667,
          'longitude': 81.0466,
          'region': 'Ella Valley',
        },
        {
          'name': 'Mirissa Coconut Tree Hill',
          'type': 'Beach',
          'latitude': 5.9483,
          'longitude': 80.4589,
          'region': 'Southern Coast',
        },
        {
          'name': 'Yala Leopard Safari Zone',
          'type': 'Wildlife',
          'latitude': 6.3728,
          'longitude': 81.5019,
          'region': 'Ruhuna',
        },
      ];
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Trip Waypoints & Map')),
      body: Column(
        children: [
          // ── Stylized Map Header Visual ──
          Stack(
            children: [
              Container(
                height: 180,
                width: double.infinity,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(AppDestinations.heroSigiriya),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Container(
                height: 180,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.jungle900.withValues(alpha: 0.5),
                      AppColors.jungle900.withValues(alpha: 0.9),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 20,
                right: 20,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.sand500,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.explore,
                        color: AppColors.jungle900,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Geographic Circuit',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Verified GPS coordinates for hotels, transit & tours',
                            style: TextStyle(
                              color: AppColors.sand200,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Waypoint List ──
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: stops.length,
              itemBuilder: (context, index) {
                final stop = stops[index];
                return _buildStopCard(stop, index, stops.length);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStopCard(Map<String, dynamic> stop, int index, int total) {
    final type = (stop['type'] ?? 'Location').toString();
    final name = stop['name'] ?? 'Stop ${index + 1}';
    final lat = stop['latitude'] ?? 7.957;
    final lng = stop['longitude'] ?? 80.760;
    final region = stop['region'] ?? 'Sri Lanka';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.jungle600.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.jungle600,
                fontSize: 16,
              ),
            ),
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: AppColors.ink,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              '$type • $region',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.jungle600,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: AppColors.ink3,
                ),
                const SizedBox(width: 4),
                Text(
                  'GPS: $lat, $lng',
                  style: const TextStyle(fontSize: 11, color: AppColors.ink3),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(
          Icons.navigation_outlined,
          color: AppColors.jungle600,
          size: 20,
        ),
      ),
    );
  }
}
