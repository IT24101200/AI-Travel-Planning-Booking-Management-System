import 'package:latlong2/latlong.dart';

/// Keeps hotel, vehicle, itinerary and booking choices consistent across screens.
///
/// These in-memory preferences do not reserve inventory or change a persisted
/// package. Itinerary changes go through the backend revision workflow.
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
  // The itinerary that owns activeBookingId. This prevents a booking from a
  // previous trip leaking into a newly selected itinerary.
  static int? activeBookingItineraryId;

  static void setActiveBookingContext({
    required int itineraryId,
    required int bookingId,
  }) {
    activeBookingItineraryId = itineraryId;
    activeBookingId = bookingId;
  }

  /// Resets all in-memory selections.
  static void reset() {
    selectedHotel = null;
    hotelDirectionsOrigin = null;
    hotelDirectionsOriginLabel = null;
    selectedTransport = null;
    activeItinerary = null;
    activeBookingId = null;
    activeBookingItineraryId = null;
  }

  /// Clears selections through [reset].
  static void clear() => reset();
}
