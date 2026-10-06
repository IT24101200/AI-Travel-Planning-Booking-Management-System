import 'api_service.dart';

class HotelCatalogService {
  static Map<String, dynamic> displayStay(Map hotel) {
    final rooms =
        (hotel['rooms'] as List? ?? const [])
            .whereType<Map>()
            .where(
              (room) =>
                  double.tryParse('${room['pricePerNight']}') != null &&
                  double.parse('${room['pricePerNight']}') > 0,
            )
            .toList()
          ..sort(
            (a, b) => double.parse(
              '${a['pricePerNight']}',
            ).compareTo(double.parse('${b['pricePerNight']}')),
          );
    final room = rooms.isEmpty ? null : rooms.first;
    return {
      ...Map<String, dynamic>.from(hotel),
      'id': '${hotel['id']}',
      'name': hotel['name'] ?? 'Hotel',
      'location': hotel['address'] ?? 'Address not provided',
      'price': room?['pricePerNight'],
      'currency': room?['currency'],
      'roomType': room?['roomType'],
      'rateNotes': room?['rateNotes'],
      'rateSourceUrl': room?['rateSourceUrl'],
      'image': ApiService.resolveMediaUrl(hotel['imageUrl']?.toString()),
    };
  }
}
