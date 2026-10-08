import '../services/date_time_contract.dart';
import '../services/itinerary_route_service.dart';
import 'transport_leg_utils.dart';

List<Map<String, dynamic>> itineraryHotelStays(Map itinerary, Map? booking) {
  final raw = booking?['bookingItems'] ?? itinerary['bookingItems'];
  final rooms = raw is List
      ? raw
            .whereType<Map>()
            .where((item) {
              final type = '${item['itemType']}'.toLowerCase();
              return type == '1' ||
                  type == 'room' ||
                  type == 'hotel' ||
                  item['hotelName'] != null;
            })
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
      : <Map<String, dynamic>>[];
  if (rooms.isNotEmpty) return rooms;
  final planned = itinerary['hotelStays'];
  if (planned is! List) return [];
  return planned
      .whereType<Map>()
      .map(
        (stay) => <String, dynamic>{
          'id': 'planned-${stay['room_id']}-${stay['check_in']}',
          'hotelName': stay['hotel_name'],
          'hotelId': stay['hotel_id'],
          'hotelLatitude': stay['latitude'],
          'hotelLongitude': stay['longitude'],
          'roomType': stay['room_type'],
          'checkInDate': stay['check_in'],
          'checkOutDate': stay['check_out'],
          'isPlanned': true,
        },
      )
      .toList();
}

Map? itineraryTravelDay(Map itinerary, int dayNumber) {
  final schedule = itinerary['travelSchedule'];
  if (schedule is! List) return null;
  return schedule
      .whereType<Map>()
      .where((d) => '${d['day_number']}' == '$dayNumber')
      .firstOrNull;
}

/// Inserts dated hotel stops without altering persisted activities or pricing.
List<Map<String, dynamic>> itineraryFlowItems(Map itinerary, Map? booking) {
  final items = ItineraryRouteService.orderedItems(itinerary);
  final start = parseDateOnly(itinerary['startDate']);
  final end = parseDateOnly(itinerary['endDate']);
  if (start == null || end == null) return items;
  final stays = itineraryHotelStays(itinerary, booking);
  for (var index = 0; index < stays.length; index++) {
    final stay = stays[index];
    final checkIn = parseDateOnly(stay['checkInDate']);
    final checkOut = parseDateOnly(stay['checkOutDate']);
    if (checkIn == null || checkOut == null || !checkOut.isAfter(checkIn)) {
      continue;
    }
    void addStop(DateTime date, String kind) {
      if (date.isBefore(start) || date.isAfter(end)) return;
      final day = date.difference(start).inDays + 1;
      final travel = itineraryTravelDay(itinerary, day);
      final overnight = kind == 'overnight';
      items.add({
        'id': 'hotel-$index-$kind-${date.toIso8601String()}',
        'dayNumber': day,
        'sequenceOrder': overnight ? 100000 : -100000,
        'stopKind': kind,
        'hotelStay': stay,
        'tourName':
            '${overnight ? 'Overnight at' : 'Check out of'} ${stay['hotelName'] ?? 'Hotel'}',
        'startTime': overnight
            ? (travel?['day_end_time'])
            : (travel?['day_start_time']),
        'latitude': stay['hotelLatitude'],
        'longitude': stay['hotelLongitude'],
      });
    }

    for (
      var date = checkIn.isBefore(start) ? start : checkIn;
      date.isBefore(checkOut) && !date.isAfter(end);
      date = date.add(const Duration(days: 1))
    ) {
      addStop(date, 'overnight');
    }
    addStop(checkOut, 'checkout');
  }
  items.sort((a, b) {
    final day = (int.tryParse('${a['dayNumber']}') ?? 1).compareTo(
      int.tryParse('${b['dayNumber']}') ?? 1,
    );
    if (day != 0) return day;
    return (int.tryParse('${a['sequenceOrder']}') ?? 0).compareTo(
      int.tryParse('${b['sequenceOrder']}') ?? 0,
    );
  });
  return items;
}

List<Map<String, dynamic>> itineraryDayTransports(
  Map itinerary,
  Map? booking,
  int day,
) {
  final start = parseDateOnly(itinerary['startDate']);
  final raw = booking?['bookingItems'] ?? itinerary['bookingItems'];
  if (start == null || raw is! List) return [];
  final date = start.add(Duration(days: day - 1));
  return orderedTransportItems(
    raw,
  ).where((item) => parseDateOnly(item['departureTime']) == date).toList();
}

String itineraryDayDirection(Map itinerary, int day) {
  final legs = itineraryTravelDay(itinerary, day)?['travel_legs'];
  if (legs is! List) return '';
  final names = <String>[];
  for (final leg in legs.whereType<Map>()) {
    for (final endpoint in [leg['from'], leg['to']]) {
      final name = endpoint is Map ? endpoint['name']?.toString().trim() : null;
      if (name != null &&
          name.isNotEmpty &&
          (names.isEmpty || names.last != name)) {
        names.add(name);
      }
    }
  }
  return names.join(' → ');
}
