import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_flutter/services/itinerary_route_service.dart';

void main() {
  test('orders stops by itinerary day and sequence instead of city names', () {
    final items = ItineraryRouteService.orderedItems({
      'items': [
        {'tourId': 3, 'dayNumber': 2, 'sequenceOrder': 0},
        {'tourId': 2, 'dayNumber': 1, 'sequenceOrder': 1},
        {'tourId': 1, 'dayNumber': 1, 'sequenceOrder': 0},
      ],
    });
    expect(items.map((item) => item['tourId']), [1, 2, 3]);
  });

  test('missing and invalid GPS data does not become a guessed city', () {
    expect(ItineraryRouteService.coordinates({'tourName': 'Kandy'}), isNull);
    expect(
      ItineraryRouteService.coordinates({'latitude': 0, 'longitude': 0}),
      isNull,
    );
    expect(
      ItineraryRouteService.coordinates({'latitude': 91, 'longitude': 80}),
      isNull,
    );
    expect(
      ItineraryRouteService.coordinates({'latitude': 7.29, 'longitude': 80.63}),
      const LatLng(7.29, 80.63),
    );
  });

  test(
    'uses full road geometry and converts GeoJSON longitude latitude order',
    () async {
      final client = MockClient((request) async {
        expect(
          request.url.path,
          contains('/route/v1/driving/80.63,7.29;80.64,7.3'),
        );
        expect(request.url.queryParameters['overview'], 'full');
        return http.Response(
          jsonEncode({
            'code': 'Ok',
            'routes': [
              {
                'distance': 1800,
                'geometry': {
                  'coordinates': [
                    [80.63, 7.29],
                    [80.635, 7.295],
                    [80.64, 7.3],
                  ],
                },
              },
            ],
          }),
          200,
        );
      });
      final route = await ItineraryRouteService.fetchRoadRoute([
        const LatLng(7.29, 80.63),
        const LatLng(7.3, 80.64),
      ], client: client);
      expect(route.points, [
        const LatLng(7.29, 80.63),
        const LatLng(7.295, 80.635),
        const LatLng(7.3, 80.64),
      ]);
      expect(route.distanceMeters, 1800);
      client.close();
    },
  );

  test('routing failure never falls back to a straight line', () async {
    final client = MockClient(
      (_) async => http.Response('{"code":"NoRoute"}', 200),
    );
    await expectLater(
      ItineraryRouteService.fetchRoadRoute([
        const LatLng(7.29, 80.63),
        const LatLng(7.3, 80.64),
      ], client: client),
      throwsA(isA<Exception>()),
    );
    client.close();
  });
}
