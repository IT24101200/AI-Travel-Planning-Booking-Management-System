import 'package:flutter/material.dart';
import 'screens/landing_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/tours/tour_search_browse_screen.dart';
import 'screens/tours/tour_details_screen.dart';
import 'screens/tours/my_itinerary_screen.dart';
import 'screens/accommodation/accommodation_options_screen.dart';
import 'screens/accommodation/transport_options_screen.dart';
import 'screens/accommodation/trip_map_screen.dart';
import 'screens/booking/checkout_payment_screen.dart';
import 'screens/booking/booking_status_screen.dart';
import 'screens/booking/trip_confirmation_screen.dart';
import 'screens/profile/trip_request_screen.dart';
import 'widgets/auth_guard.dart';
import 'services/theme_notifier.dart';
import 'services/app_theme.dart';

/// Global theme notifier — any screen can read or change the theme mode.
final ThemeNotifier themeNotifier = ThemeNotifier();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Load saved theme preference (light/dark/system)
  themeNotifier.loadSavedTheme();
  runApp(const TravelApp());
}

/// Root widget for Serendib Trails — AI Travel Planner.
/// Supports Light, Dark, and System theme modes.
class TravelApp extends StatelessWidget {
  const TravelApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuilds MaterialApp whenever theme mode changes
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Serendib Trails',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: mode,
          // 1st page is the dynamic Landing Page
          home: const LandingScreen(),
          routes: {
            // Public routes
            '/landing': (context) => const LandingScreen(),
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),

            // Protected routes (Only signed-in travelers can view inside data)
            '/home': (context) => const AuthGuard(child: HomeScreen()),
            '/tour-search': (context) => const AuthGuard(child: TourSearchBrowseScreen()),
            '/tour-details': (context) => const AuthGuard(child: TourDetailsScreen()),
            '/itinerary': (context) => const AuthGuard(child: MyItineraryScreen()),
            '/my-itinerary': (context) => const AuthGuard(child: MyItineraryScreen()),
            '/accommodation': (context) => const AuthGuard(child: AccommodationOptionsScreen()),
            '/transport': (context) => const AuthGuard(child: TransportOptionsScreen()),
            '/trip-map': (context) => const AuthGuard(child: TripMapScreen()),
            '/checkout': (context) => const AuthGuard(child: CheckoutPaymentScreen()),
            '/booking-status': (context) => const AuthGuard(child: BookingStatusScreen()),
            '/trip-confirmation': (context) => const AuthGuard(child: TripConfirmationScreen()),
            '/profile': (context) => const AuthGuard(child: HomeScreen(initialIndex: 3)),
            '/trip-request': (context) => const AuthGuard(child: TripRequestScreen()),
            '/trip-history': (context) => const AuthGuard(child: HomeScreen(initialIndex: 1)),
            '/notifications': (context) => const AuthGuard(child: HomeScreen(initialIndex: 2)),
          },
        );
      },
    );
  }
}
