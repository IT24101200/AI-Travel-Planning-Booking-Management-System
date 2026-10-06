import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/itinerary_route_service.dart';

class ItineraryRoutePreview extends StatefulWidget {
  const ItineraryRoutePreview({
    super.key,
    required this.itinerary,
    this.selectedItem,
    this.routeLoader = ItineraryRouteService.load,
    this.tileProvider,
  });
  final Map<String, dynamic> itinerary;
  final Map<String, dynamic>? selectedItem;
  final Future<ItineraryRoadRoute> Function(Map<String, dynamic>) routeLoader;
  final TileProvider? tileProvider;

  @override
  State<ItineraryRoutePreview> createState() => _ItineraryRoutePreviewState();
}

class _JourneyPreviewMap extends StatefulWidget {
  const _JourneyPreviewMap({
    super.key,
    required this.route,
    required this.selectedItem,
    this.tileProvider,
  });

  final ItineraryRoadRoute route;
  final Map<String, dynamic>? selectedItem;
  final TileProvider? tileProvider;

  @override
  State<_JourneyPreviewMap> createState() => _JourneyPreviewMapState();
}

class _JourneyPreviewMapState extends State<_JourneyPreviewMap>
    with SingleTickerProviderStateMixin {
  final _mapController = MapController();
  late final AnimationController _animation;
  late LatLng _dotFrom;
  late LatLng _dotTo;
  LatLng? _cameraFrom;
  LatLng? _cameraTo;
  double _zoomFrom = 0;
  double _zoomTo = 0;
  bool _mapReady = false;

  double get _progress => Curves.easeInOutCubic.transform(_animation.value);

  LatLng _between(LatLng from, LatLng to) => LatLng(
    from.latitude + (to.latitude - from.latitude) * _progress,
    from.longitude + (to.longitude - from.longitude) * _progress,
  );

  LatLng get _dotPoint => _between(_dotFrom, _dotTo);

  bool _sameItem(Map? left, Map? right) {
    if (left == null || right == null) return left == right;
    if (left['id'] != null && right['id'] != null) {
      return '${left['id']}' == '${right['id']}';
    }
    return [
      'tourId',
      'dayNumber',
      'sequenceOrder',
      'startTime',
    ].every((key) => '${left[key]}' == '${right[key]}');
  }

  ItineraryRouteStop? get _selectedStop {
    final item = widget.selectedItem;
    if (item == null) return widget.route.stops.first;
    for (final stop in widget.route.stops) {
      final candidate = stop.item;
      if (_sameItem(item, candidate)) return stop;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _dotFrom = _dotTo = widget.route.stops.first.point;
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
      value: 1,
    )..addListener(_moveCamera);
  }

  @override
  void didUpdateWidget(_JourneyPreviewMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameItem(oldWidget.selectedItem, widget.selectedItem)) {
      _focusSelectedStop();
    }
  }

  void _moveCamera() {
    if (!_mapReady || _cameraFrom == null || _cameraTo == null) return;
    _mapController.move(
      _between(_cameraFrom!, _cameraTo!),
      _zoomFrom + (_zoomTo - _zoomFrom) * _progress,
    );
  }

  void _focusSelectedStop() {
    final stop = _selectedStop;
    if (!_mapReady || stop == null) return;
    final currentDot = _dotPoint;
    final camera = _mapController.camera;
    _animation.stop();
    _dotFrom = currentDot;
    _dotTo = stop.point;
    _cameraFrom = camera.center;
    _cameraTo = stop.point;
    _zoomFrom = camera.zoom;
    _zoomTo = 14.5;
    _animation.forward(from: 0);
  }

  @override
  void dispose() {
    _animation.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCameraFit: CameraFit.bounds(
            bounds: LatLngBounds.fromPoints([
              ...widget.route.points,
              ...widget.route.stops.map((s) => s.point),
            ]),
            padding: const EdgeInsets.fromLTRB(32, 64, 32, 32),
            maxZoom: 15,
          ),
          onMapReady: () {
            _mapReady = true;
            if (widget.selectedItem != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _focusSelectedStop();
              });
            }
          },
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
          onPositionChanged: (_, hasGesture) {
            if (hasGesture && _animation.isAnimating) {
              _animation.stop();
              _cameraFrom = _cameraTo = null;
              _dotFrom = _dotTo;
              _animation.value = 1;
            }
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.serendibtrails.travel',
            tileProvider: widget.tileProvider,
          ),
          if (widget.route.points.length > 1)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: widget.route.points,
                  color: const Color(0xFF0E382C),
                  strokeWidth: 4,
                  borderStrokeWidth: 1.5,
                  borderColor: const Color(0xFFD4A346),
                ),
              ],
            ),
          AnimatedBuilder(
            animation: _animation,
            builder: (context, _) => MarkerLayer(
              markers: [
                ...widget.route.stops
                    .where(
                      (stop) => stop.point != _dotTo && stop.point != _dotPoint,
                    )
                    .map(
                      (stop) => Marker(
                        point: stop.point,
                        width: 26,
                        height: 26,
                        child: const Icon(
                          Icons.location_on,
                          color: Color(0xFF0E382C),
                          size: 26,
                        ),
                      ),
                    ),
                Marker(
                  point: _dotPoint,
                  width: 28,
                  height: 28,
                  child: Semantics(
                    label: 'Selected journey location',
                    child: Container(
                      key: const ValueKey('journey-location-dot'),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7DD3FC).withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF7DD3FC),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const RichAttributionWidget(
            attributions: [TextSourceAttribution('OpenStreetMap contributors')],
          ),
        ],
      ),
      if (_selectedStop == null)
        Positioned(
          left: 12,
          right: 12,
          top: 62,
          child: Material(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'GPS unavailable for ${widget.selectedItem?['tourName'] ?? 'this stop'}.',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ),
    ],
  );
}

