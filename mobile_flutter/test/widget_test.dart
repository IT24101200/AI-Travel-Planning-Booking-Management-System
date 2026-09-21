import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/widgets/common_widgets.dart';

void main() {
  testWidgets('StatusBadge smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatusBadge(status: 'Confirmed'),
        ),
      ),
    );

    expect(find.text('Confirmed'), findsOneWidget);
  });

  testWidgets('StatusBadge displays various status levels', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              StatusBadge(status: 'Draft'),
              StatusBadge(status: 'AwaitingApproval'),
              StatusBadge(status: 'Rejected'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Draft'), findsOneWidget);
    expect(find.text('AwaitingApproval'), findsOneWidget);
    expect(find.text('Rejected'), findsOneWidget);
  });

  testWidgets('EmptyState widget displays icon and message', (WidgetTester tester) async {
    bool tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.map,
            message: 'No active itineraries found',
            actionLabel: 'Explore Tours',
            onAction: () {
              tapped = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('No active itineraries found'), findsOneWidget);
    expect(find.text('Explore Tours'), findsOneWidget);
    await tester.tap(find.text('Explore Tours'));
    expect(tapped, isTrue);
  });

  testWidgets('ErrorMessage widget displays message and triggers retry', (WidgetTester tester) async {
    bool retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ErrorMessage(
            message: 'Unable to connect to travel gateway',
            onRetry: () {
              retried = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('Unable to connect to travel gateway'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });

  testWidgets('SectionHeader widget displays title and action', (WidgetTester tester) async {
    bool actionClicked = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SectionHeader(
            title: 'Featured Ceylon Tours',
            actionLabel: 'See All',
            onAction: () {
              actionClicked = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('Featured Ceylon Tours'), findsOneWidget);
    expect(find.text('See All'), findsOneWidget);
    await tester.tap(find.text('See All'));
    expect(actionClicked, isTrue);
  });
}
