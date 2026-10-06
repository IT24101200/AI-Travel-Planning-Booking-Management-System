import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/hotel_location_service.dart';
import '../services/itinerary_route_service.dart';
import '../services/trip_selection_service.dart';

class HotelRouteMap extends StatefulWidget {
  const HotelRouteMap({
    super.key,
    required this.hotel,
    this.routeLoader = _loadRoute,
    this.locationLoader = HotelLocationService.currentLocation,
    this.tileProvider,
  });
  final Map<String, dynamic> hotel;
  final Future<ItineraryRoadRoute> Function(List<LatLng>) routeLoader;
  final Future<LatLng> Function() locationLoader;
  final TileProvider? tileProvider;
  static Future<ItineraryRoadRoute> _loadRoute(List<LatLng> points) =>
      ItineraryRouteService.fetchRoadRoute(points);
  static const routeColor = Color(0xFF7DD3FC);

  @override
  State<HotelRouteMap> createState() => _HotelRouteMapState();
}

class _HotelRouteMapState extends State<HotelRouteMap> {
  final _controller = MapController();
  LatLng? _origin;
  ItineraryRoadRoute? _route;
  String? _error;
  String _originLabel = 'Choose a starting point';
  bool _picking = false;
  bool _locating = false;
  bool _loading = false;
  bool _ready = false;
  int _request = 0;
  int _locationRequest = 0;
  LatLng? get _destination => ItineraryRouteService.coordinates(widget.hotel);

  @override
  void initState() {
    super.initState();
    _origin = TripSelectionService.hotelDirectionsOrigin;
    _originLabel =
        TripSelectionService.hotelDirectionsOriginLabel ?? _originLabel;
    if (_origin != null) _refreshRoute();
  }

  @override
  void didUpdateWidget(HotelRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (ItineraryRouteService.coordinates(oldWidget.hotel) != _destination) {
      _refreshRoute();
    }
  }

  void _fit() {
    if (!_ready || _destination == null) return;
    final points = [_destination!, ?_origin, ...?_route?.points];
    if (points.every((p) => p == points.first)) {
      _controller.move(points.first, 14);
    } else {
      _controller.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.all(36),
          maxZoom: 16,
        ),
      );
    }
  }

  void _setOrigin(LatLng point, String label) {
    _locationRequest++;
    TripSelectionService.hotelDirectionsOrigin = point;
    TripSelectionService.hotelDirectionsOriginLabel = label;
    setState(() {
      _origin = point;
      _originLabel = label;
      _picking = false;
      _locating = false;
    });
    _refreshRoute();
  }

  Future<void> _refreshRoute() async {
    final request = ++_request;
    final destination = _destination;
    setState(() {
      _route = null;
      _error = null;
      _loading =
          destination != null && _origin != null && destination != _origin;
    });
    _fit();
    if (!_loading) return;
    try {
      final route = await widget.routeLoader([_origin!, destination!]);
      if (!mounted || request != _request) return;
      setState(() {
        _route = route;
        _loading = false;
      });
      _fit();
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _locate() async {
    final request = ++_locationRequest;
    setState(() {
      _locating = true;
      _error = null;
      _picking = false;
    });
    try {
      final point = await widget.locationLoader();
      if (!mounted || request != _locationRequest) return;
      _setOrigin(point, 'Current location');
    } catch (error) {
      if (!mounted || request != _locationRequest) return;
      setState(() {
        _error = error.toString();
        _locating = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final destination = _destination;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              TextButton.icon(
                onPressed: _locating ? null : _locate,
                icon: const Icon(Icons.my_location, size: 18),
                label: Text(_locating ? 'Locating…' : 'My location'),
              ),
              TextButton.icon(
                onPressed: () => setState(() {
                  _locationRequest++;
                  _locating = false;
                  _picking = !_picking;
                }),
                icon: const Icon(Icons.touch_app, size: 18),
                label: Text(_picking ? 'Tap map to start' : 'Pick on map'),
              ),
              PopupMenuButton<String>(
                tooltip: 'Airport',
                onSelected: (value) => _setOrigin(
                  value == 'CMB'
                      ? const LatLng(7.1802, 79.8842)
                      : const LatLng(6.2845, 81.1241),
                  value == 'CMB'
                      ? 'Bandaranaike airport (CMB)'
                      : 'Mattala airport (HRI)',
                ),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'CMB',
                    child: Text('Bandaranaike (CMB)'),
                  ),
                  PopupMenuItem(value: 'HRI', child: Text('Mattala (HRI)')),
                ],
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Icon(Icons.flight, size: 18),
                      SizedBox(width: 6),
                      Text('Airport'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: destination == null
                ? const Center(
                    child: Text('This hotel has no verified GPS location yet.'),
                  )
                : Stack(
                    children: [
                      FlutterMap(
                        mapController: _controller,
                        options: MapOptions(
                          initialCenter: destination,
                          initialZoom: 14,
                          onMapReady: () {
                            _ready = true;
                            _fit();
                          },
                          interactionOptions: const InteractionOptions(
                            flags:
                                InteractiveFlag.all & ~InteractiveFlag.rotate,
                          ),
                          onTap: (_, point) {
                            if (_picking) {
                              _setOrigin(point, 'Picked starting point');
                            }
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.mobile_flutter',
                            tileProvider: widget.tileProvider,
                          ),
                          if (_route != null)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: _route!.points,
                                  color: HotelRouteMap.routeColor,
                                  strokeWidth: 5,
                                  borderColor: Colors.white,
                                  borderStrokeWidth: 1,
                                ),
                              ],
                            ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: destination,
                                width: 36,
                                height: 36,
                                child: const Icon(
                                  Icons.hotel,
                                  color: Color(0xFF0369A1),
                                  size: 32,
                                ),
                              ),
                              if (_origin != null && _origin != destination)
                                Marker(
                                  point: _origin!,
                                  width: 20,
                                  height: 20,
                                  child: Container(
                                    key: const ValueKey('hotel-origin-dot'),
                                    decoration: BoxDecoration(
                                      color: HotelRouteMap.routeColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 3,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const RichAttributionWidget(
                            attributions: [
                              TextSourceAttribution(
                                '© OpenStreetMap contributors',
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (_loading)
                        const Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: LinearProgressIndicator(),
                        ),
                      Positioned(
                        top: 8,
                        left: 8,
                        right: 8,
                        child: IgnorePointer(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surface.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _picking
                                  ? 'Tap the map to choose your start'
                                  : _origin == null
                                  ? _originLabel
                                  : '$_originLabel → ${widget.hotel['name']}${_route == null ? '' : ' · ${(_route!.distanceMeters / 1000).toStringAsFixed(1)} km'}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                      ),
                      if (_error != null)
                        Positioned(
                          bottom: 26,
                          left: 8,
                          right: 8,
                          child: Material(
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                  if (_origin != null)
                                    TextButton(
                                      onPressed: _refreshRoute,
                                      child: const Text('Retry'),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
