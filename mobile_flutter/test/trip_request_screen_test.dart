import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/screens/profile/trip_request_screen.dart';
import 'package:mobile_flutter/services/api_service.dart';
import 'package:mobile_flutter/services/agent_health_service.dart';

void main() {
  setUp(() {
    ApiService.mockGetAgentConnectionStatus = () async =>
        const AgentConnectionStatus(
          state: AgentConnectionState.connected,
          latencyMs: 42,
        );
  });

  tearDown(() {
    ApiService.mockGetDestinations = null;
    ApiService.mockCreateTripRequest = null;
    ApiService.mockGetAgentConnectionStatus = null;
  });

  testWidgets(
    'TripRequestScreen renders title, fields, LKR budget, and 4 agent cards',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: TripRequestScreen()));
      await tester.pump();

      // Verify Title and Subtitle
      expect(find.text('Plan with AI'), findsOneWidget);
      expect(
        find.text('Four specialist agents, one island journey'),
        findsOneWidget,
      );

      // Verify Destination field & prompt banner
      expect(find.text('DESTINATION'), findsOneWidget);
      expect(
        find.text('Tell us what your perfect trip feels like'),
        findsOneWidget,
      );

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
    },
  );

  testWidgets(
    'TripRequestScreen supports selecting 1 or more destinations via toggle chips',
    (WidgetTester tester) async {
      ApiService.mockGetDestinations = () async => [
        {'id': 1, 'name': 'Ella'},
        {'id': 2, 'name': 'Yala'},
        {'id': 3, 'name': 'Galle'},
        {'id': 4, 'name': 'Kandy'},
        {'id': 5, 'name': 'Nuwara Eliya'},
      ];
      await tester.pumpWidget(const MaterialApp(home: TripRequestScreen()));
      await tester.pumpAndSettle();

      // Initial state has no destination selected.
      expect(find.textContaining('destinations selected'), findsNothing);

      // Tap Yala to add it (now 1 destination)
      await tester.tap(find.widgetWithText(ActionChip, 'Yala'));
      await tester.pump();
      expect(find.text('1 destination selected'), findsOneWidget);

      // Tap Galle to add it (now 2 destinations)
      await tester.tap(find.widgetWithText(ActionChip, 'Galle'));
      await tester.pump();
      expect(find.text('2 destinations selected'), findsOneWidget);

      // Tap Ella to add it (now 3 destinations)
      await tester.tap(find.widgetWithText(ActionChip, 'Ella'));
      await tester.pump();
      expect(find.text('3 destinations selected'), findsOneWidget);

      // Tap Ella to remove it
      await tester.tap(find.widgetWithText(ActionChip, 'Ella'));
      await tester.pump();
      expect(find.text('2 destinations selected'), findsOneWidget);

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
    },
  );

  testWidgets('TripRequestScreen submits every selected destination in order', (
    WidgetTester tester,
  ) async {
    ApiService.mockGetDestinations = () async => [
      {'id': 11, 'name': 'Anuradhapura'},
      {'id': 22, 'name': 'Colombo'},
      {'id': 33, 'name': 'Jaffna'},
    ];
    Map<String, dynamic>? submitted;
    ApiService.mockCreateTripRequest = (payload) async {
      submitted = payload;
      return {'statusCode': 201, 'id': 700};
    };

    await tester.pumpWidget(
      MaterialApp(
        home: const TripRequestScreen(),
        onGenerateRoute: (settings) => MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('Itinerary')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final name in ['Anuradhapura', 'Colombo', 'Jaffna']) {
      await tester.tap(find.widgetWithText(ActionChip, name));
      await tester.pump();
    }
    await tester.ensureVisible(find.text('Generate AI Itinerary'));
    await tester.tap(find.text('Generate AI Itinerary'));
    await tester.pumpAndSettle();

    expect(submitted?['destinationId'], 11);
    expect(submitted?['airportPickup'], false);
    expect(submitted?['starterLocationId'], isNull);
    expect(submitted?['rawRequestText'], contains('Route origin: AI optimized.'));
    expect(submitted?['destinationIds'], [11, 22, 33]);
    expect(submitted?['destinations'], [
      {'id': 11, 'name': 'Anuradhapura', 'order': 0},
      {'id': 22, 'name': 'Colombo', 'order': 1},
      {'id': 33, 'name': 'Jaffna', 'order': 2},
    ]);
  });

  testWidgets(
    'starter location is submitted first while the planner may optimize remaining destinations',
    (WidgetTester tester) async {
      ApiService.mockGetDestinations = () async => [
        {'id': 11, 'name': 'Anuradhapura'},
        {'id': 22, 'name': 'Colombo'},
        {'id': 33, 'name': 'Jaffna'},
      ];
      Map<String, dynamic>? submitted;
      ApiService.mockCreateTripRequest = (payload) async {
        submitted = payload;
        return {'statusCode': 201, 'id': 702};
      };

      await tester.pumpWidget(
        MaterialApp(
          home: const TripRequestScreen(),
          onGenerateRoute: (_) => MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('Itinerary')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final name in ['Anuradhapura', 'Colombo', 'Jaffna']) {
        await tester.tap(find.widgetWithText(ActionChip, name));
        await tester.pump();
      }

      await tester.tap(find.byKey(const ValueKey('starter-location-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('starter-location-option-Colombo')),
      );
      await tester.pump();

      await tester.ensureVisible(find.text('Generate AI Itinerary'));
      await tester.tap(find.text('Generate AI Itinerary'));
      await tester.pumpAndSettle();

      expect(submitted?['destinationId'], 22);
      expect(submitted?['starterLocationId'], 22);
      expect(submitted?['destinationIds'], [22, 11, 33]);
      expect(submitted?['destinations'], [
        {'id': 22, 'name': 'Colombo', 'order': 0},
        {'id': 11, 'name': 'Anuradhapura', 'order': 1},
        {'id': 33, 'name': 'Jaffna', 'order': 2},
      ]);
    },
  );

  testWidgets('airport pickup checkbox submits airport and arrival time', (
    tester,
  ) async {
    ApiService.mockGetDestinations = () async => [
      {'id': 1, 'name': 'Ella'},
      {'id': 2, 'name': 'Kandy'},
    ];
    Map<String, dynamic>? submitted;
    ApiService.mockCreateTripRequest = (payload) async {
      submitted = payload;
      return {'statusCode': 201, 'id': 701};
    };
    await tester.pumpWidget(
      MaterialApp(
        home: const TripRequestScreen(),
        onGenerateRoute: (_) => MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('Itinerary')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, 'Ella'));
    await tester.tap(find.widgetWithText(ActionChip, 'Kandy'));
    await tester.ensureVisible(find.text('Airport pickup'));
    await tester.tap(find.text('Airport pickup'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('starter-location-dropdown')), findsNothing);
    expect(find.text('Arrival airport'), findsOneWidget);
    await tester.ensureVisible(find.text('Generate AI Itinerary'));
    await tester.tap(find.text('Generate AI Itinerary'));
    await tester.pumpAndSettle();
    expect(submitted?['airportPickup'], true);
    expect(submitted?['starterLocationId'], isNull);
    expect(submitted?['airportCode'], 'CMB');
    expect(submitted?['airportArrivalTime'], '08:00:00');
  });

  testWidgets('TripRequestScreen shows checking then connected status', (
    WidgetTester tester,
  ) async {
    final health = Completer<AgentConnectionStatus>();
    ApiService.mockGetAgentConnectionStatus = () => health.future;

    await tester.pumpWidget(const MaterialApp(home: TripRequestScreen()));
    await tester.pump();
    expect(find.textContaining('Checking connection'), findsOneWidget);

    health.complete(
      const AgentConnectionStatus(
        state: AgentConnectionState.connected,
        latencyMs: 25,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('AI agent connection · Connected'),
      findsOneWidget,
    );
  });

  testWidgets('TripRequestScreen retries an unavailable agent connection', (
    WidgetTester tester,
  ) async {
    var calls = 0;
    ApiService.mockGetAgentConnectionStatus = () async {
      calls++;
      return calls == 1
          ? const AgentConnectionStatus.unavailable()
          : const AgentConnectionStatus(state: AgentConnectionState.connected);
    };

    await tester.pumpWidget(const MaterialApp(home: TripRequestScreen()));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('AI agent connection · Unavailable'),
      findsOneWidget,
    );
    expect(find.text('Retry AI'), findsOneWidget);

    await tester.tap(find.text('Retry AI'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(
      find.textContaining('AI agent connection · Connected'),
      findsOneWidget,
    );
  });

  testWidgets('TripRequestScreen remains safe on a narrow viewport', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(width: 320, height: 800, child: TripRequestScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('TripRequestScreen ignores a health result after disposal', (
    WidgetTester tester,
  ) async {
    final health = Completer<AgentConnectionStatus>();
    ApiService.mockGetAgentConnectionStatus = () => health.future;

    await tester.pumpWidget(const MaterialApp(home: TripRequestScreen()));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    health.complete(const AgentConnectionStatus.unavailable());
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
