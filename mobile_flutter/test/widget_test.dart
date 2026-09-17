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
}
