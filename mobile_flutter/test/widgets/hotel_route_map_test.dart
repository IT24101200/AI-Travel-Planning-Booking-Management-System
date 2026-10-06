import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_flutter/services/itinerary_route_service.dart';
import 'package:mobile_flutter/services/trip_selection_service.dart';
import 'package:mobile_flutter/widgets/hotel_route_map.dart';

const _hotel = {
  'id': 24,
  'name': 'Galle property',
  'latitude': 6.05,
  'longitude': 80.21,
};
const _origin = LatLng(6.08, 80.24);
ItineraryRoadRoute _route(List<LatLng> stops) => ItineraryRoadRoute([], [
  stops.first,
  const LatLng(6.07, 80.22),
  stops.last,
], 12340);

Widget _host(HotelRouteMap map) => MaterialApp(
  home: Scaffold(
    body: Center(child: SizedBox(width: 600, height: 400, child: map)),
  ),
);

void main() {
  setUp(TripSelectionService.reset);

  testWidgets('GPS start draws light blue road geometry and map can pan', (
    tester,
  ) async {
    List<LatLng>? requested;
    await tester.pumpWidget(
      _host(
        HotelRouteMap(
          hotel: _hotel,
          tileProvider: _Tiles(),
          locationLoader: () async => _origin,
          routeLoader: (points) async {
            requested = points;
            return _route(points);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('My location'));
    await tester.pumpAndSettle();
    expect(requested, [_origin, const LatLng(6.05, 80.21)]);
    final line = tester
        .widget<PolylineLayer>(find.byType(PolylineLayer))
        .polylines
        .single;
    expect(line.color, HotelRouteMap.routeColor);
    expect(line.points.length, 3);
    expect(find.byKey(const ValueKey('hotel-origin-dot')), findsOneWidget);
    final map = find.byType(FlutterMap);
    final controller = tester.widget<FlutterMap>(map).mapController!;
    final before = controller.camera.center;
    await tester.drag(map, const Offset(70, 20));
    await tester.pumpAndSettle();
    expect(controller.camera.center, isNot(before));
    expect(tester.takeException(), isNull);
  });

  testWidgets('denied GPS still allows a start picked on the map', (
    tester,
  ) async {
    List<LatLng>? requested;
    await tester.pumpWidget(
      _host(
        HotelRouteMap(
          hotel: _hotel,
          tileProvider: _Tiles(),
          locationLoader: () async => throw Exception('Permission declined'),
          routeLoader: (points) async {
            requested = points;
            return _route(points);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('My location'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Permission declined'), findsOneWidget);
    await tester.tap(find.text('Pick on map'));
    await tester.pumpAndSettle();
    await tester.tapAt(
      tester.getCenter(find.byType(FlutterMap)) + const Offset(70, 30),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(requested, isNotNull);
    expect(requested!.last, const LatLng(6.05, 80.21));
    expect(find.byType(PolylineLayer), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('airport selection wins over an older pending route', (
    tester,
  ) async {
    final pending = Completer<ItineraryRoadRoute>();
    var calls = 0;
    await tester.pumpWidget(
      _host(
        HotelRouteMap(
          hotel: _hotel,
          tileProvider: _Tiles(),
          locationLoader: () async => _origin,
          routeLoader: (points) async =>
              ++calls == 1 ? pending.future : _route(points),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('My location'));
    await tester.pump();
    await tester.tap(find.text('Airport'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Bandaranaike (CMB)'));
    await tester.pump(const Duration(milliseconds: 350));
    pending.complete(_route([_origin, const LatLng(6.05, 80.21)]));
    await tester.pumpAndSettle();
    final route = tester
        .widget<PolylineLayer>(find.byType(PolylineLayer))
        .polylines
        .single;
    expect(route.points.first, const LatLng(7.1802, 79.8842));
    expect(
      TripSelectionService.hotelDirectionsOrigin,
      const LatLng(7.1802, 79.8842),
    );
  });

  testWidgets(
    'changing hotel recalculates directions from the retained start',
    (tester) async {
      var hotel = Map<String, dynamic>.from(_hotel);
      final calls = <List<LatLng>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Column(
                children: [
                  SizedBox(
                    width: 600,
                    height: 400,
                    child: HotelRouteMap(
                      hotel: hotel,
                      tileProvider: _Tiles(),
                      locationLoader: () async => _origin,
                      routeLoader: (points) async {
                        calls.add(points);
                        return _route(points);
                      },
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(
                      () => hotel = {
                        'id': 25,
                        'name': 'Other property',
                        'latitude': 6.04,
                        'longitude': 80.19,
                      },
                    ),
                    child: const Text('Other hotel'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('My location'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other hotel'));
      await tester.pumpAndSettle();
      expect(calls.last, [_origin, const LatLng(6.04, 80.19)]);
      expect(calls.length, 2);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Tiles extends TileProvider {
  final _image = MemoryImage(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    ),
  );
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      _image;
}
