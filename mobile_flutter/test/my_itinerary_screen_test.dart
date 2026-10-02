import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/screens/tours/my_itinerary_screen.dart';
import 'package:mobile_flutter/services/api_service.dart';

void main() {
  tearDown(() {
    ApiService.mockGetMyItineraries = null;
    ApiService.mockGetItinerary = null;
    ApiService.mockAcceptItinerary = null;
    ApiService.mockRequestItineraryChanges = null;
  });

  Widget buildTestWidget() {
    return const MaterialApp(
      home: MyItineraryScreen(),
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

  testWidgets('1. Loading state displays indicator and loading text', (WidgetTester tester) async {
    final completer = Completer<List<dynamic>>();
    ApiService.mockGetMyItineraries = () => completer.future;

    await tester.pumpWidget(buildTestWidget());
    await tester.pump(); // Trigger initial frame

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading your itinerary...'), findsOneWidget);

    completer.complete([]);
    await tester.pumpAndSettle();
  });

  testWidgets('2. Empty state displays No itinerary yet and Explore Tours button', (WidgetTester tester) async {
    ApiService.mockGetMyItineraries = () async => [];

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('No itinerary yet'), findsOneWidget);
    expect(find.text('Explore Tours'), findsOneWidget);
  });

  testWidgets('3. Error state displays retry button and error message', (WidgetTester tester) async {
    ApiService.mockGetMyItineraries = () async => throw Exception('Network timeout');

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Unable to load itinerary'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('4. Real data renders timeline items, total, and prices in LKR (no \$)', (WidgetTester tester) async {
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

    // Verify LKR formatted prices
    expect(find.text('LKR 7,500'), findsOneWidget);
    expect(find.text('PROPOSED'), findsOneWidget);

    // Verify NO $ symbol is displayed anywhere on screen
    expect(find.textContaining(r'$'), findsNothing);
  });

  testWidgets('5a. Button visibility: Proposed status shows Accept & Request Changes, hides Checkout', (WidgetTester tester) async {
    final itinerary = createSampleItinerary(status: 1); // Proposed
    ApiService.mockGetMyItineraries = () async => [itinerary];
    ApiService.mockGetItinerary = (id) async => itinerary;

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Accept Itinerary'));
    expect(find.text('Accept Itinerary'), findsOneWidget);
    expect(find.text('Request Changes'), findsOneWidget);
    expect(find.text('Continue to Checkout'), findsNothing);
  });

  testWidgets('5b. Button visibility: Draft status shows Request Changes, hides Accept & Checkout', (WidgetTester tester) async {
    final itinerary = createSampleItinerary(status: 0); // Draft
    ApiService.mockGetMyItineraries = () async => [itinerary];
    ApiService.mockGetItinerary = (id) async => itinerary;

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Request Changes'));
    expect(find.text('Request Changes'), findsOneWidget);
    expect(find.text('Accept Itinerary'), findsNothing);
    expect(find.text('Continue to Checkout'), findsNothing);
  });

  testWidgets('5c. Button visibility: Accepted status shows Continue to Checkout, hides Accept & Request Changes', (WidgetTester tester) async {
    final itinerary = createSampleItinerary(status: 2); // Accepted
    ApiService.mockGetMyItineraries = () async => [itinerary];
    ApiService.mockGetItinerary = (id) async => itinerary;

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Continue to Checkout'));
    expect(find.text('Continue to Checkout'), findsOneWidget);
    expect(find.text('Accept Itinerary'), findsNothing);
    expect(find.text('Request Changes'), findsNothing);
  });

  testWidgets('5d. Button visibility: Discarded status hides all action buttons and shows notice', (WidgetTester tester) async {
    final itinerary = createSampleItinerary(status: 3); // Discarded
    ApiService.mockGetMyItineraries = () async => [itinerary];
    ApiService.mockGetItinerary = (id) async => itinerary;

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Accept Itinerary'), findsNothing);
    expect(find.text('Request Changes'), findsNothing);
    expect(find.text('Continue to Checkout'), findsNothing);
    expect(find.text('This itinerary proposal was discarded.'), findsOneWidget);
  });

  testWidgets('6. Accept Itinerary invokes accept API', (WidgetTester tester) async {
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

    final acceptBtnFinder = find.text('Accept Itinerary');
    await tester.ensureVisible(acceptBtnFinder);
    await tester.tap(acceptBtnFinder);
    await tester.pump();

    expect(acceptedId, equals(42));
  });

  testWidgets('7. Request Changes dialog validates required comment and invokes API', (WidgetTester tester) async {
    final itinerary = createSampleItinerary(id: 42, status: 1); // Proposed
    String? submittedComment;

    ApiService.mockGetMyItineraries = () async => [itinerary];
    ApiService.mockGetItinerary = (id) async => itinerary;
    ApiService.mockRequestItineraryChanges = (id, comment) async {
      submittedComment = comment;
      return true;
    };

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Open Request Changes dialog via Edit link or button
    final editFinder = find.text('Edit');
    await tester.ensureVisible(editFinder);
    await tester.tap(editFinder);
    await tester.pumpAndSettle();

    // Verify dialog opened
    expect(find.text('Request Changes'), findsWidgets);
    expect(find.text('Submit Request'), findsOneWidget);

    // Try submitting empty comment
    await tester.tap(find.text('Submit Request'));
    await tester.pumpAndSettle();

    // Validation error should appear
    expect(find.text('Comment is required to request changes'), findsOneWidget);
    expect(submittedComment, isNull);

    // Enter comment and submit
    await tester.enterText(find.byType(TextFormField), 'Please add a morning tea plantation visit');
    await tester.tap(find.text('Submit Request'));
    await tester.pump();

    expect(submittedComment, equals('Please add a morning tea plantation visit'));
  });

  testWidgets('8. Route arguments: Trip passed from Continue Plan displays itinerary and activities instead of empty state', (WidgetTester tester) async {
    // When getMyItineraries is empty (e.g. newly planned trip not yet in Itineraries table)
    ApiService.mockGetMyItineraries = () async => [];

    final sampleTrip = {
      'id': '10',
      'tripRequestId': 10,
      'title': 'Sigiriya & Kandy Explorer',
      'destinationName': 'Sigiriya',
      'startDate': '2026-10-15T00:00:00',
      'endDate': '2026-10-20T00:00:00',
      'days': 5,
      'status': 'AWAITING APPROVAL',
      'price': 150000,
      'currency': 'LKR',
      'rawRequestText': '5 days in Sigiriya and Kandy',
    };

    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            settings: RouteSettings(name: '/my-itinerary', arguments: sampleTrip),
            builder: (_) => const MyItineraryScreen(),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    // Verify it does NOT show empty state
    expect(find.text('No itinerary yet'), findsNothing);

    // Verify it shows the trip title and duration
    expect(find.text('Sigiriya & Kandy Explorer'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('DAYS'), findsOneWidget);

    // Verify action buttons for Proposed/Awaiting Approval are visible
    expect(find.text('Accept Itinerary'), findsOneWidget);
    expect(find.text('Request Changes'), findsOneWidget);
  });
}
