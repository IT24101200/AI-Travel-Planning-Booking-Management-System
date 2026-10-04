import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_flutter/screens/home_screen.dart';
import 'package:mobile_flutter/screens/profile/notifications_screen.dart';
import 'package:mobile_flutter/screens/profile/profile_preferences_screen.dart';
import 'package:mobile_flutter/screens/profile/trip_history_screen.dart';
import 'package:mobile_flutter/screens/profile/trip_request_screen.dart';
import 'package:mobile_flutter/services/api_service.dart';
import 'package:mobile_flutter/services/app_navigation.dart';
import 'package:mobile_flutter/widgets/auth_guard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'jwt_token': 'test-session',
      'user_id': 'customer-1',
      'user_name': 'Test Customer',
      'theme_mode': 'dark',
    });
  });

  tearDown(() {
    ApiService.mockGetProfile = null;
    ApiService.mockGetPreferences = null;
    ApiService.mockUpdateProfile = null;
    ApiService.mockUpdatePreferences = null;
    ApiService.mockCreateTripRequest = null;
    ApiService.mockGetMyBookings = null;
    ApiService.mockGetMyTripRequests = null;
    ApiService.mockGetMyNotifications = null;
    ApiService.mockMarkNotificationRead = null;
    ApiService.mockMarkNotificationUnread = null;
    ApiService.mockMarkAllNotificationsRead = null;
    ApiService.mockGetTours = null;
  });

  for (final verb in ['GET', 'POST', 'PUT', 'PATCH']) {
    testWidgets('$verb 401 clears only auth keys and the navigation stack', (tester) async {
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('Protected page')),
        routes: {'/login': (_) => const Scaffold(body: Text('Login page'))},
      ));
      final client = MockClient((request) async {
        expect(request.method, verb);
        expect(request.headers['Authorization'], 'Bearer test-session');
        return http.Response('{"message":"Session expired"}', 401);
      });
      await http.runWithClient(() async {
        final request = switch (verb) {
          'GET' => ApiService.get('customer/me'),
          'POST' => ApiService.post('triprequest', {}),
          'PUT' => ApiService.updatePreferences({}),
          _ => ApiService.patch('notification/id/read', {}),
        };
        await expectLater(request, throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)));
      }, () => client);
      await tester.pumpAndSettle();
      expect(find.text('Login page'), findsOneWidget);
      expect(navigatorKey.currentState!.canPop(), isFalse);
      expect(await const FlutterSecureStorage().readAll(), {'theme_mode': 'dark'});
    });
  }

  test('List failures throw, while a successful empty list stays empty', () async {
    await http.runWithClient(() async {
      await expectLater(ApiService.getMyBookings(), throwsA(isA<ApiException>()));
      await expectLater(ApiService.getMyTripRequests(), throwsA(isA<ApiException>()));
      await expectLater(ApiService.getItinerary(42), throwsA(isA<ApiException>()));
    }, () => MockClient((_) async => http.Response('{"message":"Unavailable"}', 503)));
    await http.runWithClient(() async {
      expect(await ApiService.getMyBookings(), isEmpty);
      expect(await ApiService.getMyTripRequests(), isEmpty);
    }, () => MockClient((_) async => http.Response('[]', 200)));
  });

  test('Read mutations reject unsuccessful HTTP statuses', () async {
    await http.runWithClient(() async {
      await expectLater(ApiService.markNotificationRead('id'), throwsA(isA<ApiException>()));
      await expectLater(ApiService.markNotificationUnread('id'), throwsA(isA<ApiException>()));
      await expectLater(ApiService.markAllNotificationsRead(), throwsA(isA<ApiException>()));
    }, () => MockClient((_) async => http.Response('{"message":"Rejected"}', 500)));
  });

  test('Missing preferences use the documented empty response without a fallback endpoint', () async {
    final paths = <String>[];
    await http.runWithClient(() async {
      final response = await ApiService.getPreferences();
      expect(response.statusCode, 404);
    }, () => MockClient((request) async {
      paths.add(request.url.path);
      return http.Response('{"message":"Preferences not found"}', 404);
    }));
    expect(paths, ['/api/preference']);
  });

  testWidgets('Guard redirects a missing session to login', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'theme_mode': 'dark'});
    await tester.pumpWidget(MaterialApp(
      home: const AuthGuard(child: Scaffold(body: Text('Protected page'))),
      routes: {'/login': (_) => const Scaffold(body: Text('Login page'))},
    ));
    await tester.pumpAndSettle();
    expect(find.text('Login page'), findsOneWidget);
    expect(find.text('Protected page'), findsNothing);
  });

  testWidgets('Home avatar navigates to the registered profile route', (tester) async {
    ApiService.mockGetTours = ({String? search, String? sortBy}) async => [];
    await tester.pumpWidget(MaterialApp(
      home: const HomeScreen(),
      routes: {'/profile': (_) => const Scaffold(body: Text('Profile destination'))},
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TC'));
    await tester.pumpAndSettle();
    expect(find.text('Profile destination'), findsOneWidget);
  });

  testWidgets('Failed trip creation stays on form and retry navigates only after creation', (tester) async {
    ApiService.mockGetPreferences = () async => http.Response('', 404);
    ApiService.mockCreateTripRequest = (_) async => throw const ApiException('Trip creation failed');
    Object? arguments;
    await tester.pumpWidget(MaterialApp(
      home: const TripRequestScreen(),
      onGenerateRoute: (settings) {
        arguments = settings.arguments;
        return MaterialPageRoute(builder: (_) => const Scaffold(body: Text('Real itinerary destination')));
      },
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Generate AI Itinerary'));
    await tester.tap(find.text('Generate AI Itinerary'));
    await tester.pumpAndSettle();
    expect(arguments, isNull);
    expect(find.text('Trip creation failed'), findsOneWidget);
    ApiService.mockCreateTripRequest = (_) async => {'statusCode': 201, 'id': 57};
    await tester.ensureVisible(find.text('Retry'));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(arguments, {'tripRequestId': 57});
    expect(find.text('Real itinerary destination'), findsOneWidget);
  });

  testWidgets('Empty and failed notifications never become sample alerts', (tester) async {
    ApiService.mockGetMyNotifications = () async => throw const ApiException('Alerts unavailable');
    await tester.pumpWidget(const MaterialApp(home: NotificationsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Alerts unavailable'), findsOneWidget);
    ApiService.mockGetMyNotifications = () async => [];
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No notifications yet'), findsOneWidget);
    expect(find.text('Booking Confirmed'), findsNothing);
  });

  Map<String, dynamic> alert() => {
    'id': 'alert-1', 'status': 'Sent', 'content': 'Real alert',
    'messageType': 'TripUpdate', 'channel': 'InApp',
  };

  testWidgets('Failed mark-all-read restores unread state', (tester) async {
    ApiService.mockGetMyNotifications = () async => [alert()];
    ApiService.mockMarkAllNotificationsRead = () async => throw const ApiException('Read update failed');
    await tester.pumpWidget(const MaterialApp(home: NotificationsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();
    expect(find.text('1 new updates'), findsOneWidget);
    expect(find.text('Read update failed'), findsOneWidget);
    expect(find.text('All alerts marked as read.'), findsNothing);
  });

  testWidgets('Failed individual mark-read restores unread state', (tester) async {
    ApiService.mockGetMyNotifications = () async => [alert()];
    ApiService.mockMarkNotificationRead = (_) async => throw const ApiException('Individual update failed');
    await tester.pumpWidget(const MaterialApp(home: NotificationsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Real alert'));
    await tester.pumpAndSettle();
    expect(find.text('1 new updates'), findsOneWidget);
    expect(find.text('Mark as Read'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Individual update failed'), findsOneWidget);
  });

  testWidgets('History filters real numeric and string statuses', (tester) async {
    ApiService.mockGetMyTripRequests = () async => [
      {'id': 20, 'destinationName': 'Planning destination', 'status': 'Planning'},
    ];
    ApiService.mockGetMyBookings = () async => [
      {'id': 1, 'bookingReference': 'REAL-CONFIRMED', 'status': 2},
      {'id': 2, 'bookingReference': 'REAL-COMPLETED', 'status': 5},
      {'id': 3, 'bookingReference': 'REAL-CANCELLED', 'status': 'Cancelled'},
      {'id': 4, 'bookingReference': 'REAL-AWAITING', 'status': 'AwaitingApproval'},
    ];
    await tester.pumpWidget(const MaterialApp(home: TripHistoryScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Confirmed'), findsOneWidget);
    expect(find.text('AwaitingApproval'), findsOneWidget);
    expect(find.text('Planning'), findsOneWidget);
    expect(find.text('Booking REAL-COMPLETED'), findsNothing);
    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();
    expect(find.text('Booking REAL-COMPLETED'), findsOneWidget);
    expect(find.text('Booking REAL-CONFIRMED'), findsNothing);
    await tester.tap(find.text('Cancelled'));
    await tester.pumpAndSettle();
    expect(find.text('Booking REAL-CANCELLED'), findsOneWidget);
  });

  void mockProfile({double min = 75000, double max = 350000}) {
    ApiService.mockGetProfile = () async => {
      'statusCode': 200, 'fullName': 'Test Customer',
      'email': 'customer@example.com', 'phone': '0771234567',
    };
    ApiService.mockGetPreferences = () async => http.Response(jsonEncode({
      'budgetMin': min, 'budgetMax': max,
    }), 200);
  }

  testWidgets('Profile clamps reversed out-of-bounds budgets', (tester) async {
    mockProfile(min: 2000000, max: -100);
    await tester.pumpWidget(const MaterialApp(home: ProfilePreferencesScreen()));
    await tester.pumpAndSettle();
    final slider = tester.widget<RangeSlider>(find.byType(RangeSlider));
    expect(slider.values.start, 1000000);
    expect(slider.values.end, 1000000);
    expect(tester.takeException(), isNull);
  });

  for (final failedCall in ['profile', 'preferences']) {
    testWidgets('Failed $failedCall save cannot report success', (tester) async {
      mockProfile();
      var preferencesCalled = false;
      ApiService.mockUpdateProfile = (_) async => {'statusCode': failedCall == 'profile' ? 500 : 200};
      ApiService.mockUpdatePreferences = (_) async {
        preferencesCalled = true;
        return http.Response('', 500);
      };
      await tester.pumpWidget(const MaterialApp(home: ProfilePreferencesScreen()));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save Travel Preferences'));
      await tester.tap(find.text('Save Travel Preferences'));
      await tester.pumpAndSettle();
      expect(preferencesCalled, failedCall == 'preferences');
      expect(find.textContaining('saved successfully'), findsNothing);
      expect(find.textContaining('saved locally'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
    });
  }

  testWidgets('Profile validates name and ten-digit phone before saving', (tester) async {
    mockProfile();
    var saved = false;
    ApiService.mockUpdateProfile = (_) async { saved = true; return {'statusCode': 200}; };
    await tester.pumpWidget(const MaterialApp(home: ProfilePreferencesScreen()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Edit'));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '');
    await tester.enterText(find.byType(TextFormField).at(1), 'abcdefghij');
    await tester.tap(find.text('Save Details'));
    await tester.pumpAndSettle();
    expect(find.text('Full name is required'), findsOneWidget);
    expect(find.text('Only digits allowed'), findsOneWidget);
    expect(saved, isFalse);
  });
}
