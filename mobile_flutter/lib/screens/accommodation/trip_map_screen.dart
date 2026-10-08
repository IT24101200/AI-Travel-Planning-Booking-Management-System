import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../../app_constants.dart';
import '../../services/itinerary_route_service.dart';

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
  int _activeStopIndex = 0;
  bool _isSatellite = false;
  List<MapStopItem> _stops = [];
  List<LatLng> _roadPoints = [];
  Map<int, List<LatLng>> _dayRoutes = {};
  List<LatLng> _hotels = [];
  List<LatLng> _airports = [];
  List<int> _stopDays = [];
  String _tripTitle = 'Trip route';
  String _totalKm = '0';
  String? _routeError;
  List<String> _missingStops = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRoute());
  }

  Future<void> _loadRoute() async {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map) {
      setState(
        () => _routeError =
            'Open this map from a saved itinerary to see its route.',
      );
      return;
    }
    setState(() => _routeError = null);
    try {
      final route = args['roadRoute'] is ItineraryRoadRoute
          ? args['roadRoute'] as ItineraryRoadRoute
          : await ItineraryRouteService.load(args);
      if (!mounted) return;
      setState(() {
        _tripTitle = args['title']?.toString() ?? 'Your trip route';
        _roadPoints = route.points;
        _dayRoutes = route.dayRoutes;
        _hotels = route.hotelPoints;
        _airports = route.airportPoints;
        _stopDays = route.stops
            .map((s) => int.tryParse('${s.item['dayNumber']}') ?? 1)
            .toList();
        _missingStops = route.missingStops;
        _totalKm = (route.distanceMeters / 1000).toStringAsFixed(1);
        _activeStopIndex = 0;
        _stops = route.stops.asMap().entries.map((entry) {
          final item = entry.value.item;
          final name = item['tourName']?.toString() ?? 'Activity';
          return MapStopItem(
            stopNum: entry.key + 1,
            location: 'STOP ${entry.key + 1}',
            title: name,
            rating: 0,
            time: 'Day ${item['dayNumber']} · ${item['startTime'] ?? ''}',
            distance: 'Itinerary stop',
            transit: 'Driving route',
            image: AppDestinations.getImageForDestination(name),
            latLng: entry.value.point,
            icon: Icons.location_on,
            color: const Color(0xFF2563A6),
          );
        }).toList();
      });
    } catch (error) {
      if (mounted) setState(() => _routeError = '$error');
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// Centers the map on the given stop
  void _focusStop(int index) {
    if (index < 0 || index >= _stops.length) return;
    setState(() => _activeStopIndex = index);
    final stop = _stops[index];
    final camera = _mapController.camera;
    final points = [stop.latLng, ...?_dayRoutes[_stopDays[index]]];
    if (!points.every(camera.visibleBounds.contains)) {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.all(60),
          maxZoom: camera.zoom,
        ),
      );
    }
  }

  /// Fits all stops in camera view
  void _fitAllStops() {
    if (_stops.isEmpty) return;
    final points = [..._roadPoints, ..._stops.map((s) => s.latLng)];
    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: EdgeInsets.fromLTRB(
          50,
          120,
          50,
          MediaQuery.sizeOf(context).height * 0.35,
        ),
        maxZoom: 15,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_stops.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Trip route')),
        body: Center(
          child: _routeError == null
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_routeError!, textAlign: TextAlign.center),
                      TextButton(
                        onPressed: _loadRoute,
                        child: const Text('Retry directions'),
                      ),
                    ],
                  ),
                ),
        ),
      );
    }
    final activeStop = _stops[_activeStopIndex];
    final routePoints = _roadPoints;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // ── Real OpenStreetMap Interactive Canvas ──
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCameraFit: CameraFit.bounds(
                  bounds: LatLngBounds.fromPoints([
                    ..._roadPoints,
                    ..._stops.map((s) => s.latLng),
                  ]),
                  padding: EdgeInsets.fromLTRB(
                    50,
                    120,
                    50,
                    MediaQuery.sizeOf(context).height * 0.35,
                  ),
                  maxZoom: 15,
                ),
                minZoom: 1,
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
                  userAgentPackageName: 'com.serendibtrails.travel',
                ),

                // Realistic Polyline Route connecting Sri Lankan stops
                if (routePoints.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: routePoints,
                        color: const Color(0xFF2563A6),
                        strokeWidth: 4.5,
                        borderColor: Colors.white,
                        borderStrokeWidth: 1.8,
                      ),
                      if ((_dayRoutes[_stopDays[_activeStopIndex]]?.length ??
                              0) >
                          1)
                        Polyline(
                          points: _dayRoutes[_stopDays[_activeStopIndex]]!,
                          color: const Color(0xFFFCA5A5),
                          strokeWidth: 5,
                          borderColor: Colors.white,
                          borderStrokeWidth: 1,
                        ),
                    ],
                  ),

                // Interactive Markers positioned at real Sri Lankan GPS waypoints
                MarkerLayer(
                  markers: [
                    ..._stops.asMap().entries.map((entry) {
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
                    }),
                    for (final p in _hotels)
                      Marker(
                        point: p,
                        width: 30,
                        height: 30,
                        child: const Icon(
                          Icons.hotel,
                          color: Color(0xFF2563A6),
                          size: 28,
                        ),
                      ),
                    for (final p in _airports)
                      Marker(
                        point: p,
                        width: 30,
                        height: 30,
                        child: const Icon(
                          Icons.flight,
                          color: Color(0xFF2563A6),
                          size: 28,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          if (_missingStops.isNotEmpty)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 72,
              left: 16,
              right: 16,
              child: Material(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Route incomplete. Missing GPS: ${_missingStops.toSet().join(', ')}',
                  ),
                ),
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
                          content: Text(
                            _isSatellite
                                ? 'Switched to Satellite View'
                                : 'Switched to Street Map',
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _isSatellite
                            ? AppColors.figmaGold
                            : Theme.of(context).cardColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.layers_outlined,
                        color: _isSatellite
                            ? Colors.white
                            : Theme.of(context).colorScheme.primary,
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
                  _buildLegendItem(
                    Icons.account_balance_outlined,
                    'Attraction',
                  ),
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
                        icon: const Icon(
                          Icons.chevron_left,
                          size: 22,
                          color: Color(0xFF6B7280),
                        ),
                        onPressed: _activeStopIndex > 0
                            ? () => _focusStop(_activeStopIndex - 1)
                            : null,
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
                        icon: const Icon(
                          Icons.chevron_right,
                          size: 22,
                          color: Color(0xFF6B7280),
                        ),
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
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildPlaceholderThumbnail(),
                              )
                            : Image.network(
                                activeStop.image,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildPlaceholderThumbnail(),
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
      child: const Icon(Icons.landscape, color: Color(0xFF9CA3AF)),
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
          color: isSelected ? const Color(0xFFFCA5A5) : Colors.white,
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
      child: Icon(icon, color: Colors.white, size: isSelected ? 24 : 18),
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
