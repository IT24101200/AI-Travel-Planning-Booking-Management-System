import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../../app_constants.dart';

/// Full Route Map screen using open-source OpenStreetMap (flutter_map).
/// Renders interactive tiles, route polylines, and waypoint markers for the itinerary.
class TripMapScreen extends StatefulWidget {
  const TripMapScreen({super.key});

  @override
  State<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends State<TripMapScreen> {
  final MapController _mapController = MapController();
  int _selectedStopIndex = 0;

  // Curated waypoints connecting the 7-day Sri Lanka Discovery circuit
  final List<Map<String, dynamic>> _waypoints = [
    {
      'day': 'Day 1',
      'name': 'Sigiriya Lion Rock',
      'location': LatLng(7.9570, 80.7603),
      'region': 'Matale District',
      'category': 'Culture & Heritage',
      'description': 'Ancient palace and fortress complex with 5th-century frescoes.',
      'imageUrl': AppDestinations.heroSigiriya,
      'duration': '3.5 hrs from Colombo',
    },
    {
      'day': 'Day 2',
      'name': 'Kandy Temple of Tooth',
      'location': LatLng(7.2906, 80.6337),
      'region': 'Central Province',
      'category': 'Sacred Heritage',
      'description': 'Royal palace complex housing the sacred relic of the tooth of the Buddha.',
      'imageUrl': AppDestinations.featured[0].imageUrl,
      'duration': '2.5 hrs from Sigiriya',
    },
    {
      'day': 'Day 3–4',
      'name': 'Ella Tea Country',
      'location': LatLng(6.8667, 81.0466),
      'region': 'Badulla District',
      'category': 'Highlands & Hiking',
      'description': 'Nine Arches Colonial Bridge and Little Adam\'s Peak tea plantations.',
      'imageUrl': AppDestinations.featured[1].imageUrl,
      'duration': '6.0 hrs scenic train',
    },
    {
      'day': 'Day 5–7',
      'name': 'Mirissa Coastal Beach',
      'location': LatLng(5.9483, 80.4589),
      'region': 'Southern Coast',
      'category': 'Ocean & Wellness',
      'description': 'Coconut Tree Hill, secret beach coves, and blue whale watching.',
      'imageUrl': AppDestinations.featured[2].imageUrl,
      'duration': '3.0 hrs transfer',
    },
  ];

  @override
  Widget build(BuildContext context) {
    // Collect all points for polyline
    final List<LatLng> routePoints = _waypoints.map((w) => w['location'] as LatLng).toList();
    final currentStop = _waypoints[_selectedStopIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F4),
      body: Stack(
        children: [
          // ── 1. Open-Source OpenStreetMap Tile Layer ──
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(7.15, 80.75),
              initialZoom: 8.0,
              minZoom: 6.0,
              maxZoom: 18.0,
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              // OpenStreetMap Standard Tiles
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.serendib_trails',
                maxZoom: 19,
              ),

              // Full circuit route Polyline
              PolylineLayer(
                polylines: [
                  // Gold border / halo line
                  Polyline(
                    points: routePoints,
                    strokeWidth: 6.0,
                    color: const Color(0xFFD4A346),
                  ),
                  // Dark Forest Green core line
                  Polyline(
                    points: routePoints,
                    strokeWidth: 3.5,
                    color: const Color(0xFF0E382C),
                  ),
                ],
              ),

              // Waypoint Markers
              MarkerLayer(
                markers: List.generate(_waypoints.length, (index) {
                  final wp = _waypoints[index];
                  final isSelected = index == _selectedStopIndex;
                  final LatLng pos = wp['location'] as LatLng;

                  return Marker(
                    point: pos,
                    width: isSelected ? 52 : 42,
                    height: isSelected ? 52 : 42,
                    alignment: Alignment.center,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedStopIndex = index);
                        _mapController.move(pos, 10.5);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF0E382C) : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? const Color(0xFFD4A346) : const Color(0xFF0E382C),
                            width: isSelected ? 3 : 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isSelected ? Colors.white : const Color(0xFF0E382C),
                              fontWeight: FontWeight.w900,
                              fontSize: isSelected ? 15 : 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),

          // ── 2. Top Header Overlay (Back Button + Title Pill) ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.arrow_back, color: Color(0xFF08201A), size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Route Title Badge
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E382C),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.alt_route, color: Color(0xFFD4A346), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Sri Lanka Route Circuit',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Text(
                                  'Sigiriya → Kandy → Ella → Mirissa',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Color(0xFFB8D3C8),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 3. Floating Zoom Controls ──
          Positioned(
            right: 16,
            top: 110,
            child: Column(
              children: [
                _buildMapFloatingBtn(
                  icon: Icons.add,
                  onTap: () {
                    final zoom = _mapController.camera.zoom;
                    _mapController.move(_mapController.camera.center, zoom + 1);
                  },
                ),
                const SizedBox(height: 8),
                _buildMapFloatingBtn(
                  icon: Icons.remove,
                  onTap: () {
                    final zoom = _mapController.camera.zoom;
                    _mapController.move(_mapController.camera.center, zoom - 1);
                  },
                ),
                const SizedBox(height: 8),
                _buildMapFloatingBtn(
                  icon: Icons.fit_screen_outlined,
                  onTap: () {
                    // Reset to overview of Sri Lanka
                    _mapController.move(const LatLng(7.15, 80.75), 8.0);
                  },
                ),
              ],
            ),
          ),

          // ── 4. Bottom Selected Waypoint Info Card & Circuit Selector ──
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Waypoint horizontal mini chips
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _waypoints.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final wp = _waypoints[index];
                      final isSelected = index == _selectedStopIndex;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedStopIndex = index);
                          _mapController.move(wp['location'] as LatLng, 10.5);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF0E382C) : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF0E382C) : const Color(0xFFEDECE4),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFFD4A346) : const Color(0xFF0E382C),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color: isSelected ? const Color(0xFF1A1A1A) : Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                wp['name'],
                                style: TextStyle(
                                  color: isSelected ? Colors.white : const Color(0xFF08201A),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),

                // Active Stop Detail Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFEDECE4)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          width: 80,
                          height: 80,
                          child: Image.asset(
                            currentStop['imageUrl'],
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Container(
                              color: const Color(0xFF0E382C),
                              child: const Icon(Icons.photo, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Text Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEEFAF4),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    currentStop['day'].toString().toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0E382C),
                                    ),
                                  ),
                                ),
                                Text(
                                  currentStop['duration'],
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF8A9E96),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currentStop['name'],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF08201A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currentStop['description'],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF6B7280),
                                height: 1.3,
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
          ),
        ],
      ),
    );
  }

  Widget _buildMapFloatingBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFEDECE4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Icon(icon, color: const Color(0xFF08201A), size: 20),
        ),
      ),
    );
  }
}