class _ItineraryRoutePreviewState extends State<ItineraryRoutePreview> {
  late Future<ItineraryRoadRoute> _route;

  Future<ItineraryRoadRoute> _loadRoute() {
    final future = widget.routeLoader(widget.itinerary);
    // Listen immediately: retry errors can arrive before FutureBuilder rebuilds.
    // FutureBuilder still receives and displays the same future's error.
    future.ignore();
    return future;
  }

  @override
  void initState() {
    super.initState();
    _route = _loadRoute();
  }

  @override
  void didUpdateWidget(ItineraryRoutePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.itinerary, widget.itinerary)) {
      _route = _loadRoute();
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * 0.4,
    width: double.infinity,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: FutureBuilder<ItineraryRoadRoute>(
        future: _route,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ColoredBox(
              color: Theme.of(context).cardColor,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${snapshot.error}', textAlign: TextAlign.center),
                      TextButton(
                        onPressed: () => setState(() {
                          _route = _loadRoute();
                        }),
                        child: const Text('Retry directions'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          final route = snapshot.data;
          if (route == null) {
            return const Center(child: CircularProgressIndicator());
          }
          void openRoute() => Navigator.pushNamed(
            context,
            '/trip-map',
            arguments: {...widget.itinerary, 'roadRoute': route},
          );
          return Stack(
            children: [
              _JourneyPreviewMap(
                key: ValueKey(route),
                route: route,
                selectedItem: widget.selectedItem,
                tileProvider: widget.tileProvider,
              ),
              Positioned(
                top: 12,
                left: 14,
                child: FilledButton.icon(
                  onPressed: openRoute,
                  icon: const Icon(Icons.route, size: 16),
                  label: const Text('VIEW FULL ROUTE'),
                ),
              ),
              if (route.missingStops.isNotEmpty)
                Positioned(
                  bottom: 24,
                  left: 12,
                  right: 12,
                  child: Material(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        'Route incomplete. Missing GPS: ${route.missingStops.toSet().join(', ')}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}
