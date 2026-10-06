import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../app_constants.dart';

/// Trip map screen — OpenStreetMap with route polyline, numbered markers,
/// and animated pan-to on waypoint tap.
class TripMapScreen extends StatefulWidget {
  const TripMapScreen({super.key});

  @override
  State<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends State<TripMapScreen>
    with TickerProviderStateMixin {
  late final MapController _mapController;
  int _focusedIndex = -1;
  List<LatLng> _detailedRoutePoints = [];
  bool _isLoadingRoute = false;

  // Default iconic Sri Lanka circuit
  static const List<Map<String, dynamic>> _defaultStops = [
    {
      'name': 'Sigiriya Lion Rock Fortress',
      'type': 'Heritage',
      'latitude': 7.9570,
      'longitude': 80.7603,
      'region': 'Matale District',
      'icon': Icons.castle_outlined,
    },
    {
      'name': 'Temple of the Sacred Tooth',
      'type': 'Temple',
      'latitude': 7.2906,
      'longitude': 80.6337,
      'region': 'Kandy',
      'icon': Icons.temple_hindu_outlined,
    },
    {
      'name': 'Nine Arches Colonial Bridge',
      'type': 'Tour',
      'latitude': 6.8667,
      'longitude': 81.0466,
      'region': 'Ella Valley',
      'icon': Icons.train_outlined,
    },
    {
      'name': 'Mirissa Coconut Tree Hill',
      'type': 'Beach',
      'latitude': 5.9483,
      'longitude': 80.4589,
      'region': 'Southern Coast',
      'icon': Icons.beach_access_outlined,
    },
    {
      'name': 'Yala Leopard Safari Zone',
      'type': 'Wildlife',
      'latitude': 6.3728,
      'longitude': 81.5019,
      'region': 'Ruhuna',
      'icon': Icons.park_outlined,
    },
  ];

  List<Map<String, dynamic>> _stops = [];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_stops.isNotEmpty) return; // already set

    final args = ModalRoute.of(context)?.settings.arguments;
    List<Map<String, dynamic>> parsed = [];

    if (args is List) {
      parsed = args.cast<Map<String, dynamic>>();
    } else if (args is Map<String, dynamic>) {
      final items = args['items'] as List<dynamic>? ?? [];
      parsed = items.map((i) {
        return <String, dynamic>{
          'name': i['tourName'] ?? 'Attraction Stop',
          'type': 'Tour',
          'latitude': 7.9570, // Needs real coordinates for production
          'longitude': 80.7603,
          'region': 'Sri Lanka',
          'icon': Icons.tour_outlined,
        };
      }).toList();
    }

    setState(() {
      _stops = parsed.isEmpty ? _defaultStops : parsed;
    });
    
