import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/widgets/trip_planning_summary.dart';

void main() {
  testWidgets('planning summary distinguishes fixed stops from pending order', (
    tester,
  ) async {
    for (final airport in [null, 'CMB']) {
      for (final starter in [null, 'Colombo']) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: TripPlanningSummary(
                  destinations: const ['Colombo', 'Yala', 'Bentota'],
                  starter: starter,
                  airportCode: airport,
                  arrivalTime: '16:00',
                  dateRangeLabel: '17–23 Oct 2026',
                  tripDays: 7,
                  budgetLabel: 'LKR 175,000–250,000',
                ),
              ),
            ),
          ),
        );
        expect(find.text('How we’ll plan your trip'), findsOneWidget);
        expect(
          find.text('Visit order will be confirmed after planning.'),
          findsOneWidget,
        );
        expect(find.text('1. Colombo'), findsNothing);
        expect(find.text('Yala'), findsOneWidget);
        expect(find.text('Bentota'), findsOneWidget);
        expect(find.text('7 days · 6 nights'), findsOneWidget);
        expect(
          find.textContaining('Budget: LKR 175,000–250,000'),
          findsOneWidget,
        );
        expect(
          find.text('Arrive at CMB airport'),
          airport == null ? findsNothing : findsOneWidget,
        );
        expect(
          find.text('Rest before journeys when needed'),
          airport == null ? findsNothing : findsOneWidget,
        );
        if (starter == null) {
          expect(find.text('AI chooses the first destination'), findsOneWidget);
          expect(find.text('Colombo'), findsOneWidget);
        } else {
          expect(find.text('First destination: Colombo'), findsOneWidget);
          expect(find.text('Colombo'), findsNothing);
          if (airport != null) {
            expect(find.textContaining('Airport → Colombo'), findsOneWidget);
          }
        }
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets(
    'planning explanation fits narrow and wide screens in both themes',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final width in [280.0, 390.0, 768.0]) {
        tester.view.physicalSize = Size(width, 850);
        for (final brightness in Brightness.values) {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(brightness: brightness),
              home: const Scaffold(
                body: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: TripPlanningSummary(
                    destinations: [
                      'Anuradhapura',
                      'Arugam Bay',
                      'Batticaloa',
                      'Bentota',
                    ],
                    starter: 'Anuradhapura',
                    airportCode: 'HRI',
                    arrivalTime: '17:30',
                    dateRangeLabel: '17–23 Oct 2026',
                    tripDays: 7,
                    budgetLabel: 'LKR 175,000–250,000',
                  ),
                ),
              ),
            ),
          );
          await tester.ensureVisible(
            find.textContaining('Your generated itinerary'),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      }
    },
  );
}
