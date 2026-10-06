import 'package:latlong2/latlong.dart';

/// Keeps hotel, vehicle, itinerary and booking choices consistent across screens.

class TripSelectionService {
  // Currently selected hotel or resort from AccommodationOptionsScreen
  static Map<String, dynamic>? selectedHotel;
  static LatLng? hotelDirectionsOrigin;
  static String? hotelDirectionsOriginLabel;

  // Currently selected vehicle or transfer from TransportOptionsScreen
  static Map<String, dynamic>? selectedTransport;

  // Active itinerary loaded or selected from MyItineraryScreen
  static Map<String, dynamic>? activeItinerary;

  // Active booking ID to pass forward to Checkout, Status, and Confirmation
  static int? activeBookingId;

  /// Resets all in-memory selections
  static void reset() {
    selectedHotel = null;
    hotelDirectionsOrigin = null;
    hotelDirectionsOriginLabel = null;
    selectedTransport = null;
    activeItinerary = null;
    activeBookingId = null;
  }

  /// Alias for reset
  static void clear() => reset();
}