    _fetchRoute();
  }

  Future<void> _fetchRoute() async {
    if (_stops.length < 2) return;
    setState(() => _isLoadingRoute = true);

    try {
      final coordinatesString = _stops.map((s) {
        final lat = (s['latitude'] as num).toDouble();
        final lng = (s['longitude'] as num).toDouble();
        return '$lng,$lat';
      }).join(';');

      final url = Uri.parse(
          'https://router.project-osrm.org/route/v1/driving/$coordinatesString?overview=full&geometries=geojson');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 'Ok' && data['routes'] != null && data['routes'].isNotEmpty) {
          final coordinates = data['routes'][0]['geometry']['coordinates'] as List;
          final List<LatLng> points = coordinates.map((coord) {
            return LatLng((coord[1] as num).toDouble(), (coord[0] as num).toDouble());
          }).toList();

          if (mounted) {
            setState(() {
              _detailedRoutePoints = points;
              _isLoadingRoute = false;
            });
          }
        } else {
          if (mounted) setState(() => _isLoadingRoute = false);
        }
      } else {
        if (mounted) setState(() => _isLoadingRoute = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingRoute = false);
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  // Compute the centre of all waypoints so the map opens centred on the route
  LatLng get _routeCenter {
    if (_stops.isEmpty) return const LatLng(7.8731, 80.7718);
    final avgLat =
        _stops.map((s) => (s['latitude'] as num).toDouble()).reduce((a, b) => a + b) /
            _stops.length;
    final avgLng =
        _stops.map((s) => (s['longitude'] as num).toDouble()).reduce((a, b) => a + b) /
            _stops.length;
    return LatLng(avgLat, avgLng);
  }

  List<LatLng> get _routePoints =>
      _stops.map((s) => LatLng((s['latitude'] as num).toDouble(), (s['longitude'] as num).toDouble())).toList();

  void _panTo(int index) {
    setState(() => _focusedIndex = index);
    final stop = _stops[index];
    final target = LatLng(
      (stop['latitude'] as num).toDouble(),
      (stop['longitude'] as num).toDouble(),
    );

    // Animate pan with AnimationController for smooth movement
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    final latTween = Tween<double>(begin: _mapController.camera.center.latitude, end: target.latitude);
    final lngTween = Tween<double>(begin: _mapController.camera.center.longitude, end: target.longitude);
    final zoomTween = Tween<double>(begin: _mapController.camera.zoom, end: 10.0);
    final curve = CurvedAnimation(parent: controller, curve: Curves.easeInOut);

    controller.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(curve), lngTween.evaluate(curve)),
        zoomTween.evaluate(curve),
      );
    });
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) controller.dispose();
    });
    controller.forward();
  }

  Color _typeColor(String type) {
    switch (type.toLowerCase()) {
      case 'heritage':
        return const Color(0xFFD97706);
      case 'temple':
        return const Color(0xFF7C3AED);
      case 'beach':
        return const Color(0xFF0EA5E9);
      case 'wildlife':
        return const Color(0xFF16A34A);
      default:
        return AppColors.jungle600;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text(
          'Trip Route Map',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.jungle900,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.fit_screen_outlined),
            tooltip: 'Fit all waypoints',
            onPressed: () {
              _mapController.move(_routeCenter, 7.0);
              setState(() => _focusedIndex = -1);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── OSM Map ──
          Expanded(
            flex: 6,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _routeCenter,
                    initialZoom: 7.0,
                    maxZoom: 18.0,
                    minZoom: 5.0,
                  ),
                  children: [
                    // OpenStreetMap tile layer
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.aitravel.mobile',
                      maxZoom: 18,
                    ),

                    // Route polyline connecting all stops
                    if (_routePoints.length > 1)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _detailedRoutePoints.isNotEmpty
                                ? _detailedRoutePoints
                                : _routePoints,
                            strokeWidth: 3.5,
                            color: AppColors.jungle600.withValues(alpha: 0.75),
                            pattern: StrokePattern.dashed(
                              segments: const [12.0, 6.0],
                            ),
                          ),
                        ],
                      ),

                    // Numbered markers
                    MarkerLayer(
                      markers: List.generate(_stops.length, (i) {
                        final stop = _stops[i];
                        final lat = (stop['latitude'] as num).toDouble();
                        final lng = (stop['longitude'] as num).toDouble();
                        final isFocused = _focusedIndex == i;
                        final color = _typeColor(stop['type'] ?? '');

                        return Marker(
                          point: LatLng(lat, lng),
                          width: isFocused ? 44 : 32,
                          height: isFocused ? 44 : 32,
                          alignment: Alignment.topCenter,
                          child: GestureDetector(
                            onTap: () => _panTo(i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: isFocused ? 44 : 32,
                              height: isFocused ? 44 : 32,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.ocean400,
                                  width: isFocused ? 3 : 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.ocean400.withValues(alpha: 0.3),
                                    blurRadius: isFocused ? 12 : 6,
                                    spreadRadius: isFocused ? 2 : 0,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.my_location,
                                  color: AppColors.ocean400,
                                  size: isFocused ? 22 : 16,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),

                // Floating stop count badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.jungle900.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.route, color: Colors.white, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          '${_stops.length} waypoints',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // OSM attribution (required by OSM license)
                Positioned(
                  bottom: 4,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '© OpenStreetMap contributors',
                      style: TextStyle(fontSize: 9, color: Colors.black54),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Waypoint list panel ──
          Expanded(
            flex: 4,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 12,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Drag handle
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.place, color: AppColors.jungle600, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Tap a stop to navigate',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      itemCount: _stops.length,
                      itemBuilder: (context, index) {
                        final stop = _stops[index];
                        final isFocused = _focusedIndex == index;
                        final color = _typeColor(stop['type'] ?? '');
                        final isLast = index == _stops.length - 1;

                        return GestureDetector(
                          onTap: () => _panTo(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isFocused
                                  ? color.withValues(alpha: 0.1)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isFocused ? color : AppColors.line,
                                width: isFocused ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Step number with connector line
                                Column(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: isFocused
                                            ? color
                                            : color.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${index + 1}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                            color: isFocused ? Colors.white : color,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (!isLast)
                                      Container(
                                        width: 2,
                                        height: 18,
                                        margin: const EdgeInsets.symmetric(vertical: 2),
                                        color: color.withValues(alpha: 0.25),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 10),

                                // Name, type, coords
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        stop['name'] ?? 'Stop ${index + 1}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: isFocused ? color : AppColors.ink,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: color.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              stop['type'] ?? 'Location',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: color,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              stop['region'] ?? 'Sri Lanka',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.ink3,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Navigate icon
                                Icon(
                                  Icons.my_location,
                                  color: isFocused ? color : AppColors.ink3,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
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
}
