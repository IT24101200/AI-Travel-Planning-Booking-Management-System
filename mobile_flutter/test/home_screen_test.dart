import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/screens/home_screen.dart';
import 'package:mobile_flutter/services/api_service.dart';

void main() {
  setUp(() {
    ApiService.mockGetTours = null;
  });

  tearDown(() {
    ApiService.mockGetTours = null;
  });

  Widget createTestWidget() {
    return const MaterialApp(
      home: HomeScreen(),
    );
  }

  testWidgets('HomeScreen Explore tab renders hero, search, 2x4 actions grid, categories, destinations, and tours', (WidgetTester tester) async {
    final testTours = [
      {
        'id': 101,
        'name': 'Kandy Sacred Temple Walk',
        'category': 'CULTURE',
        'durationHours': 5,
        'price': 12000,
        'rating': '4.8',
      },
      {
        'id': 102,
        'name': 'Sigiriya Sunrise Hike',
        'category': 'HERITAGE',
        'durationHours': 4,
        'price': 15000,
        'rating': '4.9',
      },
    ];

    ApiService.mockGetTours = ({String? search, String? sortBy}) async => testTours;

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Verify Hero title
    expect(find.text('Explore Serendib'), findsOneWidget);
    expect(find.text('Search places, tours & stays'), findsOneWidget);

    // Verify 2x4 Quick Actions Grid
    expect(find.text('AI Plan'), findsOneWidget);
    expect(find.text('Tours'), findsOneWidget);
    expect(find.text('Hotels'), findsOneWidget);
    expect(find.text('Transit'), findsOneWidget);
    expect(find.text('Itinerary'), findsOneWidget);
    expect(find.text('Route Map'), findsOneWidget);
    expect(find.text('My Trips'), findsAtLeast(1)); // Also in bottom nav
    expect(find.text('QR Pass'), findsOneWidget);

    // Verify Category Filter Chips
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Heritage'), findsOneWidget);
    expect(find.text('Hiking'), findsOneWidget);
    expect(find.text('Wildlife'), findsOneWidget);
    expect(find.text('Beach'), findsOneWidget);
    expect(find.text('Culture'), findsOneWidget);

    // Verify Dream destinations
    expect(find.text('Dream destinations'), findsOneWidget);
    expect(find.text('Ella'), findsOneWidget);
    expect(find.text('Mirissa'), findsOneWidget);
    expect(find.text('Yala'), findsOneWidget);

    // Verify Multi-Agent Banner
    expect(find.text('Four agents. One seamless trip.'), findsOneWidget);
    expect(find.text('1. Coordinator'), findsOneWidget);
    expect(find.text('2. Itinerary'), findsOneWidget);
    expect(find.text('3. Booking'), findsOneWidget);
    expect(find.text('4. Verification'), findsOneWidget);

    // Verify Featured Tours
    expect(find.text('Featured tours'), findsOneWidget);
    expect(find.text('Kandy Sacred Temple Walk'), findsOneWidget);
    expect(find.text('Sigiriya Sunrise Hike'), findsOneWidget);

    // Verify LKR price format (no raw $)
    expect(find.textContaining('from LKR 12,000.00'), findsOneWidget);
    expect(find.textContaining('from LKR 15,000.00'), findsOneWidget);

    // Verify CTA button
    expect(find.text('AI Plan My Trip'), findsOneWidget);
  });
}
