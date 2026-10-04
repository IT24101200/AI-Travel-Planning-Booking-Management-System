import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../../app_constants.dart';
import '../../services/trip_selection_service.dart';

/// Model representing an interactive stop on the Sri Lankan itinerary route map
class MapStopItem {
  final int stopNum;
  final String location;
  final String title;
  final double rating;
  final String time;
  final String distance;
  final String transit;
  final String image;
  final LatLng latLng;
  final IconData icon;
  final Color color;

  const MapStopItem({
    required this.stopNum,
    required this.location,
    required this.title,
    required this.rating,
    required this.time,
    required this.distance,
    required this.transit,
    required this.image,
    required this.latLng,
    required this.icon,
    required this.color,
  });
}

/// Trip map screen matching Figma frame 10 · Trip Map (node 7:10901)
/// Features real OpenStreetMap integration, accurate Sri Lankan GPS waypoints,
/// interconnected route polyline, interactive stop selection, and zoom controls.
class TripMapScreen extends StatefulWidget {
  const TripMapScreen({super.key});

  @override
  State<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends State<TripMapScreen> {
  final MapController _mapController = MapController();
  int _activeStopIndex = 1; // Default to Stop 2: Temple of the Tooth (matches Figma)
  bool _isSatellite = false;
  List<MapStopItem> _stops = [];
  String _tripTitle = 'Sri Lanka Discovery';
  int _totalKm = 612;

  // Default curated Sri Lankan stops with authentic GPS coordinates
  static const List<MapStopItem> _defaultStops = [
    MapStopItem(
      stopNum: 1,
      location: 'SIGIRIYA',
      title: 'Sigiriya Lion Rock Fortress',
      rating: 4.9,
      time: '12 Oct · 07:00–10:30',
      distance: 'From airport · 148 km',
      transit: '3.5 hrs private transfer',
      image: 'https://images.unsplash.com/photo-1586861635167-e5223aadc9fe?w=600&auto=format&fit=crop&q=80',
      latLng: LatLng(7.9570, 80.7603), // Sigiriya Rock Fortress
      icon: Icons.castle_outlined,
      color: AppColors.figmaGold,
    ),
    MapStopItem(
      stopNum: 2,
      location: 'KANDY',
      title: 'Temple of the Tooth',
      rating: 4.8,
      time: '13 Oct · 10:30–12:00',
      distance: 'From hotel · 1.8 km',
      transit: '8 min by tuk-tuk',
      image: 'https://images.unsplash.com/photo-1546708973-b339540b5162?w=600&auto=format&fit=crop&q=80',
      latLng: LatLng(7.2906, 80.6337), // Kandy Temple of the Tooth
      icon: Icons.account_balance_outlined,
      color: Color(0xFF2563EB),
    ),
    MapStopItem(
      stopNum: 3,
      location: 'DAMBULLA',
      title: 'Heritance Kandalama Stay',
      rating: 4.9,
      time: '14 Oct · Check-in 14:00',
      distance: 'From Sigiriya · 19 km',
      transit: '25 min private car',
      image: 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=600&auto=format&fit=crop&q=80',
      latLng: LatLng(7.8731, 80.6519), // Dambulla / Kandalama
      icon: Icons.hotel_outlined,
      color: AppColors.figmaDarkGreen,
    ),
    MapStopItem(
      stopNum: 4,
      location: 'ELLA',
      title: 'Nine Arches Bridge & Train',
      rating: 4.9,
      time: '16 Oct · 08:30–11:00',
      distance: 'From Kandy · 135 km',
      transit: 'Scenic observation train',
      image: 'https://images.unsplash.com/photo-1588598198321-9735fd52455b?w=600&auto=format&fit=crop&q=80',
      latLng: LatLng(6.8667, 81.0466), // Ella Nine Arch Bridge
      icon: Icons.directions_car_outlined,
      color: Color(0xFFD97706),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _stops = _defaultStops;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initFromRouteArguments();
    });
  }

