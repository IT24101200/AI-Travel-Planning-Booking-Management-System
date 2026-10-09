import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/screens/booking/trip_confirmation_screen.dart';
import 'package:mobile_flutter/screens/profile/notifications_screen.dart';
import 'package:mobile_flutter/services/api_service.dart';
import 'package:mobile_flutter/widgets/trip_confirmation_details.dart';

Map<String, dynamic> tripDetails() => {
  'bookingReference': 'ST-PAID-42',
  'startDate': '2026-10-16',
  'endDate': '2026-10-18',
  'travellers': 2,
  'amountPaid': 25000,
  'currency': 'LKR',
  'hotels': [
    {
      'name': 'Kandy booked hotel',
      'address': 'Lake Road, Kandy',
      'roomType': 'Deluxe double',
      'rooms': 1,
      'checkInDate': '2026-10-16',
      'checkOutDate': '2026-10-17',
      'contactPhone': '+94 11 555 0100',
      'contactEmail': 'hotel@example.test',
    },
    {
      'name': 'Ella booked hotel',
      'rooms': 1,
      'checkInDate': '2026-10-17',
      'checkOutDate': '2026-10-18',
    },
  ],
  'transports': [
    {
      'type': 'Car',
      'provider': 'Booked operator',
      'from': 'Airport',
      'to': 'Kandy',
      'departureTime': '2026-10-16T08:00:00',
      'arrivalTime': '2026-10-16T11:00:00',
      'travellers': 2,
      'contactPhone': '+94 77 555 0100',
      'contactEmail': 'operator@example.test',
    },
    {
      'type': 'Van',
      'provider': 'Second operator',
      'from': 'Kandy',
      'to': 'Ella',
      'departureTime': '2026-10-17T08:00:00',
      'arrivalTime': '2026-10-17T12:00:00',
      'travellers': 2,
    },
  ],
  'days': [
    for (var day = 1; day <= 3; day++)
      {
        'dayNumber': day,
        'date': '2026-10-${day + 15}',
        'stops': [
          for (var stop = 1; stop <= 6; stop++)
            {
              'kind': 'Journey',
              'name': 'Day $day planned activity $stop',
              'startTime': '${stop + 10}:00',
              'endTime': '${stop + 11}:00',
            },
        ],
        'routes': [
          {
            'from': 'Hotel',
            'to': 'Attraction',
            'distanceKm': 12,
            'travelMinutes': 30,
          },
        ],
      },
  ],
};

void main() {
  testWidgets(
    'all booked stays, legs, contacts and days fit supported themes',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      tester.view.devicePixelRatio = 1;
      for (final brightness in Brightness.values) {
        for (final width in [280.0, 320.0, 390.0, 768.0]) {
          tester.view.physicalSize = Size(width, 800);
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(brightness: brightness),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: TripConfirmationDetails(details: tripDetails()),
                ),
              ),
            ),
          );
          expect(find.text('Kandy booked hotel'), findsOneWidget);
          expect(find.text('Ella booked hotel'), findsOneWidget);
          expect(find.text('Phone: +94 77 555 0100'), findsOneWidget);
          expect(find.text('Email: hotel@example.test'), findsOneWidget);
          expect(
            find.textContaining('Not provided — contact the travel desk'),
            findsWidgets,
          );
          expect(find.text('Kandy → Ella'), findsOneWidget);
          expect(find.text('Departure: 16 Oct, 08:00'), findsOneWidget);
          expect(
            find.textContaining('Day 3 planned activity 6'),
            findsOneWidget,
          );
          expect(
            find.text('Hotel → Attraction · 12 km · 30 min'),
            findsNWidgets(3),
          );
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets(
    'payment notification opens its complete scrollable confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(() {
        ApiService.mockGetMyNotifications = null;
        ApiService.mockMarkNotificationRead = null;
      });
      var markedRead = false;
      ApiService.mockMarkNotificationRead = (_) async => markedRead = true;
      ApiService.mockGetMyNotifications = () async => [
        {
          'id': 'paid-notification',
          'messageType': 'PaymentSucceeded',
          'channel': 'InApp',
          'status': 'Sent',
          'content':
              'Your payment was successful. Your complete trip is attached.',
          'referenceType': 'Booking',
          'referenceId': '42',
          'tripDetails': tripDetails(),
          'sentAt': '2026-10-09T01:00:00Z',
        },
      ];
      await tester.pumpWidget(const MaterialApp(home: NotificationsScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Payment Successful'));
      await tester.pumpAndSettle();
      expect(markedRead, isTrue);
      expect(find.byType(TripConfirmationDetails), findsOneWidget);
      expect(find.text('Phone: +94 11 555 0100'), findsOneWidget);
      expect(find.text('Email: operator@example.test'), findsOneWidget);
      expect(find.textContaining('Day 3 planned activity 6'), findsOneWidget);
      await tester.ensureVisible(find.text('View Booking'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Close'));
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(TripConfirmationDetails), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('paid checkout confirmation includes the plan and contacts', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (_) => MaterialPageRoute(
          settings: RouteSettings(
            arguments: {
              'status': 'Confirmed',
              'paymentStatus': 'Paid',
              'bookingReference': 'ST-PAID-42',
              'totalCost': 25000,
              'currency': 'LKR',
              'tripDetails': tripDetails(),
            },
          ),
          builder: (_) => const TripConfirmationScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TripConfirmationDetails), findsOneWidget);
    expect(find.text('Email: operator@example.test'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
