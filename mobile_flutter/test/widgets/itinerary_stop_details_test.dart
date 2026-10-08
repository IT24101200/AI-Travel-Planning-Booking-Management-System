import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/utils/itinerary_flow_utils.dart';
import 'package:mobile_flutter/widgets/itinerary_stop_details.dart';

void main() {
  final itinerary = <String, dynamic>{
    'startDate': '2026-10-12',
    'endDate': '2026-10-14',
    'currency': 'LKR',
    'items': [
      {'id': 1, 'dayNumber': 1, 'sequenceOrder': 1, 'tourName': 'West Tour'},
      {'id': 2, 'dayNumber': 2, 'sequenceOrder': 1, 'tourName': 'East Tour'},
    ],
    'travelSchedule': [
      {
        'day_number': 2,
        'travel_legs': [
          {
            'from': {'name': 'West Hotel'},
            'to': {'name': 'East Tour'},
          },
          {
            'from': {'name': 'East Tour'},
            'to': {'name': 'East Hotel'},
          },
        ],
      },
    ],
  };
  final booking = <String, dynamic>{
    'currency': 'LKR',
    'bookingItems': [
      {
        'itemType': 1,
        'hotelName': 'West Hotel',
        'checkInDate': '2026-10-12',
        'checkOutDate': '2026-10-13',
      },
      {
        'itemType': 'Room',
        'hotelName': 'East Hotel',
        'roomType': 'Double',
        'checkInDate': '2026-10-13',
        'checkOutDate': '2026-10-14',
      },
      {
        'itemType': 2,
        'transportType': 'Van',
        'transportProvider': 'Coastal Transfers',
        'departureTime': '2026-10-13T07:00:00',
        'arrivalTime': '2026-10-13T10:00:00',
        'routeFrom': 'West',
        'routeTo': 'East',
        'subtotal': 12000,
      },
    ],
  };

  testWidgets(
    'hotel changes appear between activities and final check-out remains in trip order',
    (tester) async {
      final flow = itineraryFlowItems(itinerary, booking);
      expect(flow.map((item) => item['tourName']), [
        'West Tour',
        'Overnight at West Hotel',
        'Check out of West Hotel',
        'East Tour',
        'Overnight at East Hotel',
        'Check out of East Hotel',
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItineraryStopDetails(
              item: flow[4],
              itinerary: itinerary,
              booking: booking,
            ),
          ),
        ),
      );
      expect(find.text('Hotel stay · East Hotel'), findsOneWidget);
      expect(find.text('Room: Double'), findsOneWidget);
      expect(find.text('Van · Coastal Transfers'), findsOneWidget);
      expect(find.text('West → East'), findsOneWidget);
      expect(find.text('07:00–10:00'), findsOneWidget);
      expect(find.text('LKR 12,000 · Booked total'), findsOneWidget);
      expect(find.text('West Hotel → East Tour → East Hotel'), findsOneWidget);
    },
  );

  testWidgets(
    'days without a booked transfer do not display another day vehicle',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItineraryStopDetails(
              item: const {'id': 1, 'dayNumber': 1},
              itinerary: itinerary,
              booking: booking,
            ),
          ),
        ),
      );
      expect(
        find.textContaining('No separate transport reservation'),
        findsOneWidget,
      );
      expect(find.text('Van · Coastal Transfers'), findsNothing);
    },
  );

  testWidgets(
    'shared hotel nights remain on each day without a false check-out between destinations',
    (tester) async {
      final shared = {
        'bookingItems': [
          {
            'itemType': 'Room',
            'hotelName': 'Shared Hotel',
            'checkInDate': '2026-10-12',
            'checkOutDate': '2026-10-14',
          },
        ],
      };
      final flow = itineraryFlowItems(itinerary, shared);
      expect(
        flow
            .where((item) => item['stopKind'] == 'overnight')
            .map((item) => item['dayNumber']),
        [1, 2],
      );
      expect(
        flow
            .where((item) => item['stopKind'] == 'checkout')
            .single['dayNumber'],
        3,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItineraryStopDetails(
              item: flow[1],
              itinerary: itinerary,
              booking: shared,
            ),
          ),
        ),
      );
      expect(find.text('Hotel stay · Shared Hotel'), findsOneWidget);
    },
  );

  testWidgets(
    'planned hotel fallback is labelled planned and remains safe on narrow dark screens',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final planned = {
        ...itinerary,
        'hotelStays': [
          {
            'hotel_name': 'Planned Hotel',
            'check_in': '2026-10-12',
            'check_out': '2026-10-14',
            'room_id': 5,
          },
        ],
      };
      final flow = itineraryFlowItems(planned, null);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: ItineraryStopDetails(item: flow[1], itinerary: planned),
            ),
          ),
        ),
      );
      expect(find.text('Planned stay · Planned Hotel'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
