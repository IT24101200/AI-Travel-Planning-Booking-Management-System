import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/widgets/agent_workflow_card.dart';

void main() {
  testWidgets(
    'dispatch failure shows not-started agents without a narrow-screen overflow',
    (tester) async {
      tester.view.physicalSize = const Size(280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AgentWorkflowCard(
                tripRequestId: 41,
                initialLogs: [
                  {'agentName': 'Pipeline', 'status': 'Failed'},
                ],
                pipelineStatus: 'Failed',
                failureReason:
                    'The planning service is temporarily unavailable. Please retry.',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('NOT STARTED'), findsNWidgets(4));
      expect(find.text('FAILED'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an individual failed stage remains failed while later stages are not started',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AgentWorkflowCard(
              tripRequestId: 42,
              initialLogs: [
                {'agentName': 'CoordinatorAgent', 'status': 'Failed'},
              ],
              pipelineStatus: 'Failed',
              failureReason:
                  'The planning service could not complete this request. Please retry.',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('FAILED'), findsOneWidget);
      expect(find.text('NOT STARTED'), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'booking agent is failed when availability succeeds with zero candidates',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AgentWorkflowCard(
              tripRequestId: 150,
              initialLogs: [
                {
                  'agentName': 'BookingAgent',
                  'stepName': 'Checked transport availability',
                  'status': 'Success',
                  'output': '{"available_transports": 0}',
                },
              ],
              pipelineStatus: 'Failed',
              failureReason:
                  'No suitable transport is available for the selected route and travel dates.',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('FAILED'), findsOneWidget);
      expect(find.text('SUCCESS'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('long failed diagnostics stay within narrow widths when expanded', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.devicePixelRatio = 1;
    final longOutput = jsonEncode({
      'error_code': 'TRANSPORT_CATALOGUE_NO_ROUTE',
      'error':
          'No complete transport plan is available for every selected route leg.',
      'missing_route_legs': ['Colombo -> Bentota', 'Bentota -> Arugam Bay'],
      'diagnostic_detail':
          'A very long diagnostic value that must wrap safely instead of forcing the workflow card beyond the viewport.' *
          3,
    });
    final logs = [
      {
        'agentName': 'CoordinatorAgent',
        'stepName': 'TerminateTripPlanning after a long failure explanation',
        'status': 'Failed',
        'timestamp': '2026-10-08T18:57:44.772859',
        'output': longOutput,
      },
      {
        'agentName': 'ItineraryAgent',
        'stepName':
            'Generated itinerary with a deliberately long diagnostic subtitle',
        'status': 'Success',
        'timestamp': '2026-10-08T18:57:41.777215',
        'output': longOutput,
      },
      {
        'agentName': 'BookingAgent',
        'stepName': 'Booking Agent failed',
        'status': 'Failed',
        'timestamp': '2026-10-08T18:57:44.263159',
        'output': longOutput,
      },
      {
        'agentName': 'ValidationAgent',
        'stepName': 'Rejected package before approval gate',
        'status': 'Failed',
        'timestamp': '2026-10-08T18:57:44.569346',
        'output': longOutput,
      },
    ];

    for (final width in [320.0, 360.0, 390.0, 412.0, 768.0]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AgentWorkflowCard(
                tripRequestId: 155,
                initialLogs: logs,
                pipelineStatus: 'Failed',
                failureReason:
                    'No complete transport plan is available for every selected route leg.',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      for (final title in [
        'Agent 1: Coordinator Agent',
        'Agent 2: Itinerary Agent',
        'Agent 3: Booking Agent',
        'Agent 4: Validation Agent',
      ]) {
        final finder = find.text(title);
        if (finder.evaluate().isNotEmpty) {
          await tester.ensureVisible(finder.first);
          await tester.tap(finder.first);
          await tester.pump();
        }
      }

      expect(
        tester.takeException(),
        isNull,
        reason: 'RenderFlex exception at width ${width.toInt()}px',
      );
    }
  });
}
