import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
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
    ApiService.mockGetTransportPage = null;
  });

  testWidgets(
    'transport catalogue loads while private booking history is pending',
    (tester) async {
      final pending = Completer<List<dynamic>>();
      ApiService.mockGetMyBookings = () => pending.future;
      await tester.binding.setSurfaceSize(const Size(430, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(home: TransportOptionsScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Available Cars'), findsOneWidget);
      pending.completeError(const ApiException('Booking history unavailable'));
      await tester.pumpAndSettle();
      expect(find.text('Available Cars'), findsOneWidget);
      await tester.ensureVisible(find.text('Booked'));
      await tester.tap(find.text('Booked'));
      await tester.pumpAndSettle();
      expect(find.text('Booking history unavailable'), findsOneWidget);
    },
  );

  testWidgets('transport screen requests the next page only after Load more', (
    tester,
  ) async {
    final pages = <int>[];
    ApiService.mockGetTransportOptions = null;
    ApiService.mockGetTransportPage =
        ({required int page, required int pageSize, String? currency}) async {
          pages.add(page);
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': page,
                  'type': 'Van',
                  'provider': 'Provider $page',
                  'price': 5000,
                  'currency': 'LKR',
                  'capacity': 8,
                },
              ],
              'totalPages': 2042,
            }),
            200,
          );
        };
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: TransportOptionsScreen()));
    await tester.pumpAndSettle();
    expect(pages, [1]);
    await tester.ensureVisible(find.text('Load more transport'));
    await tester.tap(find.text('Load more transport'));
    await tester.pumpAndSettle();
    expect(pages, [1, 2]);
    expect(find.text('Provider 1'), findsOneWidget);
    expect(find.text('Provider 2'), findsOneWidget);
  });

  testWidgets('hotel catalogue survives unavailable booking history', (
    tester,
  ) async {
    ApiService.mockGetMyBookings = () async =>
        throw const ApiException('Booking history unavailable');
    await tester.pumpWidget(
      MaterialApp(
        home: AccommodationOptionsScreen(
          mapBuilder: (_) => const ColoredBox(color: Colors.blue),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Available Hotel'), findsWidgets);
    await tester.tap(find.text('Booked'));
    await tester.pumpAndSettle();
    expect(find.text('Booking history unavailable'), findsOneWidget);
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
