import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/services/api_service.dart';
import 'package:mobile_flutter/widgets/itinerary_change_dialog.dart';

Map<String, dynamic> options() => {
  'hotels': [
    {
      'bookingItemId': 1,
      'currentRoomId': 20,
      'hotelName': 'Current Hotel',
      'checkInDate': '2026-10-10',
      'checkOutDate': '2026-10-12',
      'options': [
        {
          'roomId': 20,
          'hotelName': 'Current Hotel',
          'roomType': 'Double',
          'distanceKm': 0,
          'total': 20000,
          'currency': 'LKR',
        },
        {
          'roomId': 21,
          'hotelName': 'Nearby Hotel',
          'roomType': 'Double',
          'distanceKm': 14.5,
          'total': 24000,
          'currency': 'LKR',
        },
      ],
    },
  ],
  'transports': [
    {
      'bookingItemId': 2,
      'currentTransportOptionId': 30,
      'routeFrom': 'Kandy',
      'routeTo': 'Ella',
      'options': [
        {
          'transportOptionId': 30,
          'provider': 'Original',
          'type': 'Van',
          'departureTime': '2026-10-12T09:00:00',
          'arrivalTime': '2026-10-12T12:00:00',
          'total': 16000,
          'currency': 'LKR',
        },
        {
          'transportOptionId': 31,
          'provider': 'Comfort Transfer',
          'type': 'Van',
          'departureTime': '2026-10-12T10:00:00',
          'arrivalTime': '2026-10-12T13:00:00',
          'total': 18000,
          'currency': 'LKR',
        },
      ],
    },
  ],
};

void main() {
  tearDown(() {
    ApiService.mockGetItineraryChangeOptions = null;
    ApiService.mockSubmitItineraryChanges = null;
  });

  testWidgets(
    'Dropdown selections send exact stay and leg IDs without requiring notes',
    (tester) async {
      Map<String, dynamic>? submitted;
      ApiService.mockGetItineraryChangeOptions = (_) async => options();
      ApiService.mockSubmitItineraryChanges = (id, body) async {
        expect(id, 42);
        submitted = body;
        return {'tripRequestId': 7};
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const ItineraryChangeDialog(itineraryId: 42),
                ),
                child: const Text('Edit'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('hotel-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Nearby Hotel').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('transport-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Comfort Transfer').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Request changes'));
      await tester.pumpAndSettle();
      expect(submitted, {
        'notes': '',
        'hotels': [
          {'bookingItemId': 1, 'roomId': 21},
        ],
        'transports': [
          {'bookingItemId': 2, 'transportOptionId': 31},
        ],
      });
      expect(find.byType(ItineraryChangeDialog), findsNothing);
    },
  );

  testWidgets(
    'Narrow dialog keeps choices after server rejection and permits retry',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      ApiService.mockGetItineraryChangeOptions = (_) async => options();
      ApiService.mockSubmitItineraryChanges = (_, _) async =>
          throw const ApiException('Selected hotel is no longer available.');
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(body: ItineraryChangeDialog(itineraryId: 42)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('change-notes')));
      await tester.enterText(
        find.byKey(const ValueKey('change-notes')),
        'Keep journeys and revise transfer',
      );
      await tester.tap(find.text('Request changes'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.text('Selected hotel is no longer available.'),
      );
      expect(
        find.text('Selected hotel is no longer available.'),
        findsOneWidget,
      );
      expect(find.text('Keep journeys and revise transfer'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
