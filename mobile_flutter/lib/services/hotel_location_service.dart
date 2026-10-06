import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'api_service.dart';

class HotelLocationService {
  static Future<LatLng> currentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const ApiException(
        'Turn on location services, or pick a start on the map.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const ApiException(
        'Allow location in app settings, or pick a start on the map.',
      );
    }
    if (permission == LocationPermission.denied) {
      throw const ApiException(
        'Location permission was declined. You can still pick a start or an airport.',
      );
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    return LatLng(position.latitude, position.longitude);
  }
}
