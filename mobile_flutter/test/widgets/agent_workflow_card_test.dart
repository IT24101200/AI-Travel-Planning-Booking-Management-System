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

  testWidgets('customer summaries hide detailed logs at supported widths', (
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

      expect(find.textContaining('diagnostic'), findsNothing);
      expect(find.textContaining('TRANSPORT_CATALOGUE_'), findsNothing);
      expect(find.text('Output / Decisions:'), findsNothing);
      expect(find.text('Input context:'), findsNothing);
      expect(find.byTooltip('Refresh Agent Logs'), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);

      expect(
        tester.takeException(),
        isNull,
        reason: 'RenderFlex exception at width ${width.toInt()}px',
      );
    }
  });

  List<Map<String, dynamic>> attempt(String time, String status) => [
    {
      'agentName': 'CoordinatorAgent',
      'stepName': 'InitializePipeline',
      'status': 'Started',
      'timestamp': '${time}00Z',
    },
    for (final entry in [
      'CoordinatorAgent',
      'ItineraryAgent',
      'BookingAgent',
      'ValidationAgent',
    ].indexed)
      {
        'agentName': entry.$2,
        'stepName': 'Finished planning stage',
        'status': status,
        'timestamp': '$time${entry.$1 + 10}Z',
        'output': status == 'Failed' ? 'Old failed diagnostics' : 'Raw output',
      },
  ];

  Future<void> showCard(
    WidgetTester tester,
    List<dynamic> logs, {
    String status = 'Planning',
    String? failureReason,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AgentWorkflowCard(
              tripRequestId: 166,
              initialLogs: logs,
              pipelineStatus: status,
              failureReason: failureReason,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('successful hotel revision replaces the failed attempt', (
    tester,
  ) async {
    final failed = attempt('2026-10-09T10:00:', 'Failed');
    await showCard(
      tester,
      failed,
      status: 'Failed',
      failureReason: 'Old failure',
    );
    expect(find.text('FAILED'), findsNWidgets(4));

    // A reconnect snapshot may return the history in reverse timestamp order.
    await showCard(tester, [
      ...attempt('2026-10-09T11:00:', 'Success').reversed,
      ...failed.reversed,
    ], status: 'AwaitingApproval');

    expect(find.text('SUCCESS'), findsNWidgets(4));
    expect(find.text('FAILED'), findsNothing);
    expect(find.text('Old failure'), findsNothing);
    expect(find.text('Your latest itinerary is ready'), findsOneWidget);
    expect(find.text('Hotels and transport selected'), findsOneWidget);
    expect(find.text('Raw output'), findsNothing);
  });

  testWidgets('new revision resets previous failures before agents finish', (
    tester,
  ) async {
    final previous = attempt('2026-10-09T10:00:', 'Failed');
    final revision = {
      'agentName': 'Customer change request',
      'stepName': 'Requested hotel and transport changes',
      'status': 'Started',
      'timestamp': '2026-10-09T11:00:00Z',
    };
    await showCard(tester, [...previous, revision]);
    expect(find.text('FAILED'), findsNothing);
    expect(find.text('RUNNING'), findsOneWidget);
    expect(find.text('NOT STARTED'), findsNWidgets(3));

    await showCard(tester, [
      ...previous,
      revision,
      ...attempt('2026-10-09T11:01:', 'Success').take(2),
    ]);
    expect(find.text('SUCCESS'), findsOneWidget);
    expect(find.text('FAILED'), findsNothing);
    expect(find.text('NOT STARTED'), findsNWidgets(3));
  });

  testWidgets('latest stage result wins even without attempt markers', (
    tester,
  ) async {
    await showCard(tester, [
      {'agentName': 'BookingAgent', 'status': 'Failed'},
      {'agentName': 'BookingAgent', 'status': 'Success'},
    ]);
    expect(find.text('SUCCESS'), findsOneWidget);
    expect(find.text('FAILED'), findsNothing);
  });

  testWidgets('accepted proposal wins while final logs are catching up', (
    tester,
  ) async {
    await showCard(
      tester,
      attempt('2026-10-09T10:00:', 'Failed'),
      status: 'AwaitingApproval',
    );
    expect(find.text('SUCCESS'), findsNWidgets(4));
    expect(find.text('FAILED'), findsNothing);
  });

  testWidgets(
    'failed revision of an existing proposal still shows its reason',
    (tester) async {
      await showCard(
        tester,
        [
          ...attempt('2026-10-09T10:00:', 'Success'),
          ...attempt('2026-10-09T11:00:', 'Failed'),
        ],
        status: 'AwaitingApproval',
        failureReason: 'Selected hotel is unavailable.',
      );
      expect(find.text('FAILED'), findsNWidgets(4));
      expect(find.text('SUCCESS'), findsNothing);
      expect(find.text('Selected hotel is unavailable.'), findsOneWidget);
      expect(find.text('Your latest itinerary is ready'), findsNothing);
    },
  );

  testWidgets('coordinator retry resets downstream stage failures', (
    tester,
  ) async {
    await showCard(tester, [
      ...attempt('2026-10-09T10:00:', 'Failed'),
      {
        'agentName': 'CoordinatorAgent',
        'stepName': 'DecomposeAndAllocateBudget',
        'status': 'Success',
        'timestamp': '2026-10-09T10:01:00Z',
      },
    ]);
    expect(find.text('SUCCESS'), findsOneWidget);
    expect(find.text('FAILED'), findsNothing);
    expect(find.text('NOT STARTED'), findsNWidgets(3));
  });
}
