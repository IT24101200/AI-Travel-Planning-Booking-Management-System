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
}