  /// Parses itinerary arguments if passed from MyItineraryScreen
  void _initFromRouteArguments() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final title = args['title']?.toString();
      if (title != null && title.isNotEmpty) {
        setState(() {
          _tripTitle = title;
        });
      }

      final rawItems = args['items'];
      if (rawItems is List && rawItems.isNotEmpty) {
        final parsed = <MapStopItem>[];
        int num = 1;
        for (var item in rawItems) {
          if (item is! Map) continue;
          final tourName = item['tourName']?.toString() ?? 'Activity';
          final latLng = _resolveCoordinates(tourName, item['destinationName']?.toString());
          final timeStr = item['startTime']?.toString() ?? '09:00';
          final dayNum = item['dayNumber']?.toString() ?? '$num';

          IconData icon = Icons.account_balance_outlined;
          Color color = const Color(0xFF2563EB);
          if (num == 1) {
            icon = Icons.castle_outlined;
            color = AppColors.figmaGold;
          } else if (num == rawItems.length) {
            icon = Icons.directions_car_outlined;
            color = const Color(0xFFD97706);
          } else if (num % 2 == 0) {
            icon = Icons.hotel_outlined;
            color = AppColors.figmaDarkGreen;
          }

          parsed.add(
            MapStopItem(
              stopNum: num++,
              location: _extractLocationName(tourName),
              title: tourName,
              rating: 4.8 + (num % 3) * 0.1,
              time: 'Day $dayNum · ${timeStr.length >= 5 ? timeStr.substring(0, 5) : timeStr}',
              distance: 'Scheduled Tour Stop',
              transit: 'Private guided transit',
              image: AppDestinations.getImageForDestination(tourName),
              latLng: latLng,
              icon: icon,
              color: color,
            ),
          );
        }

        if (parsed.isNotEmpty) {
          setState(() {
            _stops = parsed;
            _totalKm = parsed.length * 115;
            _activeStopIndex = 0;
          });
        }
      }
    }

    final selectedHotel = TripSelectionService.selectedHotel;
    final selectedTransport = TripSelectionService.selectedTransport;
    if (selectedHotel != null || selectedTransport != null) {
      final updatedStops = _stops.map((stop) {
        if (stop.icon == Icons.hotel_outlined && selectedHotel != null) {
          final hotelName = selectedHotel['name']?.toString() ?? stop.title;
          final location = selectedHotel['location']?.toString() ?? stop.location;
          final rating = (selectedHotel['rating'] is num)
              ? (selectedHotel['rating'] as num).toDouble()
              : stop.rating;
          final image = selectedHotel['image']?.toString() ?? stop.image;
          return MapStopItem(
            stopNum: stop.stopNum,
            location: location.toUpperCase(),
            title: hotelName,
            rating: rating,
            time: stop.time,
            distance: stop.distance,
            transit: selectedTransport != null
                ? selectedTransport['title']?.toString() ?? stop.transit
                : stop.transit,
            image: image,
            latLng: stop.latLng,
            icon: stop.icon,
            color: stop.color,
          );
        }
        if (selectedTransport != null && stop.icon == Icons.directions_car_outlined) {
          return MapStopItem(
            stopNum: stop.stopNum,
            location: stop.location,
            title: stop.title,
            rating: stop.rating,
            time: stop.time,
            distance: stop.distance,
            transit: selectedTransport['title']?.toString() ?? stop.transit,
            image: stop.image,
            latLng: stop.latLng,
            icon: stop.icon,
            color: stop.color,
          );
        }
        return stop;
      }).toList();

      setState(() {
        _stops = updatedStops;
      });
    }
  }

  /// Resolves authentic GPS coordinates for Sri Lankan tour destinations
  LatLng _resolveCoordinates(String name, String? destination) {
    final text = '$name ${destination ?? ''}'.toLowerCase();
    if (text.contains('sigiriya')) return const LatLng(7.9570, 80.7603);
    if (text.contains('dambulla') || text.contains('kandalama')) return const LatLng(7.8731, 80.6519);
    if (text.contains('kandy') || text.contains('tooth')) return const LatLng(7.2906, 80.6337);
    if (text.contains('nuwara eliya') || text.contains('pedro') || text.contains('gregory')) return const LatLng(6.9497, 80.7891);
    if (text.contains('ella') || text.contains('nine arch') || text.contains('adam')) return const LatLng(6.8667, 81.0466);
    if (text.contains('yala') || text.contains('safari')) return const LatLng(6.3725, 81.5173);
    if (text.contains('mirissa') || text.contains('whale')) return const LatLng(5.9483, 80.4589);
    if (text.contains('galle') || text.contains('fort')) return const LatLng(6.0535, 80.2210);
    if (text.contains('minneriya')) return const LatLng(8.0321, 80.9015);
    if (text.contains('horton') || text.contains('world')) return const LatLng(6.8028, 80.8044);
    if (text.contains('bentota')) return const LatLng(6.4259, 79.9958);
    if (text.contains('trincomalee')) return const LatLng(8.5874, 81.2152);
    return const LatLng(7.2906, 80.6337);
  }

  String _extractLocationName(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('sigiriya')) return 'SIGIRIYA';
    if (lower.contains('dambulla')) return 'DAMBULLA';
    if (lower.contains('kandy')) return 'KANDY';
    if (lower.contains('nuwara eliya')) return 'NUWARA ELIYA';
    if (lower.contains('ella')) return 'ELLA';
    if (lower.contains('yala')) return 'YALA';
    if (lower.contains('mirissa')) return 'MIRISSA';
    if (lower.contains('galle')) return 'GALLE';
    return 'SRI LANKA';
  }

  /// Centers the map on the given stop
  void _focusStop(int index) {
    if (index < 0 || index >= _stops.length) return;
    setState(() => _activeStopIndex = index);
    final stop = _stops[index];
    _mapController.move(stop.latLng, 9.8);
  }

  /// Fits all stops in camera view
  void _fitAllStops() {
    if (_stops.isEmpty) return;
    final points = _stops.map((s) => s.latLng).toList();
    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 120),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeStop = _stops.isNotEmpty ? _stops[_activeStopIndex] : _defaultStops[0];
    final routePoints = _stops.map((s) => s.latLng).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // ── Real OpenStreetMap Interactive Canvas ──
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: const LatLng(7.45, 80.75), // Geographic center of Sri Lanka
                initialZoom: 8.2,
                minZoom: 6.5,
                maxZoom: 18.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                // Real OpenStreetMap Tile Layer
                TileLayer(
                  urlTemplate: _isSatellite
                      ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.serendib_trails',
                ),

                // Realistic Polyline Route connecting Sri Lankan stops
                if (routePoints.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: routePoints,
                        color: const Color(0xFF0F4735).withValues(alpha: 0.92),
                        strokeWidth: 4.5,
                        borderColor: AppColors.figmaGold,
                        borderStrokeWidth: 1.8,
                      ),
                    ],
                  ),

                // Interactive Markers positioned at real Sri Lankan GPS waypoints
                MarkerLayer(
                  markers: _stops.asMap().entries.map((entry) {
                    final index = entry.key;
                    final stop = entry.value;
                    final isSelected = index == _activeStopIndex;

                    return Marker(
                      point: stop.latLng,
                      width: isSelected ? 50 : 40,
                      height: isSelected ? 50 : 40,
                      child: GestureDetector(
                        onTap: () => _focusStop(index),
                        child: _buildMapPin(
                          icon: stop.icon,
                          color: stop.color,
                          isSelected: isSelected,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // ── Top Floating App Bar Capsule ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_back,
                        color: Theme.of(context).colorScheme.primary,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _tripTitle,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${_stops.length} stops · $_totalKm km',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: const Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Layer Switcher / Recenter Button
                  GestureDetector(
                    onTap: () {
                      setState(() => _isSatellite = !_isSatellite);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          duration: const Duration(seconds: 1),
                          content: Text(_isSatellite ? 'Switched to Satellite View' : 'Switched to Street Map'),
                        ),
                      );
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _isSatellite ? AppColors.figmaGold : Theme.of(context).cardColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.layers_outlined,
                        color: _isSatellite ? Colors.white : Theme.of(context).colorScheme.primary,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Top Right Floating Legend Card ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 76,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLegendItem(Icons.castle_outlined, 'Destination'),
                  const SizedBox(height: 6),
                  _buildLegendItem(Icons.hotel_outlined, 'Hotel'),
                  const SizedBox(height: 6),
                  _buildLegendItem(Icons.account_balance_outlined, 'Attraction'),
                  const SizedBox(height: 6),
                  _buildLegendItem(Icons.directions_car_outlined, 'Transport'),
                ],
              ),
            ),
          ),

          // ── Map Zoom and Fit Route Controls (Right Side) ──
          Positioned(
            right: 16,
            bottom: 250,
            child: Column(
              children: [
                _buildMapActionButton(
                  icon: Icons.add,
                  tooltip: 'Zoom In',
                  onTap: () => _mapController.move(
                    _mapController.camera.center,
                    _mapController.camera.zoom + 1,
                  ),
                ),
                const SizedBox(height: 8),
                _buildMapActionButton(
                  icon: Icons.remove,
                  tooltip: 'Zoom Out',
                  onTap: () => _mapController.move(
                    _mapController.camera.center,
                    _mapController.camera.zoom - 1,
                  ),
                ),
                const SizedBox(height: 8),
                _buildMapActionButton(
                  icon: Icons.center_focus_strong_outlined,
                  tooltip: 'Fit Route',
                  onTap: _fitAllStops,
                ),
              ],
            ),
          ),

          // ── Bottom Floating Stop Preview Card ──
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 18,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Center grab handle & Next/Prev dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.chevron_left, size: 22, color: Color(0xFF6B7280)),
                        onPressed: _activeStopIndex > 0 ? () => _focusStop(_activeStopIndex - 1) : null,
                      ),
                      Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1D5DB),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.chevron_right, size: 22, color: Color(0xFF6B7280)),
                        onPressed: _activeStopIndex < _stops.length - 1
                            ? () => _focusStop(_activeStopIndex + 1)
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Stop Details Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: activeStop.image.startsWith('assets/')
                            ? Image.asset(
                                activeStop.image,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => _buildPlaceholderThumbnail(),
                              )
                            : Image.network(
                                activeStop.image,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => _buildPlaceholderThumbnail(),
                              ),
                      ),
                      const SizedBox(width: 14),
                      // Details Column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'STOP ${activeStop.stopNum} OF ${_stops.length} · ${activeStop.location}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.figmaGold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              activeStop.title,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.figmaDarkGreen,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: AppColors.figmaGold,
                                  size: 16,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  activeStop.rating.toStringAsFixed(1),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.figmaDarkGreen,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              activeStop.time,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Distance & Transit Bar
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF2EC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          activeStop.distance,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: const Color(0xFF374151),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          activeStop.transit,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF064E3B),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // CTA Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/tour-search');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.figmaDarkGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.arrow_forward, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'View Stop Details',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
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
        ],
      ),
    );
  }

  Widget _buildPlaceholderThumbnail() {
    return Container(
      width: 80,
      height: 80,
      color: const Color(0xFFE5E7EB),
      child: const Icon(
        Icons.landscape,
        color: Color(0xFF9CA3AF),
      ),
    );
  }

  Widget _buildMapActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 20, color: AppColors.figmaDarkGreen),
        tooltip: tooltip,
        onPressed: onTap,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildMapPin({
    required IconData icon,
    required Color color,
    required bool isSelected,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isSelected ? 48 : 38,
      height: isSelected ? 48 : 38,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? AppColors.figmaGold : Colors.white,
          width: isSelected ? 3.0 : 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: isSelected ? 10 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: isSelected ? 24 : 18,
      ),
    );
  }

  Widget _buildLegendItem(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.figmaDarkGreen),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.figmaDarkGreen,
          ),
        ),
      ],
    );
  }
}
