import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/services/hotel_catalog_service.dart';

void main() {
  test(
    'reads cheapest published room rate and retains hotel GPS and currency',
    () {
      final hotel = HotelCatalogService.displayStay({
        'id': 100, 'name': 'Property', 'address': 'Street, Galle',
        'latitude': 6.04, 'longitude': 80.19,
        'pricePerNight': 999, // obsolete hotel-level field must not win
        'rooms': [
          {'roomType': 'Suite', 'pricePerNight': 28573, 'currency': 'LKR'},
          {'roomType': 'Crayford', 'pricePerNight': 21430, 'currency': 'LKR'},
          {'roomType': 'Unquoted', 'pricePerNight': 0, 'currency': 'LKR'},
        ],
      });
      expect(hotel['price'], 21430);
      expect(hotel['currency'], 'LKR');
      expect(hotel['roomType'], 'Crayford');
      expect(hotel['latitude'], 6.04);
      expect(hotel['longitude'], 80.19);
      expect(hotel['location'], 'Street, Galle');
    },
  );

  test('does not manufacture rates when no priced room exists', () {
    expect(
      HotelCatalogService.displayStay({'id': 2, 'rooms': []})['price'],
      isNull,
    );
  });
}
