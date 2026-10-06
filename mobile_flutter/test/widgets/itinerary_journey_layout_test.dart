import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/widgets/itinerary_journey_layout.dart';

void main() {
  testWidgets(
    'scrolling to and selecting the sixth location keeps map and heading fixed',
    (tester) async {
      var selected = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => ItineraryJourneyLayout(
                map: ColoredBox(
                  color: Colors.lightBlue,
                  child: Center(child: Text('Map location $selected')),
                ),
                heading: const Text('Your journey'),
                children: [
                  for (var i = 1; i <= 6; i++)
                    SizedBox(
                      height: 120,
                      child: TextButton(
                        onPressed: () => setState(() => selected = i),
                        child: Text('Journey location $i'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      final map = find.byKey(const ValueKey('fixed-itinerary-map'));
      final mapRect = tester.getRect(map);
      final headingRect = tester.getRect(find.text('Your journey'));
      expect(mapRect.height, 240);

      await tester.scrollUntilVisible(find.text('Journey location 6'), 160);
      await tester.tap(find.text('Journey location 6'));
      await tester.pumpAndSettle();
      expect(find.text('Map location 6'), findsOneWidget);
      expect(tester.getRect(map), mapRect);
      expect(tester.getRect(find.text('Your journey')), headingRect);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'short landscape view reserves space for independently scrolling locations',
    (tester) async {
      tester.view.physicalSize = const Size(800, 320);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.only(top: 64),
              child: ItineraryJourneyLayout(
                map: const ColoredBox(color: Colors.lightBlue),
                heading: const Text('Your journey'),
                children: [
                  for (var i = 1; i <= 6; i++)
                    SizedBox(height: 100, child: Text('Location $i')),
                ],
              ),
            ),
          ),
        ),
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('fixed-itinerary-map')))
            .height,
        128,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('journey-scroll'))).height,
        greaterThan(60),
      );
      await tester.scrollUntilVisible(find.text('Location 6'), 120);
      expect(tester.takeException(), isNull);
    },
  );
}
