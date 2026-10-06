import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/screens/profile/trip_history_screen.dart';
import 'package:mobile_flutter/services/api_service.dart';

void main() {
  setUp(() {
    ApiService.mockGetMyBookings = () async => [
      {
        'id': 1,
        'bookingReference': 'CONFIRMED-1',
        'status': 'Confirmed',
        'totalCost': 120000,
        'currency': 'LKR',
        'bookingItems': [
          {
            'itemType': 'Room',
            'hotelName': 'Jetwing Kandy Gallery',
            'hotelAddress': 'Haragama, Kandy',
            'roomType': 'Deluxe Room',
            'roomCapacity': 2,
            'checkInDate': '2026-11-10T00:00:00',
            'checkOutDate': '2026-11-13T00:00:00',
            'subtotal': 90000,
            'currency': 'LKR',
          },
          {
            'itemType': 'Transport',
            'transportType': 'Train',
            'transportProvider': 'Sri Lanka Railways',
            'routeFrom': 'Colombo Fort',
            'routeTo': 'Kandy',
            'departureTime': '2026-11-10T07:00:00',
            'subtotal': 30000,
            'currency': 'LKR',
          },
        ],
      },
      {
        'id': 2,
        'bookingReference': 'COMPLETED-2',
        'status': 'Completed',
        'totalCost': 150000,
      },
      {
        'id': 3,
        'bookingReference': 'CANCELLED-3',
        'status': 'Cancelled',
        'totalCost': 90000,
      },
      {
        'id': 4,
        'bookingReference': 'REJECTED-4',
        'status': 'Rejected',
        'totalCost': 90000,
      },
    ];
    ApiService.mockGetMyTripRequests = () async => [
      {'id': 10, 'status': 'Planning', 'destinationName': 'Planning Trip'},
      {
        'id': 11,
        'status': 'AwaitingApproval',
        'destinationName': 'Approval Trip',
      },
      {'id': 12, 'status': 'Failed', 'destinationName': 'Failed Trip'},
    ];
  });

  tearDown(() {
    ApiService.mockGetMyBookings = null;
    ApiService.mockGetMyTripRequests = null;
  });

  testWidgets('history tabs show only their supported real statuses', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: TripHistoryScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Planning Trip'), findsOneWidget);
    expect(find.text('Approval Trip'), findsOneWidget);
    expect(find.text('Booking CONFIRMED-1'), findsNothing);
    expect(find.text('Failed Trip'), findsNothing);
    expect(find.text('Booking REJECTED-4'), findsNothing);

    await tester.tap(find.text('Booked'));
    await tester.pumpAndSettle();
    expect(find.text('Booking CONFIRMED-1'), findsOneWidget);
    expect(find.text('BOOKED BY THE 4 AI AGENTS'), findsOneWidget);
    expect(find.text('Jetwing Kandy Gallery'), findsOneWidget);
    expect(find.text('Deluxe Room · Up to 2 guests'), findsOneWidget);
    expect(find.text('Train · Sri Lanka Railways'), findsOneWidget);
    expect(find.text('Colombo Fort → Kandy'), findsOneWidget);

    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();
    expect(find.text('Booking COMPLETED-2'), findsOneWidget);
    expect(find.text('Planning Trip'), findsNothing);

    await tester.tap(find.text('Cancelled'));
    await tester.pumpAndSettle();
    expect(find.text('Booking CANCELLED-3'), findsOneWidget);
    expect(find.text('Booking REJECTED-4'), findsNothing);
  });

  testWidgets('booked inventory fits a narrow mobile screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: TripHistoryScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Booked'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Jetwing Kandy Gallery'), findsOneWidget);
    expect(find.text('Train · Sri Lanka Railways'), findsOneWidget);
  });
}
