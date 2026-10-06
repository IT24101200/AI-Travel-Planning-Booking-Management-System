import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/widgets/itinerary_route_preview.dart';

void main() {
  testWidgets('preview uses 40 percent height and shows unavailable directions without a fake map', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: ItineraryRoutePreview(itinerary: {'items': []}),
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('no map stops'), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);
    expect(tester.getSize(find.byType(ItineraryRoutePreview)).height, 240);
    await tester.tap(find.text('Retry directions'));
    await tester.pumpAndSettle();
    expect(find.textContaining('no map stops'), findsOneWidget);
  });
}
