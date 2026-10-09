import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/screens/booking/booking_status_screen.dart';
import 'package:mobile_flutter/services/api_service.dart';
import 'package:mobile_flutter/services/trip_selection_service.dart';

void main() {
  tearDown(() {
    ApiService.mockGetBooking = null;
    TripSelectionService.clear();
  });

  Map<String, dynamic> booking(List<Map<String, dynamic>> items) => {
    'id': 42,
    'itineraryId': 69,
    'bookingReference': 'ST-2026-42',
    'tripTitle': 'Kandy → Ella → Arugam Bay',
    'status': 'AwaitingApproval',
    'totalCost': 129900,
    'currency': 'LKR',
    'bookingItems': items,
  };

  Map<String, dynamic> hotel(
    int id,
    String name,
    String start,
    String end,
    num price,
  ) => {
    'id': id,
    'itemType': 'Room',
    'roomId': id,
    'hotelName': name,
    'roomType': 'Double',
    'roomCapacity': 2,
    'checkInDate': '2026-10-${start}T00:00:00',
    'checkOutDate': '2026-10-${end}T00:00:00',
    'subtotal': price,
    'currency': 'LKR',
  };

  Map<String, dynamic> transport(
    int id,
    int leg,
    String from,
    String to,
    num price,
  ) => {
    'id': id,
    'itemType': 'Transport',
    'transportOptionId': id,
    'transportLegIndex': leg,
    'transportType': 'Van',
    'transportProvider': leg == 0 ? 'Airport Shuttle' : 'Private Transfer',
    'routeFrom': from,
    'routeTo': to,
    'departureTime': '2026-10-${16 + leg}T08:00:00',
    'arrivalTime': '2026-10-${16 + leg}T11:00:00',
    'quantity': 2,
    'subtotal': price,
    'currency': 'LKR',
  };

  Future<void> showBooking(
    WidgetTester tester,
    List<Map<String, dynamic>> items,
    Brightness brightness,
  ) async {
    ApiService.mockGetBooking = (_) async => booking(items);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        onGenerateRoute: (_) => MaterialPageRoute(
          settings: const RouteSettings(arguments: 42),
          builder: (_) => const BookingStatusScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'all three hotel stays and ordered transport legs show their own booking details',
    (tester) async {
      tester.view.physicalSize = const Size(400, 689);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await showBooking(tester, [
        hotel(3, 'Jetwing Surf & Safari', '20', '22', 50000),
        transport(6, 2, 'Ella', 'Arugam Bay', 13000),
        hotel(1, 'Hotel Royal Kandyan', '16', '17', 11700),
        transport(5, 1, 'Kandy', 'Ella', 16000),
        hotel(2, 'Nine Arch Holiday Resort', '17', '20', 30000),
        transport(4, 0, 'Bandaranaike International Airport', 'Kandy', 9200),
      ], Brightness.dark);

      expect(find.text('HOTEL'), findsNWidgets(3));
      expect(find.text('TRANSPORT'), findsNWidgets(3));
      final hotelNames = [
        'Hotel Royal Kandyan',
        'Nine Arch Holiday Resort',
        'Jetwing Surf & Safari',
      ];
      for (final name in hotelNames) {
        expect(find.text(name), findsOneWidget);
      }
      expect(
        tester.getTopLeft(find.text(hotelNames[0])).dy,
        lessThan(tester.getTopLeft(find.text(hotelNames[1])).dy),
      );
      expect(
        tester.getTopLeft(find.text(hotelNames[1])).dy,
        lessThan(tester.getTopLeft(find.text(hotelNames[2])).dy),
      );
      for (final dates in [
        '16 · Check-out: 2026-10-17',
        '17 · Check-out: 2026-10-20',
        '20 · Check-out: 2026-10-22',
      ]) {
        expect(find.text('Check-in: 2026-10-$dates'), findsOneWidget);
      }
      for (final price in [
        '11,700',
        '30,000',
        '50,000',
        '9,200',
        '16,000',
        '13,000',
      ]) {
        expect(find.text('LKR $price.00'), findsOneWidget);
      }
      for (var index = 1; index <= 3; index++) {
        expect(find.text('Leg $index · Van'), findsOneWidget);
      }
      expect(
        tester.getTopLeft(find.text('Leg 1 · Van')).dy,
        lessThan(tester.getTopLeft(find.text('Leg 2 · Van')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Leg 2 · Van')).dy,
        lessThan(tester.getTopLeft(find.text('Leg 3 · Van')).dy),
      );
      expect(
        find.text('Route: Bandaranaike International Airport → Kandy'),
        findsOneWidget,
      );
      expect(find.text('Route: Kandy → Ella'), findsOneWidget);
      expect(find.text('Route: Ella → Arugam Bay'), findsOneWidget);
      expect(find.text('Provider: Airport Shuttle'), findsOneWidget);
      expect(find.text('Departure: 16 Oct 2026, 08:00'), findsOneWidget);
      expect(find.text('Arrival: 18 Oct 2026, 11:00'), findsOneWidget);
      expect(find.text('Travellers: 2'), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'separate stays at the same hotel and legacy item types are preserved',
    (tester) async {
      await showBooking(tester, [
        {...hotel(1, 'Return hotel', '16', '17', 11700), 'itemType': 1},
        {...hotel(2, 'Return hotel', '20', '22', 30000), 'itemType': '1'},
        {...transport(3, 0, 'Airport', 'Kandy', 9200), 'itemType': 2},
      ], Brightness.light);
      expect(find.text('Return hotel'), findsNWidgets(2));
      expect(find.text('HOTEL'), findsNWidgets(2));
      expect(find.text('TRANSPORT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'hotel and transport details fit phone and desktop widths in both themes',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      for (final brightness in Brightness.values) {
        for (final width in [320.0, 400.0, 768.0]) {
          tester.view.physicalSize = Size(width, 689);
          await showBooking(tester, [
            hotel(1, 'Hotel Royal Kandyan', '16', '17', 11700),
            hotel(2, 'Nine Arch Holiday Resort', '17', '20', 30000),
            hotel(3, 'Jetwing Surf & Safari', '20', '22', 50000),
            transport(
              4,
              0,
              'Bandaranaike International Airport',
              'Kandy',
              9200,
            ),
            transport(5, 1, 'Kandy', 'Ella', 16000),
            transport(6, 2, 'Ella', 'Arugam Bay', 13000),
          ], brightness);
          expect(find.text('HOTEL'), findsNWidgets(3));
          expect(find.text('TRANSPORT'), findsNWidgets(3));
          expect(
            tester.takeException(),
            isNull,
            reason: '$brightness at $width pixels',
          );
        }
      }
    },
  );
}
