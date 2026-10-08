import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/itinerary_route_service.dart';
import '../services/date_time_contract.dart';

class ItineraryRoutePreview extends StatefulWidget {
  const ItineraryRoutePreview({
    super.key,
    required this.itinerary,
    this.selectedItem,
    this.booking,
    this.routeLoader = ItineraryRouteService.load,
    this.hotelRouteLoader = ItineraryRouteService.fetchRoadRoute,
    this.tileProvider,
  });
  final Map<String, dynamic> itinerary;
  final Map<String, dynamic>? selectedItem;
  final Map<String, dynamic>? booking;
  final Future<ItineraryRoadRoute> Function(Map<String, dynamic>) routeLoader;
  final Future<ItineraryRoadRoute> Function(List<LatLng>) hotelRouteLoader;
  final TileProvider? tileProvider;

  @override
  State<ItineraryRoutePreview> createState() => _ItineraryRoutePreviewState();
}

class _JourneyPreviewMap extends StatefulWidget {
  const _JourneyPreviewMap({
    super.key,
    required this.route,
    required this.selectedItem,
    required this.hotelPoint,
    required this.hotelRouteLoader,
    this.tileProvider,
  });

  final ItineraryRoadRoute route;
  final Map<String, dynamic>? selectedItem;
  final LatLng? hotelPoint;
  final Future<ItineraryRoadRoute> Function(List<LatLng>) hotelRouteLoader;
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
  final _hotelRoutes = <String, ItineraryRoadRoute>{};
  ItineraryRoadRoute? _hotelRoute;
  String? _hotelRouteError;
  int _routeRequest = 0;

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
    final point = ItineraryRouteService.coordinates(item);
    if (point != null) return ItineraryRouteStop(item, point);
    return null;
  }

  List<LatLng> get _selectedDayPoints =>
      widget.route.dayRoutes[int.tryParse(
        '${widget.selectedItem?['dayNumber'] ?? widget.route.stops.first.item['dayNumber']}',
      )] ??
      _hotelRoute?.points ??
      const [];

  @override
  void initState() {
    super.initState();
    _dotFrom = _dotTo = widget.route.stops.first.point;
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
      value: 1,
    )..addListener(_moveCamera);
    _loadHotelRoute();
  }

  @override
  void didUpdateWidget(_JourneyPreviewMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameItem(oldWidget.selectedItem, widget.selectedItem) ||
        oldWidget.hotelPoint != widget.hotelPoint) {
      _focusSelectedStop();
      _loadHotelRoute();
    }
  }

  Future<void> _loadHotelRoute() async {
    final request = ++_routeRequest;
    var origin = widget.hotelPoint;
    var destination = _selectedStop?.point;
    if (widget.selectedItem?['stopKind'] != null) {
      final day = '${widget.selectedItem?['dayNumber']}';
      final visits = widget.route.stops.where(
        (stop) =>
            '${stop.item['dayNumber']}' == day &&
            stop.item['isTransferDay'] != true,
      );
      if (visits.isNotEmpty) {
        if (widget.selectedItem?['stopKind'] == 'checkout') {
          destination = visits.first.point;
        } else {
          origin = visits.last.point;
        }
      }
    }
    setState(() {
      _hotelRoute = null;
      _hotelRouteError = null;
    });
    if (origin == null || destination == null || origin == destination) return;
    if (widget.route.dayRoutes.isNotEmpty) return;
    final key = '$origin/$destination';
    try {
      final route =
          _hotelRoutes[key] ??
          await widget.hotelRouteLoader([origin, destination]);
      if (!mounted || request != _routeRequest) return;
      _hotelRoutes[key] = route;
      setState(() => _hotelRoute = route);
      _focusSelectedStop();
    } catch (_) {
      if (!mounted || request != _routeRequest) return;
      setState(() {
        _hotelRouteError = 'Hotel directions unavailable.';
      });
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
    final focusPoints = [
      stop.point,
      if (widget.route.dayRoutes.isEmpty) ?widget.hotelPoint,
      ..._selectedDayPoints,
    ];
    _cameraFrom = _cameraTo = null;
    _zoomFrom = camera.zoom;
    _zoomTo = camera.zoom;
    if (!focusPoints.every(camera.visibleBounds.contains)) {
      final fitted = CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(focusPoints),
        padding: const EdgeInsets.fromLTRB(32, 64, 32, 32),
        maxZoom: camera.zoom,
      ).fit(camera);
      _cameraFrom = camera.center;
      _cameraTo = fitted.center;
      _zoomTo = fitted.zoom;
    }
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
              ?widget.hotelPoint,
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
          if (widget.route.points.length > 1 || _hotelRoute != null)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: widget.route.points,
                  color: const Color(0xFF2563A6),
                  strokeWidth: 4,
                  borderStrokeWidth: 1.5,
                  borderColor: Colors.white,
                ),
                if (_selectedDayPoints.length > 1)
                  Polyline(
                    points: _selectedDayPoints,
                    color: const Color(0xFFFCA5A5),
                    strokeWidth: 5,
                    borderStrokeWidth: 1,
                    borderColor: Colors.white,
                  ),
              ],
            ),
          AnimatedBuilder(
            animation: _animation,
            builder: (context, _) => MarkerLayer(
              markers: [
                for (final hotel in {
                  ...widget.route.hotelPoints,
                  ?widget.hotelPoint,
                })
                  Marker(
                    point: hotel,
                    width: 30,
                    height: 30,
                    child: const Icon(
                      Icons.hotel,
                      color: Color(0xFF2563A6),
                      size: 28,
                      semanticLabel: 'Booked hotel',
                    ),
                  ),
                for (final airport in widget.route.airportPoints)
                  Marker(
                    point: airport,
                    width: 30,
                    height: 30,
                    child: const Icon(
                      Icons.flight,
                      color: Color(0xFF2563A6),
                      size: 28,
                    ),
                  ),
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
                          color: Color(0xFF2563A6),
                          size: 26,
                        ),
                      ),
                    ),
                ..._directionMarkers(),
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
                        color: const Color(0xFF2563A6).withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563A6),
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
      if (_hotelRouteError != null)
        Positioned(
          left: 12,
          bottom: 26,
          child: Material(
            borderRadius: BorderRadius.circular(8),
            child: TextButton(
              onPressed: _loadHotelRoute,
              child: Text('$_hotelRouteError Retry'),
            ),
          ),
        ),
    ],
  );

  List<Marker> _directionMarkers() {
    final points = _selectedDayPoints;
    if (points.length < 2) return [];
    final count = math.min(3, points.length - 1);
    return List.generate(count, (index) {
      final segment = ((index + 1) * (points.length - 1) / (count + 1)).floor();
      final from = points[segment], to = points[segment + 1];
      final bearing = const Distance().bearing(from, to);
      return Marker(
        point: LatLng(
          (from.latitude + to.latitude) / 2,
          (from.longitude + to.longitude) / 2,
        ),
        width: 28,
        height: 28,
        child: Semantics(
          label: 'Selected day travel direction',
          child: Transform.rotate(
            angle: bearing * math.pi / 180,
            child: const Icon(
              Icons.navigation,
              color: Color(0xFFFCA5A5),
              size: 25,
              shadows: [Shadow(color: Colors.white, blurRadius: 3)],
            ),
          ),
        ),
      );
    });
  }
}

