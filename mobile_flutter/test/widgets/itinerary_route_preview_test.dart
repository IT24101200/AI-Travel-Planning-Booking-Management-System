import 'dart:convert';

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
    'first stop is blue; tapping another stop animates the dot and camera without reloading directions',
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
      expect(controller.camera.center.latitude, closeTo(7.31, 0.000001));
      expect(controller.camera.center.longitude, closeTo(80.65, 0.000001));
      expect(controller.camera.zoom, closeTo(14.5, 0.000001));
      expect(loads, 1);
      expect(
        tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController,
        same(controller),
      );
    },
  );

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
  const _SelectionHarness({required this.onLoad});
  final VoidCallback onLoad;

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
  static const itinerary = {'items': items};
  final tileProvider = _MemoryTileProvider();

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Column(
        children: [
          ItineraryRoutePreview(
            itinerary: itinerary,
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
