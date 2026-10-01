import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_constants.dart';
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
import 'screens/profile/profile_preferences_screen.dart';
import 'screens/profile/trip_request_screen.dart';
import 'screens/profile/trip_history_screen.dart';
import 'screens/profile/notifications_screen.dart';
import 'widgets/auth_guard.dart';

void main() {
  runApp(const TravelApp());
}

/// Root widget for Serendib Trails — AI Travel Planner.
/// Natural Sri Lankan color palette: Jungle Green, Ocean Teal, Temple Gold, Ivory.
class TravelApp extends StatelessWidget {
  const TravelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Serendib Trails',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.ivory,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.jungle600,
          primary: AppColors.jungle600,
          secondary: AppColors.sand500,
          surface: AppColors.paper,
          surfaceContainerLowest: AppColors.ivory,
          error: AppColors.coral500,
        ),
        textTheme: GoogleFonts.poppinsTextTheme().apply(
          bodyColor: AppColors.ink2,
          displayColor: AppColors.ink,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.jungle800,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: -0.2,
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.jungle600,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.jungle600, width: 1.8),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          hintStyle: const TextStyle(color: AppColors.ink3, fontSize: 14),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1.5,
          shadowColor: Colors.black.withValues(alpha: 0.06),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.line, width: 0.8),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        ),
      ),
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
        '/accommodation': (context) => const AuthGuard(child: AccommodationOptionsScreen()),
        '/transport': (context) => const AuthGuard(child: TransportOptionsScreen()),
        '/trip-map': (context) => const AuthGuard(child: TripMapScreen()),
        '/checkout': (context) => const AuthGuard(child: CheckoutPaymentScreen()),
        '/booking-status': (context) => const AuthGuard(child: BookingStatusScreen()),
        '/trip-confirmation': (context) => const AuthGuard(child: TripConfirmationScreen()),
        '/profile': (context) => const AuthGuard(child: ProfilePreferencesScreen()),
        '/trip-request': (context) => const AuthGuard(child: TripRequestScreen()),
        '/trip-history': (context) => const AuthGuard(child: TripHistoryScreen()),
        '/notifications': (context) => const AuthGuard(child: NotificationsScreen()),
      },
    );
  }
}
