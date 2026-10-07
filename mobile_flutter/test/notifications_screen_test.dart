import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/screens/profile/notifications_screen.dart';
import 'package:mobile_flutter/services/api_service.dart';

void main() {
  setUp(() {
    ApiService.mockGetMyNotifications = null;
    ApiService.mockMarkNotificationRead = null;
    ApiService.mockMarkNotificationUnread = null;
    ApiService.mockMarkAllNotificationsRead = null;
  });

  tearDown(() {
    ApiService.mockGetMyNotifications = null;
    ApiService.mockMarkNotificationRead = null;
    ApiService.mockMarkNotificationUnread = null;
    ApiService.mockMarkAllNotificationsRead = null;
  });

  Widget createTestWidget() {
    return const MaterialApp(home: NotificationsScreen());
  }

  testWidgets(
    'NotificationsScreen renders header, categories, and sample/live alerts',
    (WidgetTester tester) async {
      final testAlerts = [
        {
          'id': 'notif-1',
          'channel': 'SMS',
          'messageType': 'Reminder',
          'status': 'Sent',
          'content':
              'Serendib Trails: Chauffeur guide pickup confirmed for user. Contact: +94 77 123 4567.',
          'sentAt': '2026-09-29T10:00:00Z',
        },
        {
          'id': 'notif-2',
          'channel': 'InApp',
          'messageType': 'TripUpdate',
          'status': 'Read',
          'content': 'Day-by-day itinerary excursion details updated for user.',
          'sentAt': '2026-09-29T08:00:00Z',
          'readAt': '2026-09-29T09:00:00Z',
        },
        {
          'id': 'notif-3',
          'channel': 'Email',
          'messageType': 'BookingConfirmation',
          'status': 'Sent',
          'content':
              'Dear user, your bespoke Sri Lanka travel booking has been confirmed by Serendib Trails.',
          'sentAt': '2026-09-26T14:30:00Z',
        },
      ];

      ApiService.mockGetMyNotifications = () async => testAlerts;

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verify header title
      expect(find.text('Alerts'), findsOneWidget);
      // 2 are unread ('notif-1' and 'notif-3')
      expect(find.text('2 new updates'), findsOneWidget);

      // Verify filter categories
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Unread'), findsOneWidget);
      expect(find.text('Bookings'), findsOneWidget);
      expect(find.text('Payments'), findsOneWidget);
      expect(find.text('Info'), findsOneWidget);

      // Verify tags and titles
      expect(find.text('TRANSIT'), findsOneWidget);
      expect(find.text('AI TRIP'), findsOneWidget);
      expect(find.text('BOOKING'), findsOneWidget);

      // Verify multi-channel badges
      expect(find.text('SMS'), findsOneWidget);
      expect(find.text('In-App'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
    },
  );

  testWidgets('Filtering by Unread shows only unread alerts', (
    WidgetTester tester,
  ) async {
    final testAlerts = [
      {
        'id': 'notif-1',
        'channel': 'SMS',
        'messageType': 'Reminder',
        'status': 'Sent',
        'content': 'Transit alert',
        'sentAt': '2026-09-29T10:00:00Z',
      },
      {
        'id': 'notif-2',
        'channel': 'InApp',
        'messageType': 'TripUpdate',
        'status': 'Read',
        'content': 'Read itinerary update',
        'sentAt': '2026-09-29T08:00:00Z',
        'readAt': '2026-09-29T09:00:00Z',
      },
    ];

    ApiService.mockGetMyNotifications = () async => testAlerts;

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Both visible initially in 'All'
    expect(find.text('Transit alert'), findsOneWidget);
    expect(find.text('Read itinerary update'), findsOneWidget);

    // Tap 'Unread' filter
    await tester.tap(find.text('Unread'));
    await tester.pumpAndSettle();

    // Only unread remains
    expect(find.text('Transit alert'), findsOneWidget);
    expect(find.text('Read itinerary update'), findsNothing);
  });

  testWidgets('Mark all read button updates UI and calls ApiService', (
    WidgetTester tester,
  ) async {
    bool markAllCalled = false;
    ApiService.mockMarkAllNotificationsRead = () async {
      markAllCalled = true;
    };

    final testAlerts = [
      {
        'id': 'notif-1',
        'channel': 'SMS',
        'messageType': 'Reminder',
        'status': 'Sent',
        'content': 'Chauffeur pickup',
        'sentAt': '2026-09-29T10:00:00Z',
      },
    ];

    ApiService.mockGetMyNotifications = () async => testAlerts;

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('1 new updates'), findsOneWidget);

    // Tap "Mark all read" text button
    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();

    expect(markAllCalled, isTrue);
    expect(find.text('0 new updates'), findsOneWidget);
    expect(find.text('All alerts marked as read.'), findsOneWidget);
  });

  testWidgets(
    'Tapping alert opens bottom sheet modal with full details and toggle action',
    (WidgetTester tester) async {
      bool markReadCalled = false;
      ApiService.mockMarkNotificationRead = (id) async {
        markReadCalled = true;
      };

      final testAlerts = [
        {
          'id': 'notif-1',
          'channel': 'Email',
          'messageType': 'BookingConfirmation',
          'status': 'Sent',
          'content':
              'Booking Confirmed: Dear traveler, your booking ST-1003 is confirmed.',
          'sentAt': '2026-09-26T14:30:00Z',
        },
      ];

      ApiService.mockGetMyNotifications = () async => testAlerts;

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap on the card
      await tester.tap(find.text('Booking Confirmed'));
      await tester.pumpAndSettle();

      // Bottom sheet is displayed (text appears in both the background card and the foreground modal)
      expect(
        find.text('Dear traveler, your booking ST-1003 is confirmed.'),
        findsNWidgets(2),
      );
      expect(find.text('Close'), findsOneWidget);
      expect(markReadCalled, isTrue);

      // Close bottom sheet
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Close'), findsNothing);
    },
  );

  testWidgets('Notification load errors use a safe user-facing message', (
    WidgetTester tester,
  ) async {
    ApiService.mockGetMyNotifications = () async {
      throw StateError(
        'SqlException: SELECT * FROM Notifications; stack trace',
      );
    };

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong. Please retry.'), findsOneWidget);
    expect(find.textContaining('SqlException'), findsNothing);
    expect(find.textContaining('stack trace'), findsNothing);
  });

  testWidgets('Long notification content remains safe on a narrow screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    ApiService.mockGetMyNotifications = () async => [
      {
        'id': 'long-notification',
        'channel': 'InApp',
        'messageType': 'SystemAlert',
        'status': 'Sent',
        'content':
            'A very long travel notice title: ${'Detailed itinerary information ' * 40}',
        'sentAt': '2026-09-29T10:00:00Z',
      },
    ];

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('A very long travel notice title'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Supported references show guarded trip and booking actions while unknown references stay safe',
    (WidgetTester tester) async {
      ApiService.mockMarkNotificationRead = (id) async {};
      ApiService.mockGetMyNotifications = () async => [
        {
          'id': 'trip-ref',
          'channel': 'InApp',
          'messageType': 'TripPlanningReady',
          'status': 'Sent',
          'content': 'Trip ready: Your itinerary is ready to review.',
          'referenceType': 'TripRequest',
          'referenceId': '17',
          'sentAt': '2026-09-29T10:00:00Z',
        },
        {
          'id': 'booking-ref',
          'channel': 'InApp',
          'messageType': 'BookingConfirmed',
          'status': 'Sent',
          'content': 'Booking ready: Your booking is confirmed.',
          'referenceType': 'Booking',
          'referenceId': '42',
          'sentAt': '2026-09-29T09:00:00Z',
        },
        {
          'id': 'unknown-ref',
          'channel': 'InApp',
          'messageType': 'SystemAlert',
          'status': 'Sent',
          'content': 'Unknown reference: This should remain a detail only.',
          'referenceType': 'Hotel',
          'referenceId': '99',
          'sentAt': '2026-09-29T08:00:00Z',
        },
        {
          'id': 'missing-ref',
          'channel': 'InApp',
          'messageType': 'SystemAlert',
          'status': 'Sent',
          'content': 'Missing reference: This should remain a detail only.',
          'referenceType': 'Booking',
          'sentAt': '2026-09-29T07:00:00Z',
        },
      ];

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Trip ready'));
      await tester.pumpAndSettle();
      expect(find.text('View Trip'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Booking ready'));
      await tester.pumpAndSettle();
      expect(find.text('View Booking'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Unknown reference'));
      await tester.pumpAndSettle();
      expect(find.text('View Trip'), findsNothing);
      expect(find.text('View Booking'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
