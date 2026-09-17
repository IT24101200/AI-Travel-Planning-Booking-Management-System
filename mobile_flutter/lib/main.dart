import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/api_service.dart';
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
import 'screens/profile/profile_preferences_screen.dart';
import 'screens/profile/trip_request_screen.dart';
import 'screens/profile/trip_history_screen.dart';
import 'screens/profile/notifications_screen.dart';

void main() {
  runApp(const TravelApp());
}

/// Root widget for the AI Travel Planning app.
/// Uses Figma-inspired color palette: Teal (Evergreen) primary, Iris accent.
class TravelApp extends StatelessWidget {
  const TravelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Travel Planner',
      debugShowCheckedModeBanner: false,
      // Theme inspired by Figma design system colors
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D9488), // Evergreen teal
          primary: const Color(0xFF0D9488),
          secondary: const Color(0xFF7C5CFC), // Iris purple
          surface: Colors.white,
          error: Colors.red.shade600,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF0D9488),
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D9488),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        ),
      ),
      // Auth guard — check for saved token
      home: const AuthGate(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/tour-search': (context) => const TourSearchBrowseScreen(),
        '/tour-details': (context) => const TourDetailsScreen(),
        '/itinerary': (context) => const MyItineraryScreen(),
        '/accommodation': (context) => const AccommodationOptionsScreen(),
        '/transport': (context) => const TransportOptionsScreen(),
        '/trip-map': (context) => const TripMapScreen(),
        '/checkout': (context) => const CheckoutPaymentScreen(),
        '/booking-status': (context) => const BookingStatusScreen(),
        '/trip-confirmation': (context) => const TripConfirmationScreen(),
        '/profile': (context) => const ProfilePreferencesScreen(),
        '/trip-request': (context) => const TripRequestScreen(),
        '/trip-history': (context) => const TripHistoryScreen(),
        '/notifications': (context) => const NotificationsScreen(),
      },
    );
  }
}

/// Checks if user is already logged in, redirects accordingly.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final loggedIn = await ApiService.isLoggedIn();
    if (!mounted) return;
    if (loggedIn) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show splash while checking auth
    return Scaffold(
      backgroundColor: const Color(0xFF0D9488),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flight_takeoff, size: 64, color: Colors.white),
            const SizedBox(height: 16),
            Text(
              'AI Travel Planner',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
