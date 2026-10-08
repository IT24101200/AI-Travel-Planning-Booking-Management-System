import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_flutter/services/itinerary_route_service.dart';

void main() {
  test('daily road routes retain airport, tours and changing hotels', () async {
    Map<String, dynamic> endpoint(double lon, String kind) => {
      'latitude': 7.5,
      'longitude': lon,
      'kind': kind,
    };
    final airport = endpoint(79.9, 'airport');
    final hotel1 = endpoint(80.1, 'hotel');
    final tour = endpoint(80.2, 'tour');
    final hotel2 = endpoint(80.3, 'hotel');
    final requests = <String>[];
    final client = MockClient((request) async {
      final coordinates = request.url.path.split('/').last;
      requests.add(coordinates);
      return http.Response(
        jsonEncode({
          'code': 'Ok',
          'routes': [
            {
              'distance': 1000,
              'geometry': {
                'coordinates': coordinates
                    .split(';')
                    .map((pair) => pair.split(',').map(double.parse).toList())
                    .toList(),
              },
            },
          ],
        }),
        200,
      );
    });
    final route = await ItineraryRouteService.load({
      'items': [
        {'tourId': 1, 'dayNumber': 2, ...tour},
      ],
      'travelSchedule': [
        {
          'day_number': 1,
          'travel_legs': [
            {'from': airport, 'to': hotel1},
          ],
        },
        {
          'day_number': 2,
          'travel_legs': [
            {'from': hotel1, 'to': tour},
            {'from': tour, 'to': hotel2},
          ],
        },
      ],
    }, client: client);
    expect(requests, ['79.9,7.5;80.1,7.5', '80.1,7.5;80.2,7.5;80.3,7.5']);
    expect(route.dayRoutes[2], [
      const LatLng(7.5, 80.1),
      const LatLng(7.5, 80.2),
      const LatLng(7.5, 80.3),
    ]);
    expect(route.hotelPoints, [
      const LatLng(7.5, 80.1),
      const LatLng(7.5, 80.3),
    ]);
    expect(route.airportPoints, [const LatLng(7.5, 79.9)]);
    expect(route.distanceMeters, 2000);
    client.close();
  });

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
