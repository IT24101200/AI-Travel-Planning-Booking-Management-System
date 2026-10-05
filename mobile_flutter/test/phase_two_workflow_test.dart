import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/screens/auth/login_screen.dart';
import 'package:mobile_flutter/screens/booking/booking_status_screen.dart';
import 'package:mobile_flutter/screens/booking/checkout_payment_screen.dart';
import 'package:mobile_flutter/screens/booking/trip_confirmation_screen.dart';
import 'package:mobile_flutter/services/api_service.dart';
import 'package:mobile_flutter/services/ticket_pdf_service.dart';
import 'package:mobile_flutter/services/trip_selection_service.dart';
import 'package:qr_flutter/qr_flutter.dart';

Widget wrapWithArgs(Widget screen, {Object? args, Map<String, WidgetBuilder>? additionalRoutes}) {
  return MaterialApp(
    onGenerateRoute: (settings) {
      if (additionalRoutes != null && additionalRoutes.containsKey(settings.name)) {
        return MaterialPageRoute(
          settings: settings,
          builder: additionalRoutes[settings.name]!,
        );
      }
      return MaterialPageRoute(
        settings: RouteSettings(name: '/', arguments: args),
        builder: (_) => screen,
      );
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'jwt_token': 'test-token',
      'user_id': 'user-1',
      'user_name': 'Maya Fernando',
    });
    TripSelectionService.clear();
  });

  tearDown(() {
    ApiService.mockGetBooking = null;
    ApiService.mockCreateBooking = null;
    ApiService.mockCreatePayment = null;
    ApiService.mockLogin = null;
    TripSelectionService.clear();
  });

  group('TicketPdfService & TripSelectionService Unit Tests', () {
    test('generateTicketPdf returns valid PDF 1.4 document bytes', () {
      final pdfBytes = TicketPdfService.generateTicketPdf(
        bookingReference: 'ST-2026-99999',
        customerName: 'Test Traveler',
        destination: 'Sigiriya Cultural Expedition',
        dates: '10-15 Oct 2026',
        stops: 'Sigiriya, Dambulla',
        hotelName: 'Heritance Kandalama',
        transportTitle: 'Private AC Van',
        totalCost: 1500.0,
        currency: 'USD',
      );

      expect(pdfBytes, isNotEmpty);
      final pdfString = utf8.decode(pdfBytes, allowMalformed: true);
      // Valid PDF document starts with %PDF-1.4
      expect(pdfString.startsWith('%PDF-1.4'), isTrue);
      // Contains trailer and EOF marker
      expect(pdfString.contains('%%EOF'), isTrue);
      // Contains trip details
      expect(pdfString.contains('ST-2026-99999'), isTrue);
      expect(pdfString.contains('Test Traveler'), isTrue);
      expect(pdfString.contains('Heritance Kandalama'), isTrue);
    });

    test('TripSelectionService correctly maintains selections', () {
      expect(TripSelectionService.selectedHotel, isNull);
      expect(TripSelectionService.selectedTransport, isNull);
      expect(TripSelectionService.activeBookingId, isNull);

      TripSelectionService.selectedHotel = {'id': 1, 'name': 'Cinnamon Lodge'};
      TripSelectionService.selectedTransport = {'id': 2, 'type': 'Train', 'name': 'Scenic Express'};
      TripSelectionService.activeBookingId = 42;

      expect(TripSelectionService.selectedHotel!['name'], 'Cinnamon Lodge');
      expect(TripSelectionService.selectedTransport!['name'], 'Scenic Express');
      expect(TripSelectionService.activeBookingId, 42);

      TripSelectionService.clear();
      expect(TripSelectionService.selectedHotel, isNull);
      expect(TripSelectionService.selectedTransport, isNull);
      expect(TripSelectionService.activeBookingId, isNull);
    });
  });

  group('BookingStatusScreen Widget Tests', () {
    testWidgets('QR code is hidden during AwaitingApproval and pending notice is shown', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      ApiService.mockGetBooking = (id) async => {
        'id': 105,
        'bookingReference': 'ST-2026-105',
        'destination': 'Ella Adventure',
        'status': 1, // AwaitingApproval
        'bookingStatus': 'AwaitingApproval',
        'totalCost': 1200.0,
        'currency': 'USD',
      };

      await tester.pumpWidget(wrapWithArgs(const BookingStatusScreen(), args: 105));
      await tester.pumpAndSettle();

      // Status hero and ticket pending notice
      expect(find.text('AWAITING AGENT APPROVAL'), findsOneWidget);
      expect(find.text('DIGITAL TICKET PENDING'), findsOneWidget);
      // QrImageView must NOT be rendered when status is AwaitingApproval
      expect(find.byType(QrImageView), findsNothing);
    });

    testWidgets('QR pass is displayed only when Confirmed and Paid', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      ApiService.mockGetBooking = (id) async => {
        'id': 106,
        'bookingReference': 'ST-2026-106',
        'destination': 'Ella Adventure',
        'status': 2, // Confirmed
        'bookingStatus': 'Confirmed',
        'paymentStatus': 'Paid',
        'totalCost': 1200.0,
        'currency': 'USD',
      };

      await tester.pumpWidget(wrapWithArgs(const BookingStatusScreen(), args: 106));
      await tester.pumpAndSettle();

      // Confirmed and paid badge, ticket header, and QrImageView
      expect(find.text('BOOKING CONFIRMED'), findsOneWidget);
      expect(find.text('YOUR DIGITAL TICKET'), findsOneWidget);
      expect(find.text('Pay Now with Stripe'), findsNothing);
      expect(find.byType(QrImageView), findsOneWidget);

      // Tap Cancel Booking button
      final cancelBtn = find.text('Cancel Booking');
      expect(cancelBtn, findsOneWidget);
      await tester.ensureVisible(cancelBtn);
      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();

      // Should show real cancellation/support dialog, NOT fake refund snackbar
      expect(find.text('Booking Cancellation'), findsOneWidget);
      expect(find.textContaining('support@serendibtrails.com'), findsOneWidget);
    });

    testWidgets('Confirmed but unpaid booking has no QR ticket', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final booking = <dynamic, dynamic>{
        'id': 109,
        'bookingReference': 'ST-2026-109',
        'destination': 'Ella Adventure',
        'status': 2,
        'bookingStatus': 'Confirmed',
        'totalCost': 1200.0,
        'currency': 'USD',
      };

      await tester.pumpWidget(wrapWithArgs(const BookingStatusScreen(), args: booking));
      await tester.pumpAndSettle();

      expect(find.text('Pay Now with Stripe'), findsOneWidget);
      expect(find.text('YOUR DIGITAL TICKET'), findsNothing);
      expect(find.byType(QrImageView), findsNothing);
    });

    testWidgets('Pay Now with Stripe button navigates to Checkout for unpaid confirmed booking', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool navigatedToCheckout = false;
      final rawMap = <dynamic, dynamic>{
        'id': 107,
        'bookingReference': 'ST-2026-107',
        'destination': 'Mirissa Coastal Getaway',
        'status': 2, // Confirmed
        'bookingStatus': 'Confirmed',
        'totalCost': 950.0,
        'currency': 'USD',
      };

      await tester.pumpWidget(wrapWithArgs(
        const BookingStatusScreen(),
        args: rawMap,
        additionalRoutes: {
          '/checkout': (context) {
            navigatedToCheckout = true;
            return const Scaffold(body: Text('Mock Checkout Screen'));
          },
        },
      ));
      await tester.pumpAndSettle();

      expect(find.text('BOOKING CONFIRMED'), findsOneWidget);
      final payBtn = find.text('Pay Now with Stripe');
      expect(payBtn, findsOneWidget);
      await tester.ensureVisible(payBtn);
      await tester.tap(payBtn);
      await tester.pumpAndSettle();

      expect(navigatedToCheckout, isTrue);
      expect(find.text('Mock Checkout Screen'), findsOneWidget);
    });

    testWidgets('Paid confirmed booking shows View Confirmation without Pay Now button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final paidBooking = <dynamic, dynamic>{
        'id': 108,
        'bookingReference': 'ST-2026-108',
        'destination': 'Mirissa Coastal Getaway',
        'status': 2,
        'paymentStatus': 'Paid',
        'totalCost': 950.0,
        'currency': 'USD',
      };

      await tester.pumpWidget(wrapWithArgs(const BookingStatusScreen(), args: paidBooking));
      await tester.pumpAndSettle();

      expect(find.text('BOOKING CONFIRMED'), findsOneWidget);
      expect(find.text('View Confirmation'), findsOneWidget);
      expect(find.text('Pay Now with Stripe'), findsNothing);
    });
  });

  group('CheckoutPaymentScreen Widget Tests', () {
    testWidgets('Blocks payment when booking is awaiting approval and unlocks on approval', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final bookingData = {
        'id': 201,
        'bookingReference': 'ST-2026-201',
        'destination': 'Hill Country Trek',
        'status': 1, // AwaitingApproval
        'bookingStatus': 'AwaitingApproval',
        'totalCost': 980.0,
      };

      await tester.pumpWidget(wrapWithArgs(const CheckoutPaymentScreen(), args: bookingData));
      await tester.pumpAndSettle();

      // Shows awaiting approval banner
      expect(find.text('Awaiting Agent Approval'), findsOneWidget);
      expect(find.text('Payment Locked (Awaiting Approval)'), findsOneWidget);

      // Confirm & Pay button is disabled
      final elevatedBtn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Payment Locked (Awaiting Approval)'),
      );
      expect(elevatedBtn.onPressed, isNull);

      // Tap student demo simulate approval
      await tester.tap(find.text('Simulate Approval'));
      await tester.pumpAndSettle();

      // Payment is now unlocked
      expect(find.text('Confirm & Pay \$980'), findsOneWidget);
    });

    testWidgets('Simulated decline keeps user on checkout screen with error message', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final bookingData = {
        'id': 202,
        'bookingReference': 'ST-2026-202',
        'destination': 'Hill Country Trek',
        'status': 2, // Confirmed
        'bookingStatus': 'Confirmed',
        'totalCost': 980.0,
      };

      ApiService.mockCreatePayment = (payload) async => {
        'statusCode': 400,
        'status': 'Failed',
        'message': 'Your card was declined by the issuer.',
      };

      await tester.pumpWidget(wrapWithArgs(const CheckoutPaymentScreen(), args: bookingData));
      await tester.pumpAndSettle();

      // Find the card number input
      final cardField = find.widgetWithText(TextField, '4242 4242 4242 4242').first;
      await tester.enterText(cardField, '4242 4242 4242 0002');
      await tester.pumpAndSettle();

      // Tap Confirm & Pay
      final payBtn = find.text('Confirm & Pay \$980');
      await tester.ensureVisible(payBtn);
      await tester.tap(payBtn);
      await tester.pumpAndSettle();

      // User must STAY on checkout and error banner is shown
      expect(find.text('Checkout'), findsOneWidget);
      expect(find.textContaining('declined'), findsWidgets);
    });

    testWidgets('Successful payment navigates to TripConfirmationScreen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final bookingData = {
        'id': 203,
        'bookingReference': 'ST-2026-203',
        'destination': 'Hill Country Trek',
        'status': 2, // Confirmed
        'bookingStatus': 'Confirmed',
        'totalCost': 980.0,
      };

      ApiService.mockCreatePayment = (payload) async => {
        'statusCode': 200,
        'id': 888,
        'status': 'Paid',
        'stripeReference': 'pi_test_success',
      };

      await tester.pumpWidget(wrapWithArgs(
        const CheckoutPaymentScreen(),
        args: bookingData,
        additionalRoutes: {
          '/trip-confirmation': (_) => const TripConfirmationScreen(),
        },
      ));
      await tester.pumpAndSettle();

      // Card default is 4242 4242 4242 4242 (valid)
      final payBtn = find.text('Confirm & Pay \$980');
      await tester.ensureVisible(payBtn);
      await tester.tap(payBtn);
      await tester.pumpAndSettle();

      // Successfully navigated to Trip Confirmation!
      expect(find.text('Booking Confirmed!'), findsOneWidget);
    });
  });

  group('TripConfirmationScreen & LoginScreen Tests', () {
    testWidgets('TripConfirmationScreen reflects dynamic recap and clipboard copy on Share Trip', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      TripSelectionService.selectedHotel = {
        'id': 5,
        'name': 'Aliya Resort & Spa',
      };
      TripSelectionService.selectedTransport = {
        'id': 9,
        'name': 'Luxury Electric Van',
        'route': 'Sigiriya - Kandy',
      };

      final bookingData = {
        'id': 301,
        'bookingReference': 'ST-2026-301',
        'destination': 'Cultural Triangle Tour',
        'customerName': 'Maya Fernando',
        'dates': '14–20 Oct 2026',
        'status': 'Confirmed',
        'paymentStatus': 'Paid',
      };

      await tester.pumpWidget(wrapWithArgs(const TripConfirmationScreen(), args: bookingData));
      await tester.pumpAndSettle();

      // Booking reference
      expect(find.text('ST-2026-301'), findsOneWidget);
      // Dynamic hotel and transport from TripSelectionService
      expect(find.text('Aliya Resort & Spa'), findsOneWidget);
      expect(find.textContaining('Luxury Electric Van'), findsOneWidget);

      // Tap Share Trip
      final shareBtn = find.text('Share Trip');
      await tester.ensureVisible(shareBtn);
      await tester.tap(shareBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Trip itinerary copied to clipboard!'), findsOneWidget);
    });

    testWidgets('TripConfirmationScreen generates ticket PDF on Download PDF tap', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final bookingData = {
        'id': 302,
        'bookingReference': 'ST-2026-302',
        'destination': 'Cultural Triangle Tour',
        'customerName': 'Maya Fernando',
        'dates': '14–20 Oct 2026',
        'status': 'Confirmed',
        'paymentStatus': 'Paid',
      };

      await tester.pumpWidget(wrapWithArgs(const TripConfirmationScreen(), args: bookingData));
      await tester.pumpAndSettle();

      // Tap Download PDF
      final downloadBtn = find.text('Download PDF');
      await tester.ensureVisible(downloadBtn);
      await tester.tap(downloadBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.textContaining('Ticket PDF generated'), findsOneWidget);
    });

    testWidgets('LoginScreen forgot password shows support contact dialog', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: LoginScreen()),
      ));

      await tester.pumpAndSettle();

      final forgotBtn = find.text('Forgot password?');
      expect(forgotBtn, findsOneWidget);
      await tester.ensureVisible(forgotBtn);
      await tester.tap(forgotBtn);
      await tester.pumpAndSettle();

      // Confirms support dialog opens, NOT a false email snackbar
      expect(find.text('Password Recovery'), findsOneWidget);
      expect(find.textContaining('support@serendibtrails.lk'), findsOneWidget);

      await tester.tap(find.text('Understood'));
      await tester.pumpAndSettle();
      expect(find.text('Password Recovery'), findsNothing);
    });
  });
}
