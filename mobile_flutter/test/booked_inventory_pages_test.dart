import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/screens/accommodation/accommodation_options_screen.dart';
import 'package:mobile_flutter/screens/accommodation/transport_options_screen.dart';
import 'package:mobile_flutter/services/api_service.dart';

void main() {
  final bookings = <dynamic>[
    {
      'id': 10,
      'bookingReference': 'TRV-PAID-10',
      'status': 'Confirmed',
      'payments': [
        {'status': 'Paid'},
      ],
      'bookingItems': [
        {
          'id': 101,
          'itemType': 'Room',
          'hotelName': 'Earl’s Regency',
          'hotelAddress': 'Tennekumbura, Kandy',
          'hotelLatitude': 7.2821,
          'hotelLongitude': 80.6654,
          'roomType': 'Deluxe Room',
          'checkInDate': '2026-10-13T00:00:00',
          'checkOutDate': '2026-10-19T00:00:00',
          'subtotal': 120000,
          'currency': 'LKR',
        },
        {
          'id': 102,
          'itemType': 'Transport',
          'transportType': 'Train',
          'transportProvider': 'Sri Lanka Railways',
          'routeFrom': 'Colombo Fort',
          'routeTo': 'Kandy',
          'quantity': 2,
          'subtotal': 10000,
          'currency': 'LKR',
        },
      ],
    },
    {
      'id': 11,
      'bookingReference': 'TRV-UNPAID-11',
      'payments': [
        {'status': 'Pending'},
      ],
      'bookingItems': [
        {'itemType': 'Room', 'hotelName': 'Unpaid Hotel'},
        {
          'itemType': 'Transport',
          'transportType': 'Bus',
          'transportProvider': 'Unpaid Bus',
        },
      ],
    },
  ];

  setUp(() {
    ApiService.mockGetMyBookings = () async => bookings;
    ApiService.mockGetHotels = ({String? currency}) async => [
      {
        'id': 1,
        'name': 'Available Hotel',
        'address': 'Kandy',
        'latitude': 7.29,
        'longitude': 80.63,
        'rooms': [
          {'roomType': 'Standard', 'pricePerNight': 20000, 'currency': 'LKR'},
        ],
      },
    ];
    ApiService.mockGetTransportOptions = ({String? currency}) async => [
      {
        'id': 1,
        'type': 'Car',
        'provider': 'Available Cars',
        'capacity': 4,
        'routeFrom': 'Colombo',
        'routeTo': 'Kandy',
        'price': 25000,
        'currency': 'LKR',
      },
    ];
  });

  tearDown(() {
    ApiService.mockGetMyBookings = null;
    ApiService.mockGetHotels = null;
    ApiService.mockGetTransportOptions = null;
  });

  testWidgets('Accommodation Booked category shows only paid hotel items', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AccommodationOptionsScreen(
          mapBuilder: (_) => const ColoredBox(color: Colors.blue),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Booked'));
    await tester.pumpAndSettle();

    expect(find.text('1 booked stays'), findsOneWidget);
    expect(find.text('Earl’s Regency'), findsOneWidget);
    expect(find.text('Deluxe Room'), findsOneWidget);
    expect(find.textContaining('TRV-PAID-10'), findsOneWidget);
    expect(find.text('Unpaid Hotel'), findsNothing);
  });

  testWidgets('Transport Booked category shows only paid transport items', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: TransportOptionsScreen()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Booked'));
    await tester.tap(find.text('Booked'));
    await tester.pumpAndSettle();

    expect(find.text('BOOKED & PAID'), findsOneWidget);
    expect(find.text('Sri Lanka Railways'), findsOneWidget);
    expect(find.text('Colombo Fort → Kandy'), findsOneWidget);
    expect(find.text('Unpaid Bus'), findsNothing);
  });
}