class _ItineraryRoutePreviewState extends State<ItineraryRoutePreview> {
  late Future<ItineraryRoadRoute> _route;

  LatLng? get _hotelPoint {
    if (widget.selectedItem?['hotelStay'] is Map) {
      final selectedPoint = ItineraryRouteService.coordinates(
        widget.selectedItem!,
      );
      if (selectedPoint != null) return selectedPoint;
    }
    final items =
        widget.booking?['bookingItems'] ?? widget.itinerary['bookingItems'];
    if (items is! List) return null;
    final selected =
        widget.selectedItem ??
        ItineraryRouteService.orderedItems(widget.itinerary).firstOrNull;
    final start = parseDateOnly(widget.itinerary['startDate']);
    final day = int.tryParse('${selected?['dayNumber']}') ?? 1;
    final date = start?.add(Duration(days: day - 1));
    LatLng? checkoutHotel;
    for (final item in items.whereType<Map>()) {
      final type = item['itemType']?.toString().toLowerCase();
      if (type != 'room' &&
          type != 'hotel' &&
          type != '1' &&
          item['hotelName'] == null) {
        continue;
      }
      final point = ItineraryRouteService.coordinates({
        'latitude': item['hotelLatitude'],
        'longitude': item['hotelLongitude'],
      });
      if (point == null) continue;
      final checkIn = parseDateOnly(item['checkInDate']);
      final checkOut = parseDateOnly(item['checkOutDate']);
      if (date != null) {
        if (checkIn != null && date.isBefore(checkIn)) continue;
        if (checkOut != null && !date.isBefore(checkOut)) {
          if (date == checkOut) checkoutHotel = point;
          continue;
        }
      }
      return point;
    }
    return checkoutHotel;
  }

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
                hotelPoint: _hotelPoint,
                hotelRouteLoader: widget.hotelRouteLoader,
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
