import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/screens/tours/my_itinerary_screen.dart';
import 'package:mobile_flutter/services/api_service.dart';
import 'package:mobile_flutter/services/trip_selection_service.dart';
import 'package:mobile_flutter/widgets/itinerary_route_preview.dart';

void main() {
  setUp(() {
    TripSelectionService.clear();
    ApiService.mockGetAgentHealth = () async => {'status': 'healthy'};
    ApiService.mockGetAgentLogs = (_) async => [];
    ApiService.mockStreamAgentLogs = (_) =>
        const Stream<AgentLogStreamEvent>.empty();
    ApiService.mockGetTripRequest = (_) async => {
      'id': 10,
      'status': 'Planned',
    };
    ApiService.mockGetMyBookings = () async => [];
    ApiService.mockGetMyTripRequests = () async => [];
    ApiService.mockGetTour = (_) async => {
      'latitude': 7.29,
      'longitude': 80.63,
    };
  });

  tearDown(() {
    TripSelectionService.clear();
    ApiService.mockGetMyItineraries = null;
    ApiService.mockGetItinerary = null;
    ApiService.mockAcceptItinerary = null;
    ApiService.mockRequestItineraryChanges = null;
    ApiService.mockGetItineraryChangeOptions = null;
    ApiService.mockSubmitItineraryChanges = null;
    ApiService.mockCancelTripRequest = null;
    ApiService.mockGetAgentHealth = null;
    ApiService.mockGetAgentLogs = null;
    ApiService.mockStreamAgentLogs = null;
    ApiService.mockGetTripRequest = null;
    ApiService.mockGetMyBookings = null;
    ApiService.mockGetMyTripRequests = null;
    ApiService.mockGetTour = null;
  });

  Widget buildTestWidget({
    Map<String, WidgetBuilder>? routes,
    DateTime Function()? nowProvider,
  }) {
    return MaterialApp(
      routes: routes ?? const {},
      home: MyItineraryScreen(
        nowProvider: nowProvider ?? () => DateTime(2026, 10, 6),
      ),
    );
  }

  Map<String, dynamic> createSampleItinerary({
    int id = 1,
    dynamic status = 1, // 0: Draft, 1: Proposed, 2: Accepted, 3: Discarded
    num totalCost = 7500,
  }) {
    return {
      'id': id,
      'customerId': 'cust-123',
      'tripRequestId': 10,
      'startDate': '2026-10-12T00:00:00',
      'endDate': '2026-10-18T00:00:00',
      'status': status,
      'totalEstimatedCost': totalCost,
      'currency': 'LKR',
      'items': [
        {
          'id': 101,
          'tourId': 4,
          'tourName': 'Sigiriya Rock Fortress',
          'dayNumber': 1,
          'sequenceOrder': 1,
          'startTime': '08:30:00',
          'endTime': '12:00:00',
          'priceAtSelection': 4500,
        },
        {
          'id': 102,
          'tourId': 7,
          'tourName': 'Temple of the Tooth',
          'dayNumber': 2,
          'sequenceOrder': 1,
          'startTime': '09:00:00',
          'endTime': '11:30:00',
          'priceAtSelection': 3000,
        },
      ],
    };
  }

  Future<void> scrollJourneyToBottom(WidgetTester tester) async {
    final journey = find.byKey(const ValueKey('journey-scroll'));
    expect(journey, findsOneWidget);
    for (var attempt = 0; attempt < 4; attempt++) {
      await tester.fling(journey, const Offset(0, -1000), 1000);
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  testWidgets(
    'planned transfer days and every dated hotel stay are displayed',
    (tester) async {
      final itinerary = createSampleItinerary();
      ApiService.mockGetMyItineraries = () async => [itinerary];
      ApiService.mockGetItinerary = (_) async => itinerary;
      const endpoint = {
        'name': 'East Hotel',
        'kind': 'hotel',
        'latitude': 7.29,
        'longitude': 80.63,
      };
      ApiService.mockGetTripRequest = (_) async => {
        'id': 10,
        'status': 'Planned',
        'planJson': jsonEncode({
          'itinerary': {
            'schedule': [
              {
                'day_number': 1,
                'items': [
                  {'tour_id': 4},
                ],
                'travel_legs': [],
                'travel_distance_km': 10,
                'travel_minutes': 30,
              },
              {
                'day_number': 2,
                'items': [
                  {'tour_id': 7},
                ],
                'travel_legs': [],
                'travel_distance_km': 20,
                'travel_minutes': 45,
              },
              {
                'day_number': 3,
                'items': [],
                'travel_legs': [
                  {'from': endpoint, 'to': endpoint},
                ],
                'travel_distance_km': 120,
                'travel_minutes': 180,
              },
            ],
          },
        }),
      };
      ApiService.mockGetMyBookings = () async => [
        {
          'id': 5,
          'itineraryId': 1,
          'tripRequestId': 10,
          'currency': 'LKR',
          'bookingItems': [
            {
              'itemType': 'Room',
              'hotelName': 'West Hotel',
              'checkInDate': '2026-10-12',
              'checkOutDate': '2026-10-14',
              'subtotal': 2000,
            },
            {
              'itemType': 'Room',
              'hotelName': 'East Hotel',
              'checkInDate': '2026-10-14',
              'checkOutDate': '2026-10-18',
              'subtotal': 4000,
            },
            {
              'itemType': 'Transport',
              'transportType': 'Van',
              'transportProvider': 'Island Transfers',
              'departureTime': '2026-10-14T08:00:00',
              'arrivalTime': '2026-10-14T11:00:00',
              'routeFrom': 'West',
              'routeTo': 'East',
              'subtotal': 6000,
            },
          ],
        },
      ];
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Travel to East Hotel'),
        180,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('journey-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('Travel to East Hotel'), findsOneWidget);
      await tester.tap(find.text('Travel to East Hotel'));
      await tester.pumpAndSettle();
      expect(find.text('Van · Island Transfers'), findsOneWidget);
      expect(
        tester
            .widget<ItineraryRoutePreview>(find.byType(ItineraryRoutePreview))
            .selectedItem?['dayNumber'],
        3,
      );
      expect(
        find.textContaining('Hotel transfer · Day travel: 120 km, 180 min'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('West Hotel'),
        200,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('journey-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('West Hotel'), findsOneWidget);
      expect(find.text('East Hotel'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('1. Loading state displays indicator and loading text', (
    WidgetTester tester,
  ) async {
    final completer = Completer<List<dynamic>>();
    ApiService.mockGetMyItineraries = () => completer.future;

    await tester.pumpWidget(buildTestWidget());
    await tester.pump(); // Trigger initial frame

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading your itinerary...'), findsOneWidget);

    completer.complete([]);
    await tester.pumpAndSettle();
  });

  testWidgets(
    '2. Empty state displays No itinerary yet and Explore Tours button',
    (WidgetTester tester) async {
      ApiService.mockGetMyItineraries = () async => [];

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('No itinerary yet'), findsOneWidget);
      expect(find.text('Explore Tours'), findsOneWidget);
    },
  );

  testWidgets('3. Error state displays retry button and error message', (
    WidgetTester tester,
  ) async {
    ApiService.mockGetMyItineraries = () async =>
        throw Exception('Network timeout');

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Unable to load itinerary'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets(
    '4. Real data renders timeline items, total, and prices in LKR (no \$)',
    (WidgetTester tester) async {
      final itinerary = createSampleItinerary(status: 1);
      ApiService.mockGetMyItineraries = () async => [itinerary];
      ApiService.mockGetItinerary = (id) async => itinerary;

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Verify timeline items rendered
      expect(find.text('Sigiriya Rock Fortress'), findsOneWidget);
      expect(find.text('Temple of the Tooth'), findsOneWidget);
      expect(find.text('DAY 1'), findsOneWidget);
      expect(find.text('DAY 2'), findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey('journey-scroll')),
        const Offset(0, -1000),
      );
      await tester.pumpAndSettle();

      // Verify LKR formatted prices
      expect(find.text('LKR 7,500'), findsNWidgets(3));
      expect(find.text('PROPOSED'), findsOneWidget);

      // Verify NO $ symbol is displayed anywhere on screen
      expect(find.textContaining(r'$'), findsNothing);
    },
  );

  testWidgets(
    '5a. Button visibility: Proposed status shows Accept & Request Changes, hides Checkout',
    (WidgetTester tester) async {
      final itinerary = createSampleItinerary(status: 1); // Proposed
      ApiService.mockGetMyItineraries = () async => [itinerary];
      ApiService.mockGetItinerary = (id) async => itinerary;

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      await scrollJourneyToBottom(tester);
      await tester.ensureVisible(find.text('Accept Itinerary'));
      expect(find.text('Accept Itinerary'), findsOneWidget);
      expect(find.text('Request Changes'), findsOneWidget);
      expect(find.text('Continue to Checkout'), findsNothing);
    },
  );

  testWidgets(
    '5b. Button visibility: Draft status shows Request Changes, hides Accept & Checkout',
    (WidgetTester tester) async {
      final itinerary = createSampleItinerary(status: 0); // Draft
      ApiService.mockGetMyItineraries = () async => [itinerary];
      ApiService.mockGetItinerary = (id) async => itinerary;

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      await scrollJourneyToBottom(tester);
      await tester.ensureVisible(find.text('Request Changes'));
      expect(find.text('Request Changes'), findsOneWidget);
      expect(find.text('Accept Itinerary'), findsNothing);
      expect(find.text('Continue to Checkout'), findsNothing);
    },
  );

  testWidgets(
    '5c. Button visibility: Accepted status shows Continue to Checkout, hides Accept & Request Changes',
    (WidgetTester tester) async {
      final itinerary = createSampleItinerary(status: 2); // Accepted
      ApiService.mockGetMyItineraries = () async => [itinerary];
      ApiService.mockGetItinerary = (id) async => itinerary;

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      await scrollJourneyToBottom(tester);
      await tester.ensureVisible(find.text('Continue to Checkout'));
      expect(find.text('Continue to Checkout'), findsOneWidget);
      expect(find.text('Accept Itinerary'), findsNothing);
      expect(find.text('Request Changes'), findsNothing);
    },
  );

  testWidgets(
    '5e. Checkout receives the booking matched to the selected itinerary',
    (tester) async {
      final itinerary = createSampleItinerary(id: 42, status: 2);
      Object? checkoutArgument;
      ApiService.mockGetMyItineraries = () async => [itinerary];
      ApiService.mockGetItinerary = (_) async => itinerary;
      ApiService.mockGetMyBookings = () async => [
        {'id': 999, 'itineraryId': 7},
        {'id': 901, 'itineraryId': 42},
      ];
      TripSelectionService.setActiveBookingContext(
        itineraryId: 7,
        bookingId: 999,
      );

      await tester.pumpWidget(
        buildTestWidget(
          routes: {
            '/checkout': (context) {
              checkoutArgument = ModalRoute.of(context)?.settings.arguments;
              return const Scaffold(body: Text('Mock Checkout'));
            },
          },
        ),
      );
      await tester.pumpAndSettle();
      await scrollJourneyToBottom(tester);
      final checkoutButton = find.text('Continue to Checkout');
      await tester.ensureVisible(checkoutButton);
      await tester.tap(checkoutButton);
      await tester.pumpAndSettle();

      expect(checkoutArgument, equals(901));
      expect(find.text('Mock Checkout'), findsOneWidget);
    },
  );

  testWidgets(
    '5d. Button visibility: Discarded status hides all action buttons and shows notice',
    (WidgetTester tester) async {
      final itinerary = createSampleItinerary(status: 3); // Discarded
      ApiService.mockGetMyItineraries = () async => [itinerary];
      ApiService.mockGetItinerary = (id) async => itinerary;

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      await scrollJourneyToBottom(tester);
      expect(find.text('Accept Itinerary'), findsNothing);
      expect(find.text('Request Changes'), findsNothing);
      expect(find.text('Continue to Checkout'), findsNothing);
      expect(
        find.text('This itinerary proposal was discarded.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('6. Accept Itinerary invokes accept API', (
    WidgetTester tester,
  ) async {
    final itinerary = createSampleItinerary(id: 42, status: 1); // Proposed
    int? acceptedId;

    ApiService.mockGetMyItineraries = () async => [itinerary];
    ApiService.mockGetItinerary = (id) async => itinerary;
    ApiService.mockAcceptItinerary = (id) async {
      acceptedId = id;
      return true;
    };

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();
    await scrollJourneyToBottom(tester);
    final acceptBtnFinder = find.text('Accept Itinerary');
    await tester.ensureVisible(acceptBtnFinder);
    await tester.tap(acceptBtnFinder);
    await tester.pump();

    expect(acceptedId, equals(42));
  });

  testWidgets(
    '6a. Cancel trip requires confirmation and refreshes cancelled state',
    (WidgetTester tester) async {
      final itinerary = createSampleItinerary(id: 42, status: 1);
      var tripStatus = 'Planning';
      int? cancelledId;
      ApiService.mockGetMyItineraries = () async => [itinerary];
      ApiService.mockGetItinerary = (_) async => itinerary;
      ApiService.mockGetTripRequest = (_) async => {
        'id': 10,
        'status': tripStatus,
      };
      ApiService.mockCancelTripRequest = (id) async {
        cancelledId = id;
        tripStatus = 'Cancelled';
        return {
          'status': 'Cancelled',
          'message': 'Your trip has been cancelled.',
        };
      };

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await scrollJourneyToBottom(tester);
      await tester.tap(find.text('Cancel trip'));
      await tester.pumpAndSettle();
      expect(find.text('Cancel trip'), findsNWidgets(2));
      expect(
        find.textContaining('Are you sure you want to cancel this trip?'),
        findsOneWidget,
      );

      await tester.tap(find.text('Keep trip'));
      await tester.pumpAndSettle();
      expect(cancelledId, isNull);

      await tester.tap(find.text('Cancel trip'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel trip').last);
      await tester.pumpAndSettle();

      expect(cancelledId, 10);
      expect(
        find.text('Cancelled. This trip is no longer actionable.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('6b. Cancel trip is available for an approved unpaid trip', (
    WidgetTester tester,
  ) async {
    final itinerary = createSampleItinerary(id: 42, status: 2);
    ApiService.mockGetMyItineraries = () async => [itinerary];
    ApiService.mockGetItinerary = (_) async => itinerary;
    ApiService.mockGetTripRequest = (_) async => {
      'id': 10,
      'status': 'Approved',
    };

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();
    await scrollJourneyToBottom(tester);

    expect(find.text('Cancel trip'), findsOneWidget);
  });

  testWidgets('6c. Cancel trip is hidden inside the three-day cutoff', (
    WidgetTester tester,
  ) async {
    final itinerary = createSampleItinerary(id: 42, status: 2);
    ApiService.mockGetMyItineraries = () async => [itinerary];
    ApiService.mockGetItinerary = (_) async => itinerary;
    ApiService.mockGetTripRequest = (_) async => {
      'id': 10,
      'status': 'Approved',
    };

    await tester.pumpWidget(
      buildTestWidget(nowProvider: () => DateTime(2026, 10, 10)),
    );
    await tester.pumpAndSettle();
    await scrollJourneyToBottom(tester);

    expect(find.text('Cancel trip'), findsNothing);
  });

  testWidgets(
    '6d. Cancel trip is available exactly three days before departure',
    (WidgetTester tester) async {
      final itinerary = createSampleItinerary(id: 42, status: 1);
      ApiService.mockGetMyItineraries = () async => [itinerary];
      ApiService.mockGetItinerary = (_) async => itinerary;
      ApiService.mockGetTripRequest = (_) async => {
        'id': 10,
        'status': 'AwaitingApproval',
      };

      await tester.pumpWidget(
        buildTestWidget(nowProvider: () => DateTime(2026, 10, 9)),
      );
      await tester.pumpAndSettle();
      await scrollJourneyToBottom(tester);

      expect(find.text('Cancel trip'), findsOneWidget);
      expect(
        find.text('Cancellation is available until 3 days before departure.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('6e. Cancellation failure keeps the existing itinerary state', (
    WidgetTester tester,
  ) async {
    final itinerary = createSampleItinerary(id: 42, status: 1);
    ApiService.mockGetMyItineraries = () async => [itinerary];
    ApiService.mockGetItinerary = (_) async => itinerary;
    ApiService.mockCancelTripRequest = (_) async =>
        throw const ApiException('This trip can no longer be cancelled.');

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();
    await scrollJourneyToBottom(tester);
    await tester.tap(find.text('Cancel trip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel trip').last);
    await tester.pumpAndSettle();

    expect(find.text('This trip can no longer be cancelled.'), findsOneWidget);
    expect(find.text('Accept Itinerary'), findsOneWidget);
  });

  testWidgets(
    '7. Request Changes validates choices or instructions and starts replanning',
    (WidgetTester tester) async {
      final itinerary = createSampleItinerary(id: 42, status: 1); // Proposed
      String? submittedComment;

      ApiService.mockGetMyItineraries = () async => [itinerary];
      ApiService.mockGetItinerary = (id) async => itinerary;
      ApiService.mockGetItineraryChangeOptions = (_) async => {
        'hotels': [],
        'transports': [],
      };
      ApiService.mockSubmitItineraryChanges = (id, request) async {
        submittedComment = request['notes'] as String;
        return {'tripRequestId': 10, 'status': 'Planning'};
      };

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Open Request Changes dialog via Edit link or button
      final editFinder = find.text('Edit');
      await tester.ensureVisible(editFinder);
      await tester.tap(editFinder);
      await tester.pumpAndSettle();

      // Verify dialog opened
      expect(find.text('Request itinerary changes'), findsOneWidget);

      // Try submitting empty comment
      await tester.tap(find.text('Request changes'));
      await tester.pumpAndSettle();

      // Validation error should appear
      expect(
        find.text('Select an alternative or enter instructions.'),
        findsOneWidget,
      );
      expect(submittedComment, isNull);

      // Enter comment and submit
      await tester.enterText(
        find.byKey(const ValueKey('change-notes')),
        'Prefer the selected quiet hotel',
      );
      await tester.tap(find.text('Request changes'));
      await tester.pump();

      expect(submittedComment, equals('Prefer the selected quiet hotel'));
    },
  );

  testWidgets(
    'Agent completion opens revised itinerary and its matching booking',
    (tester) async {
      final events = StreamController<AgentLogStreamEvent>.broadcast();
      var revised = false;
      final original = createSampleItinerary(id: 42, status: 1);
      final updated = createSampleItinerary(id: 43, status: 1);
      ApiService.mockGetMyItineraries = () async =>
          revised ? [original, updated] : [original];
      ApiService.mockGetItinerary = (id) async => id == 43 ? updated : original;
      ApiService.mockGetMyBookings = () async => [
        {
          'id': revised ? 101 : 100,
          'itineraryId': revised ? 43 : 42,
          'tripRequestId': 10,
          'bookingItems': [],
        },
      ];
      ApiService.mockGetTripRequest = (_) async => {
        'id': 10,
        'status': revised ? 'AwaitingApproval' : 'Planned',
        if (!revised) 'failureReason': 'Previous change request failed.',
      };
      ApiService.mockGetAgentLogs = (_) async => [
        for (final agent in [
          'CoordinatorAgent',
          'ItineraryAgent',
          'BookingAgent',
          'ValidationAgent',
        ])
          {
            'agentName': agent,
            'status': 'Failed',
            'output': 'Old internal diagnostics',
          },
      ];
      ApiService.mockStreamAgentLogs = (_) => events.stream;
      ApiService.mockGetItineraryChangeOptions = (_) async => {
        'hotels': [],
        'transports': [],
      };
      ApiService.mockSubmitItineraryChanges = (_, _) async => {
        'tripRequestId': 10,
      };
      Future<void> revealAgentSummary() async {
        final scrollable = find.descendant(
          of: find.byKey(const ValueKey('journey-scroll')),
          matching: find.byType(Scrollable),
        );
        tester.state<ScrollableState>(scrollable).position.jumpTo(0);
        await tester.pump();
        await tester.scrollUntilVisible(
          find.text('AI Planning Engine'),
          150,
          scrollable: scrollable,
        );
        await tester.pumpAndSettle();
      }

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      await revealAgentSummary();
      expect(find.text('FAILED'), findsNWidgets(4));
      await tester.ensureVisible(find.text('Edit'));
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('change-notes')),
        'Please revise hotel',
      );
      await tester.tap(find.text('Request changes'));
      await tester.pump(const Duration(milliseconds: 400));
      revised = true;
      events.add(
        const AgentLogStreamEvent('trip-status', {
          'status': 'AwaitingApproval',
        }),
      );
      await tester.pumpAndSettle();
      expect(TripSelectionService.activeBookingItineraryId, 43);
      expect(TripSelectionService.activeBookingId, 101);
      await revealAgentSummary();
      expect(find.text('FAILED'), findsNothing);
      expect(find.text('SUCCESS'), findsNWidgets(4));
      expect(find.text('Your latest itinerary is ready'), findsOneWidget);
      expect(find.text('Previous change request failed.'), findsNothing);
      expect(find.text('Old internal diagnostics'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await events.close();
    },
  );

  testWidgets('8. A submitted trip without an API itinerary stays pending', (
    tester,
  ) async {
    ApiService.mockGetMyItineraries = () async => [];
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (_) => MaterialPageRoute(
          settings: const RouteSettings(arguments: {'tripRequestId': 10}),
          builder: (_) => const MyItineraryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Your itinerary is pending'), findsOneWidget);
    expect(find.text('Accept Itinerary'), findsNothing);
    expect(find.text('Continue to Checkout'), findsNothing);
    expect(find.textContaining('LKR'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('9. Empty API items never generate activities or a cost', (
    tester,
  ) async {
    final itinerary = createSampleItinerary()..['items'] = [];
    itinerary.remove('totalEstimatedCost');
    ApiService.mockGetMyItineraries = () async => [itinerary];
    ApiService.mockGetItinerary = (_) async => itinerary;
    await tester.pumpWidget(
      buildTestWidget(nowProvider: () => DateTime(2026, 10, 10)),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('No activities scheduled yet for this itinerary.'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Cost pending'),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Cost pending'), findsOneWidget);
    expect(find.text('Sigiriya Rock Fortress'), findsNothing);
    expect(find.text('Accept Itinerary'), findsNothing);
  });

  testWidgets(
    '10. Failed acceptance retains Proposed status and offers retry',
    (tester) async {
      final itinerary = createSampleItinerary();
      ApiService.mockGetMyItineraries = () async => [itinerary];
      ApiService.mockGetItinerary = (_) async => itinerary;
      ApiService.mockAcceptItinerary = (_) async =>
          throw const ApiException('Approval denied');
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      await scrollJourneyToBottom(tester);
      await tester.ensureVisible(find.text('Accept Itinerary'));
      await tester.tap(find.text('Accept Itinerary'));
      await tester.pumpAndSettle();
      expect(find.text('Approval denied'), findsOneWidget);
      expect(find.text('Continue to Checkout'), findsNothing);
      expect(itinerary['status'], 1);
    },
  );

  testWidgets(
    '11. VIEW FULL ROUTE button is tappable and navigates to /trip-map',
    (tester) async {
      final itinerary = createSampleItinerary();
      ApiService.mockGetMyItineraries = () async => [itinerary];
      ApiService.mockGetItinerary = (_) async => itinerary;
      bool navigatedToMap = false;

      await tester.pumpWidget(
        buildTestWidget(
          routes: {
            '/trip-map': (context) {
              navigatedToMap = true;
              return const Scaffold(body: Text('Mock Trip Map'));
            },
          },
        ),
      );
      await tester.pumpAndSettle();

      final viewRouteBtn = find.text('VIEW FULL ROUTE');
      expect(viewRouteBtn, findsOneWidget);
      await tester.tap(viewRouteBtn);
      await tester.pumpAndSettle();

      expect(navigatedToMap, isTrue);
      expect(find.text('Mock Trip Map'), findsOneWidget);
    },
  );

  testWidgets('12. failed AI planning screen is scroll-safe at supported widths', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.devicePixelRatio = 1;
    ApiService.mockGetMyItineraries = () async => [];
    ApiService.mockGetTripRequest = (_) async => {
      'id': 155,
      'status': 'Failed',
      'startDate': '2026-10-16T00:00:00',
      'endDate': '2026-10-22T00:00:00',
      'failureReason':
          'No complete transport plan is available for every selected route leg.',
    };
    ApiService.mockGetAgentLogs = (_) async => [
      {
        'agentName': 'CoordinatorAgent',
        'stepName': 'TerminateTripPlanning after a long failure explanation',
        'status': 'Failed',
        'timestamp': '2026-10-08T18:57:44.772859',
        'output':
            '{"failure_code":"TRANSPORT_CATALOGUE_NO_ROUTE","missing_route_legs":["Colombo -> Bentota","Bentota -> Arugam Bay"],"detail":"This diagnostic output must wrap safely across a narrow mobile viewport."}',
      },
      {
        'agentName': 'ItineraryAgent',
        'stepName': 'Generated itinerary with a long diagnostic subtitle',
        'status': 'Success',
        'timestamp': '2026-10-08T18:57:41.777215',
        'output': '{"tours_found":13}',
      },
      {
        'agentName': 'BookingAgent',
        'stepName': 'Booking Agent failed',
        'status': 'Failed',
        'timestamp': '2026-10-08T18:57:44.263159',
        'output':
            '{"agent_outcome":"Failed","error_code":"TRANSPORT_CATALOGUE_NO_ROUTE","error":"No complete transport plan is available for every selected route leg."}',
      },
      {
        'agentName': 'ValidationAgent',
        'stepName': 'Rejected package before approval gate',
        'status': 'Failed',
        'timestamp': '2026-10-08T18:57:44.569346',
        'output':
            '{"error_code":"UPSTREAM_BOOKING_FAILED","error":"No complete transport plan is available for every selected route leg."}',
      },
    ];

    for (final width in [320.0, 360.0, 390.0, 412.0, 768.0]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (settings) => MaterialPageRoute(
            settings: const RouteSettings(arguments: {'tripRequestId': 155}),
            builder: (_) => const MyItineraryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'No complete transport plan is available for every selected route leg.',
        ),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    '13. populated itinerary stays responsive from mobile to desktop widths',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      tester.view.devicePixelRatio = 1;
      final itinerary = createSampleItinerary(status: 1, totalCost: 250000);
      itinerary['title'] =
          'Colombo Bentota Arugam Bay long multi-destination journey';
      (itinerary['items'] as List)[0]['tourName'] =
          'A very long cultural and coastal activity title that must wrap safely';
      (itinerary['items'] as List)[0]['description'] =
          'Long activity details should wrap within the itinerary card.';
      itinerary['bookingItems'] = [
        {
          'itemType': 'Transport',
          'transportLegIndex': 0,
          'transportType': 'Private Van',
          'transportProvider':
              'A deliberately long demo transport provider name',
          'routeFrom': 'Colombo',
          'routeTo': 'Bentota',
          'totalPrice': 22500,
        },
        {
          'itemType': 'Transport',
          'transportLegIndex': 1,
          'transportType': 'Private Van',
          'transportProvider':
              'A deliberately long demo transport provider name',
          'routeFrom': 'Bentota',
          'routeTo': 'Arugam Bay',
          'totalPrice': 60000,
        },
      ];
      ApiService.mockGetMyItineraries = () async => [itinerary];
      ApiService.mockGetItinerary = (_) async => itinerary;

      for (final width in [320.0, 360.0, 390.0, 412.0, 768.0, 1024.0]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'RenderFlex exception at width ${width.toInt()}px',
        );
      }
    },
  );
}
