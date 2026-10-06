import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../services/itinerary_route_service.dart';

class ItineraryRoutePreview extends StatefulWidget {
  const ItineraryRoutePreview({super.key, required this.itinerary});
  final Map<String, dynamic> itinerary;

  @override
  State<ItineraryRoutePreview> createState() => _ItineraryRoutePreviewState();
}

class _ItineraryRoutePreviewState extends State<ItineraryRoutePreview> {
  late Future<ItineraryRoadRoute> _route;

  Future<ItineraryRoadRoute> _loadRoute() {
    final future = ItineraryRouteService.load(widget.itinerary);
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
          return GestureDetector(
            onTap: openRoute,
            child: Stack(
              children: [
                IgnorePointer(
                  child: FlutterMap(
                    key: ValueKey(route),
                    options: MapOptions(
                      initialCameraFit: CameraFit.bounds(
                        bounds: LatLngBounds.fromPoints([
                          ...route.points,
                          ...route.stops.map((s) => s.point),
                        ]),
                        padding: const EdgeInsets.fromLTRB(32, 64, 32, 32),
                        maxZoom: 15,
                      ),
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.serendibtrails.travel',
                      ),
                      if (route.points.length > 1)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: route.points,
                              color: const Color(0xFF0E382C),
                              strokeWidth: 4,
                              borderStrokeWidth: 1.5,
                              borderColor: const Color(0xFFD4A346),
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: route.stops
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
                            )
                            .toList(),
                      ),
                      const RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution('OpenStreetMap contributors'),
                        ],
                      ),
                    ],
                  ),
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
            ),
          );
        },
      ),
    ),
  );
}
