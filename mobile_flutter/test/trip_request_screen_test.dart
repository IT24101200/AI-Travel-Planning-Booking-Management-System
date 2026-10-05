import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/screens/profile/trip_request_screen.dart';

void main() {
  testWidgets('TripRequestScreen renders title, fields, LKR budget, and 4 agent cards',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TripRequestScreen(),
      ),
    );
    await tester.pump();

    // Verify Title and Subtitle
    expect(find.text('Plan with AI'), findsOneWidget);
    expect(find.text('Four specialist agents, one island journey'), findsOneWidget);

    // Verify Destination field & prompt banner
    expect(find.text('DESTINATION'), findsOneWidget);
    expect(find.text('Tell us what your perfect trip feels like'), findsOneWidget);

    // Verify Dates and Travelers
    expect(find.text('DATE RANGE'), findsOneWidget);
    expect(find.text('TRAVELERS'), findsOneWidget);

    // Verify Budget in LKR (no raw dollar sign)
    expect(find.text('TOTAL BUDGET'), findsOneWidget);
    expect(find.textContaining(RegExp(r'\$')), findsNothing);
    expect(find.textContaining('LKR'), findsWidgets);

    // Verify Travel Interests
    expect(find.text('TRAVEL INTERESTS'), findsOneWidget);
    expect(find.text('Culture'), findsOneWidget);
    expect(find.text('Wildlife'), findsOneWidget);
    expect(find.text('Beaches'), findsOneWidget);

    // Verify The 4 Project Agents
    expect(find.text('Coordinator Agent'), findsOneWidget);
    expect(find.text('Itinerary Agent'), findsOneWidget);
    expect(find.text('Booking Agent'), findsOneWidget);
    expect(find.text('Validation Agent'), findsOneWidget);

    // Verify Generate Button
    expect(find.text('Generate AI Itinerary'), findsOneWidget);
  });

  testWidgets('TripRequestScreen supports selecting 1 or more destinations via toggle chips',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TripRequestScreen(),
      ),
    );
    await tester.pump();

    // Initial state has 4 destinations
    expect(find.text('4 destinations selected'), findsOneWidget);

    // Tap Yala to add it (now 5 destinations)
    await tester.tap(find.widgetWithText(ActionChip, 'Yala'));
    await tester.pump();
    expect(find.text('5 destinations selected'), findsOneWidget);

    // Tap Galle to add it (now 6 destinations, exactly matching user screenshot scenario)
    await tester.tap(find.widgetWithText(ActionChip, 'Galle'));
    await tester.pump();
    expect(find.text('6 destinations selected'), findsOneWidget);

    // Tap Ella to remove it
    await tester.tap(find.widgetWithText(ActionChip, 'Ella'));
    await tester.pump();
    expect(find.text('5 destinations selected'), findsOneWidget);

    // Tap clear button (X icon)
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    // Tap Kandy (1 destination selected)
    await tester.tap(find.widgetWithText(ActionChip, 'Kandy'));
    await tester.pump();
    expect(find.text('1 destination selected'), findsOneWidget);

    // Tap Nuwara Eliya (2 destinations selected)
    await tester.tap(find.widgetWithText(ActionChip, 'Nuwara Eliya'));
    await tester.pump();
    expect(find.text('2 destinations selected'), findsOneWidget);
  });
}
