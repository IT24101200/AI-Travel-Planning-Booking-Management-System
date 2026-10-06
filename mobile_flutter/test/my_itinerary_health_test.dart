import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/screens/tours/my_itinerary_screen.dart';
import 'package:mobile_flutter/services/api_service.dart';

void main() {
  setUp(() {
    final itinerary = <String, dynamic>{
      'id': 1,
      'tripRequestId': 10,
      'title': 'Saved journey',
      'status': 'Accepted',
      'startDate': '2026-10-12',
      'endDate': '2026-10-18',
      'totalEstimatedCost': 7500,
      'currency': 'LKR',
      'items': <Map<String, dynamic>>[],
    };
    ApiService.mockGetMyItineraries = () async => [itinerary];
    ApiService.mockGetItinerary = (_) async => itinerary;
    ApiService.mockGetTripRequest = (_) async => {
      'id': 10,
      'status': 'AwaitingApproval',
    };
  });

  tearDown(() {
    ApiService.mockGetMyItineraries = null;
    ApiService.mockGetItinerary = null;
    ApiService.mockGetTripRequest = null;
  });

  testWidgets('saved itinerary loads while the health check is pending', (
    tester,
  ) async {
    final health = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(
      MaterialApp(home: MyItineraryScreen(healthLoader: () => health.future)),
    );
    await tester.pumpAndSettle();
    expect(find.text('ACCEPTED'), findsOneWidget);
    expect(find.text('Checking agent connection…'), findsOneWidget);
    expect(find.text('Loading your itinerary...'), findsNothing);
    health.complete({'status': 'healthy'});
    await tester.pumpAndSettle();
    expect(find.text('Agentic AI started'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'health failure preserves itinerary and retry recovers independently',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MyItineraryScreen(
            healthLoader: () async {
              if (++calls == 1) {
                throw const ApiException(
                  'Gateway unavailable',
                  statusCode: 502,
                );
              }
              return {'status': 'healthy'};
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ACCEPTED'), findsOneWidget);
      expect(find.text('Agent connection unavailable'), findsOneWidget);
      expect(find.text('Agentic AI was not started'), findsNothing);
      await tester.tap(find.text('Retry agent connection'));
      await tester.pumpAndSettle();
      expect(find.text('Agentic AI started'), findsOneWidget);
      expect(calls, 2);
      expect(tester.takeException(), isNull);
    },
  );
}
