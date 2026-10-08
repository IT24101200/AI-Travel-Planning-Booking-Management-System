import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_flutter/services/itinerary_route_service.dart';
import 'package:mobile_flutter/widgets/itinerary_route_preview.dart';

void main() {
  testWidgets(
    'map responds to dragging, pinch zoom and double tap without opening another screen',
    (tester) async {
      await tester.pumpWidget(_SelectionHarness(onLoad: () {}));
      await tester.pumpAndSettle();
      final map = find.byType(FlutterMap);
      final controller = tester.widget<FlutterMap>(map).mapController!;
      final initialCenter = controller.camera.center;
      await tester.drag(map, const Offset(80, 0));
      await tester.pumpAndSettle();
      expect(
        controller.camera.center.longitude,
        isNot(closeTo(initialCenter.longitude, 0.000001)),
      );

      final center = tester.getCenter(map);
      final beforePinch = controller.camera.zoom;
      final left = await tester.startGesture(
        center - const Offset(30, 0),
        pointer: 1,
      );
      final right = await tester.startGesture(
        center + const Offset(30, 0),
        pointer: 2,
      );
      await tester.pump();
      await left.moveTo(center - const Offset(70, 0));
      await right.moveTo(center + const Offset(70, 0));
      await tester.pump();
      await left.up();
      await right.up();
      await tester.pumpAndSettle();
      expect(controller.camera.zoom, greaterThan(beforePinch));

      final beforeDoubleTap = controller.camera.zoom;
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(center);
      await tester.pumpAndSettle();
      expect(controller.camera.zoom, greaterThan(beforeDoubleTap));
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'visible stops animate the dot without moving or zooming the map or reloading directions',
    (tester) async {
      var loads = 0;
      await tester.pumpWidget(_SelectionHarness(onLoad: () => loads++));
      await tester.pumpAndSettle();

      LatLng dot() => tester
          .widget<MarkerLayer>(find.byType(MarkerLayer))
          .markers
          .last
          .point;
      final controller = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      final initialCenter = controller.camera.center;
      final initialZoom = controller.camera.zoom;
      expect(dot(), const LatLng(7.29, 80.63));
      expect(
        tester
            .widget<MarkerLayer>(find.byType(MarkerLayer))
            .markers
            .takeWhile((marker) => marker.child is Icon)
            .map((marker) => marker.point),
        [const LatLng(7.31, 80.65), const LatLng(7.33, 80.67)],
      );
      expect(
        find.byKey(const ValueKey('journey-location-dot')),
        findsOneWidget,
      );

      await tester.tap(find.text('Second stop'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 275));
      expect(dot().latitude, greaterThan(7.29));
      expect(dot().latitude, lessThan(7.31));
      await tester.pumpAndSettle();
      expect(dot(), const LatLng(7.31, 80.65));
      expect(
        tester
            .widget<MarkerLayer>(find.byType(MarkerLayer))
            .markers
            .takeWhile((marker) => marker.child is Icon)
            .map((marker) => marker.point),
        [const LatLng(7.29, 80.63), const LatLng(7.33, 80.67)],
      );
      expect(controller.camera.center, initialCenter);
      expect(controller.camera.zoom, initialZoom);
      expect(loads, 1);
      expect(
        tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController,
        same(controller),
      );
    },
  );

  testWidgets('offscreen stops move into view without zooming in', (
    tester,
  ) async {
    await tester.pumpWidget(_SelectionHarness(onLoad: () {}));
    await tester.pumpAndSettle();
    final controller = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!;
    controller.move(const LatLng(6.9, 79.8), 12);
    await tester.pumpAndSettle();
    expect(
      controller.camera.visibleBounds.contains(const LatLng(7.31, 80.65)),
      isFalse,
    );
    await tester.tap(find.text('Second stop'));
    await tester.pumpAndSettle();
    expect(
      controller.camera.visibleBounds.contains(const LatLng(7.31, 80.65)),
      isTrue,
    );
    expect(controller.camera.zoom, lessThanOrEqualTo(12));
  });

  testWidgets(
    'selected hotel route is light red and all other roads are blue',
    (tester) async {
      final requests = <List<LatLng>>[];
      await tester.pumpWidget(
        _SelectionHarness(
          onLoad: () {},
          booking: const {
            'bookingItems': [
              {
                'itemType': 'Room',
                'hotelLatitude': 7.28,
                'hotelLongitude': 80.62,
              },
            ],
          },
          hotelRouteLoader: (points) async {
            requests.add(points);
            return ItineraryRoadRoute([], [
              points.first,
              const LatLng(7.285, 80.625),
              points.last,
            ], 1200);
          },
        ),
      );
      await tester.pumpAndSettle();
      final controller = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      final center = controller.camera.center;
      final zoom = controller.camera.zoom;
      await tester.tap(find.text('Second stop'));
      await tester.pumpAndSettle();
      final roads = tester
          .widget<PolylineLayer>(find.byType(PolylineLayer))
          .polylines;
      expect(roads.first.color, const Color(0xFF2563A6));
      expect(roads.last.color, const Color(0xFFFCA5A5));
      expect(roads.last.points, [
        const LatLng(7.28, 80.62),
        const LatLng(7.285, 80.625),
        const LatLng(7.31, 80.65),
      ]);
      expect(requests.last, [
        const LatLng(7.28, 80.62),
        const LatLng(7.31, 80.65),
      ]);
      expect(find.byIcon(Icons.hotel), findsOneWidget);
      expect(controller.camera.center, center);
      expect(controller.camera.zoom, zoom);
    },
  );

  testWidgets('selected day highlights its complete hotel and journey route', (
    tester,
  ) async {
    const dayTwo = [
      LatLng(7.29, 80.63),
      LatLng(7.31, 80.65),
      LatLng(7.33, 80.67),
    ];
    await tester.pumpWidget(
      _SelectionHarness(
        onLoad: () {},
        dayRoutes: const {
          1: [LatLng(7.29, 80.63), LatLng(7.31, 80.65)],
          2: dayTwo,
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Second stop'));
    await tester.pumpAndSettle();
    final roads = tester
        .widget<PolylineLayer>(find.byType(PolylineLayer))
        .polylines;
    expect(roads.last.points, dayTwo);
    expect(roads.last.color, const Color(0xFFFCA5A5));
    expect(roads.first.color, const Color(0xFF2563A6));
    expect(find.byIcon(Icons.navigation), findsNWidgets(2));
  });

  testWidgets(
    'hotel stop selection marks the hotel and highlights its day without a tour id',
    (tester) async {
      const hotel = LatLng(7.32, 80.66);
      const dayRoute = [LatLng(7.29, 80.63), hotel];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItineraryRoutePreview(
              itinerary: const {'items': []},
              selectedItem: const {
                'id': 'night-2',
                'dayNumber': 2,
                'stopKind': 'overnight',
                'tourName': 'Overnight at East Hotel',
                'latitude': 7.32,
                'longitude': 80.66,
                'hotelStay': {'hotelName': 'East Hotel'},
              },
              routeLoader: (_) async => const ItineraryRoadRoute(
                [
                  ItineraryRouteStop({
                    'id': 1,
                    'dayNumber': 1,
                  }, LatLng(7.29, 80.63)),
                ],
                dayRoute,
                1000,
                dayRoutes: {2: dayRoute},
                hotelPoints: [hotel],
              ),
              tileProvider: _MemoryTileProvider(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final markers = tester
          .widget<MarkerLayer>(find.byType(MarkerLayer))
          .markers;
      expect(markers.last.point, hotel);
      expect(
        tester
            .widget<PolylineLayer>(find.byType(PolylineLayer))
            .polylines
            .last
            .points,
        dayRoute,
      );
      expect(find.textContaining('GPS unavailable'), findsNothing);
      expect(find.byIcon(Icons.navigation), findsOneWidget);
    },
  );

  testWidgets(
    'legacy overnight selection routes from the final activity to its hotel',
    (tester) async {
      final requested = <List<LatLng>>[];
      const tour = LatLng(7.29, 80.63), hotel = LatLng(7.32, 80.66);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItineraryRoutePreview(
              itinerary: const {'items': []},
              selectedItem: const {
                'id': 'night-1',
                'dayNumber': 1,
                'stopKind': 'overnight',
                'latitude': 7.32,
                'longitude': 80.66,
                'hotelStay': {'hotelName': 'East Hotel'},
              },
              routeLoader: (_) async => const ItineraryRoadRoute(
                [
                  ItineraryRouteStop({'id': 1, 'dayNumber': 1}, tour),
                ],
                [tour],
                0,
              ),
              hotelRouteLoader: (points) async {
                requested.add(points);
                return ItineraryRoadRoute([], points, 1000);
              },
              tileProvider: _MemoryTileProvider(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(requested, [
        [tour, hotel],
      ]);
      expect(
        tester
            .widget<PolylineLayer>(find.byType(PolylineLayer))
            .polylines
            .last
            .points,
        [tour, hotel],
      );
      expect(find.byIcon(Icons.navigation), findsOneWidget);
    },
  );

  testWidgets('journey date selects the hotel booked for that day', (
    tester,
  ) async {
    final origins = <LatLng>[];
    await tester.pumpWidget(
      _SelectionHarness(
        onLoad: () {},
        booking: const {
          'bookingItems': [
            {
              'itemType': 'Room',
              'hotelLatitude': 7.28,
              'hotelLongitude': 80.62,
              'checkInDate': '2026-10-12',
              'checkOutDate': '2026-10-13',
            },
            {
              'itemType': 'Room',
              'hotelLatitude': 7.32,
              'hotelLongitude': 80.66,
              'checkInDate': '2026-10-13',
              'checkOutDate': '2026-10-15',
            },
          ],
        },
        hotelRouteLoader: (points) async {
          origins.add(points.first);
          return ItineraryRoadRoute([], points, 1200);
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(origins.last, const LatLng(7.28, 80.62));
    await tester.tap(find.text('Second stop'));
    await tester.pumpAndSettle();
    expect(origins.last, const LatLng(7.32, 80.66));
  });

  testWidgets(
    'visible daily route does not refocus on a different overnight hotel',
    (tester) async {
      await tester.pumpWidget(
        _SelectionHarness(
          onLoad: () {},
          booking: const {
            'bookingItems': [
              {
                'itemType': 'Room',
                'hotelLatitude': 6.4,
                'hotelLongitude': 80.0,
              },
            ],
          },
          dayRoutes: const {
            2: [LatLng(7.30, 80.64), LatLng(7.31, 80.65), LatLng(7.32, 80.66)],
          },
        ),
      );
      await tester.pumpAndSettle();
      final controller = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      controller.move(const LatLng(7.31, 80.65), 12);
      await tester.pumpAndSettle();
      final center = controller.camera.center;
      final zoom = controller.camera.zoom;
      await tester.tap(find.text('Second stop'));
      await tester.pumpAndSettle();
      expect(controller.camera.center, center);
      expect(controller.camera.zoom, zoom);
    },
  );

  testWidgets('failed hotel directions keep other roads and offer retry', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      _SelectionHarness(
        onLoad: () {},
        booking: const {
          'bookingItems': [
            {
              'itemType': 'Room',
              'hotelLatitude': 7.28,
              'hotelLongitude': 80.62,
            },
          ],
        },
        hotelRouteLoader: (points) async {
          if (++attempts == 1) throw Exception('Routing unavailable');
          return ItineraryRoadRoute([], points, 1200);
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<PolylineLayer>(find.byType(PolylineLayer)).polylines,
      hasLength(1),
    );
    await tester.tap(find.text('Hotel directions unavailable. Retry'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<PolylineLayer>(find.byType(PolylineLayer)).polylines,
      hasLength(2),
    );
    expect(find.text('Hotel directions unavailable. Retry'), findsNothing);
  });

  testWidgets('late hotel directions cannot replace the latest journey route', (
    tester,
  ) async {
    final requests = <Completer<ItineraryRoadRoute>>[];
    final endpoints = <List<LatLng>>[];
    await tester.pumpWidget(
      _SelectionHarness(
        onLoad: () {},
        booking: const {
          'bookingItems': [
            {'itemType': 1, 'hotelLatitude': 7.28, 'hotelLongitude': 80.62},
          ],
        },
        hotelRouteLoader: (points) {
          endpoints.add(points);
          final request = Completer<ItineraryRoadRoute>();
          requests.add(request);
          return request.future;
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Second stop'));
    await tester.pumpAndSettle();
    requests.last.complete(ItineraryRoadRoute([], endpoints.last, 1200));
    await tester.pumpAndSettle();
    requests.first.complete(ItineraryRoadRoute([], endpoints.first, 1200));
    await tester.pumpAndSettle();
    final roads = tester
        .widget<PolylineLayer>(find.byType(PolylineLayer))
        .polylines;
    expect(roads.last.points.last, const LatLng(7.31, 80.65));
  });

  testWidgets(
    'rapid selection switches finish at the latest scheduled occurrence',
    (tester) async {
      await tester.pumpWidget(_SelectionHarness(onLoad: () {}));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Second stop'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.tap(find.text('Third stop'));
      await tester.pumpAndSettle();
      final marker = tester
          .widget<MarkerLayer>(find.byType(MarkerLayer))
          .markers
          .last;
      expect(marker.point, const LatLng(7.33, 80.67));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a stop without GPS shows a message and preserves the selected location',
    (tester) async {
      await tester.pumpWidget(_SelectionHarness(onLoad: () {}));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Missing stop'));
      await tester.pumpAndSettle();
      expect(find.text('GPS unavailable for Missing venue.'), findsOneWidget);
      expect(
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.last.point,
        const LatLng(7.29, 80.63),
      );
    },
  );

  testWidgets(
    'preview uses 40 percent height and shows unavailable directions without a fake map',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ItineraryRoutePreview(itinerary: {'items': []})),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('no map stops'), findsOneWidget);
      expect(find.byType(FlutterMap), findsNothing);
      expect(tester.getSize(find.byType(ItineraryRoutePreview)).height, 240);
      await tester.tap(find.text('Retry directions'));
      await tester.pumpAndSettle();
      expect(find.textContaining('no map stops'), findsOneWidget);
    },
  );
}

class _SelectionHarness extends StatefulWidget {
  const _SelectionHarness({
    required this.onLoad,
    this.booking,
    this.hotelRouteLoader = ItineraryRouteService.fetchRoadRoute,
    this.dayRoutes = const {},
  });
  final VoidCallback onLoad;
  final Map<String, dynamic>? booking;
  final Future<ItineraryRoadRoute> Function(List<LatLng>) hotelRouteLoader;
  final Map<int, List<LatLng>> dayRoutes;

  @override
  State<_SelectionHarness> createState() => _SelectionHarnessState();
}

class _SelectionHarnessState extends State<_SelectionHarness> {
  Map<String, dynamic>? selected;
  static const items = [
    {'id': 1, 'tourId': 67, 'dayNumber': 1, 'sequenceOrder': 1},
    {'id': 2, 'tourId': 67, 'dayNumber': 2, 'sequenceOrder': 1},
    {'id': 3, 'tourId': 67, 'dayNumber': 3, 'sequenceOrder': 1},
    {'id': 4, 'tourId': 68, 'dayNumber': 4, 'tourName': 'Missing venue'},
  ];
  static const itinerary = {'items': items, 'startDate': '2026-10-12'};
  final tileProvider = _MemoryTileProvider();

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Column(
        children: [
          ItineraryRoutePreview(
            itinerary: itinerary,
            booking: widget.booking,
            hotelRouteLoader: widget.hotelRouteLoader,
            selectedItem: selected,
            tileProvider: tileProvider,
            routeLoader: (_) async {
              widget.onLoad();
              return ItineraryRoadRoute(
                [
                  ItineraryRouteStop(items[0], const LatLng(7.29, 80.63)),
                  ItineraryRouteStop(items[1], const LatLng(7.31, 80.65)),
                  ItineraryRouteStop(items[2], const LatLng(7.33, 80.67)),
                ],
                const [
                  LatLng(7.29, 80.63),
                  LatLng(7.31, 80.65),
                  LatLng(7.33, 80.67),
                ],
                4000,
                dayRoutes: widget.dayRoutes,
              );
            },
          ),
          for (final entry in {
            1: 'Second stop',
            2: 'Third stop',
            3: 'Missing stop',
          }.entries)
            TextButton(
              onPressed: () => setState(() => selected = items[entry.key]),
              child: Text(entry.value),
            ),
        ],
      ),
    ),
  );
}

class _MemoryTileProvider extends TileProvider {
  final image = MemoryImage(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    ),
  );

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      image;
}
