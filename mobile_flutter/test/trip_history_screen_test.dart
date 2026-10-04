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
    expect(find.text('Booking CONFIRMED-1'), findsOneWidget);
    expect(find.text('Failed Trip'), findsNothing);
    expect(find.text('Booking REJECTED-4'), findsNothing);

    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();
    expect(find.text('Booking COMPLETED-2'), findsOneWidget);
    expect(find.text('Planning Trip'), findsNothing);

    await tester.tap(find.text('Cancelled'));
    await tester.pumpAndSettle();
    expect(find.text('Booking CANCELLED-3'), findsOneWidget);
    expect(find.text('Booking REJECTED-4'), findsNothing);
  });
}
