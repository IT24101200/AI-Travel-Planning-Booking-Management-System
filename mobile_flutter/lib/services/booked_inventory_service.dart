/// Extracts paid inventory snapshots for the catalogue screens' Booked tabs.
///
/// Planned stays and transfers appear in the itinerary before payment. These
/// tabs intentionally describe paid bookings and keep every matching item.
class BookedInventoryService {
  /// Returns every room item belonging to a paid booking.
  static List<Map<String, dynamic>> paidRoomItems(List<dynamic> bookings) =>
      _paidItems(bookings, _isRoom);

  /// Returns every transport leg belonging to a paid booking.
  static List<Map<String, dynamic>> paidTransportItems(
    List<dynamic> bookings,
  ) => _paidItems(bookings, _isTransport);

  static List<Map<String, dynamic>> _paidItems(
    List<dynamic> bookings,
    bool Function(Map<String, dynamic>) matches,
  ) {
    final result = <Map<String, dynamic>>[];
    for (final rawBooking in bookings.whereType<Map>()) {
      final booking = Map<String, dynamic>.from(rawBooking);
      if (!_isPaid(booking)) continue;
      final items = booking['bookingItems'];
      if (items is! List) continue;
      for (final rawItem in items.whereType<Map>()) {
        final item = Map<String, dynamic>.from(rawItem);
        if (!matches(item)) continue;
        result.add({
          ...item,
          'bookingReference': booking['bookingReference'],
          'bookingStatus': booking['status'],
          'tripStartDate': booking['startDate'],
          'tripEndDate': booking['endDate'],
        });
      }
    }
    return result;
  }

  static bool _isPaid(Map<String, dynamic> booking) {
    if (booking['paymentStatus']?.toString().toLowerCase() == 'paid') {
      return true;
    }
    final payments = booking['payments'];
    return payments is List &&
        payments.whereType<Map>().any(
          (payment) =>
              payment['status']?.toString().toLowerCase() == 'paid' ||
              payment['status'] == 1,
        );
  }

  static bool _isRoom(Map<String, dynamic> item) {
    final type = item['itemType'];
    final normalized = type?.toString().toLowerCase();
    return type == 1 ||
        normalized == 'room' ||
        normalized == 'hotel' ||
        item['hotelName'] != null;
  }

  static bool _isTransport(Map<String, dynamic> item) {
    final type = item['itemType'];
    final normalized = type?.toString().toLowerCase();
    return type == 2 ||
        normalized == 'transport' ||
        item['transportType'] != null;
  }
}
