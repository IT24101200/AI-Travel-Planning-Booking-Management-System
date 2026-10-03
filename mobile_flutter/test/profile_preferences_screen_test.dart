import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_flutter/screens/profile/profile_preferences_screen.dart';
import 'package:mobile_flutter/services/api_service.dart';

void main() {
  setUp(() {
    ApiService.mockGetProfile = () async => {
          'statusCode': 200,
          'fullName': 'user',
          'email': 'user@gmail.com',
          'phone': '0776543876',
          'tripCount': 6,
        };

    ApiService.mockGetPreferences = () async => http.Response(
          jsonEncode({
            'budgetMin': 75000,
            'budgetMax': 350000,
            'currency': 'LKR',
            'preferredActivities': 'Culture, Wildlife, Hiking, Food',
            'dietaryNotes': 'Vegetarian',
            'accessibilityNotes': 'Ground floor preferred',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
  });

  tearDown(() {
    ApiService.mockGetProfile = null;
    ApiService.mockGetPreferences = null;
  });

  testWidgets(
      'ProfilePreferencesScreen renders profile info, budget range in LKR, dietary, accessibility and save button',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProfilePreferencesScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify Title and Banner
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('TRAIL MEMBER · 6 TRIPS'), findsOneWidget);

    // Verify Account Details
    expect(find.text('Account details'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Mobile'), findsOneWidget);
    expect(find.text('Home country'), findsOneWidget);

    // Verify Budget Range in LKR
    expect(find.text('Budget range'), findsOneWidget);
    expect(find.textContaining('LKR'), findsWidgets);
    expect(find.textContaining(RegExp(r'\$')), findsNothing);

    // Verify Travel Interests
    expect(find.text('Travel interests'), findsOneWidget);
    expect(find.text('Culture'), findsOneWidget);
    expect(find.text('Wildlife'), findsOneWidget);
    expect(find.text('Hiking'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);

    // Verify Dietary Requirements
    expect(find.text('Dietary requirements'), findsOneWidget);
    expect(find.text('No restrictions'), findsOneWidget);
    expect(find.text('Vegetarian'), findsOneWidget);
    expect(find.text('Vegan'), findsOneWidget);

    // Verify Accessibility
    expect(find.text('Accessibility & mobility'), findsOneWidget);
    expect(find.text('Ground floor preferred'), findsOneWidget);
    expect(find.text('Wheelchair accessible'), findsOneWidget);

    // Verify Notifications, Save and Logout buttons
    expect(find.text('Trip notifications'), findsOneWidget);
    expect(find.text('Save Travel Preferences'), findsOneWidget);
    expect(find.text('Log Out'), findsOneWidget);
  });
}
