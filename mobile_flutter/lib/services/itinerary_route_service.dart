import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'api_service.dart';

class ItineraryRouteStop {
  const ItineraryRouteStop(this.item, this.point);
  final Map<String, dynamic> item;
  final LatLng point;
}

class ItineraryRoadRoute {
  const ItineraryRoadRoute(
    this.stops,
    this.points,
    this.distanceMeters, {
    this.missingStops = const [],
    this.dayRoutes = const {},
    this.hotelPoints = const [],
    this.airportPoints = const [],
  });
  final List<ItineraryRouteStop> stops;
  final List<LatLng> points;
  final double distanceMeters;
  final List<String> missingStops;
  final Map<int, List<LatLng>> dayRoutes;
  final List<LatLng> hotelPoints;
  final List<LatLng> airportPoints;
}

class ItineraryRouteService {
  static const _routingBase = String.fromEnvironment(
    'ROUTING_BASE_URL',
    defaultValue: 'https://router.project-osrm.org',
  );
  static final _cache = <String, ItineraryRoadRoute>{};

  static LatLng? coordinates(Map data) {
    final lat = double.tryParse('${data['latitude']}');
    final lon = double.tryParse('${data['longitude']}');
    if (lat == null ||
        lon == null ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat.abs() > 90 ||
        lon.abs() > 180 ||
        (lat == 0 && lon == 0)) {
      return null;
    }
    return LatLng(lat, lon);
  }

  static List<Map<String, dynamic>> orderedItems(Map itinerary) {
    final raw = itinerary['items'];
    if (raw is! List) return [];
    final items = raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    int number(dynamic value) => int.tryParse('$value') ?? 0;
    items.sort((a, b) {
      final day = number(a['dayNumber']).compareTo(number(b['dayNumber']));
      if (day != 0) return day;
      final sequence = number(
        a['sequenceOrder'],
      ).compareTo(number(b['sequenceOrder']));
      if (sequence != 0) return sequence;
      return '${a['startTime']}'.compareTo('${b['startTime']}');
    });
    return items;
  }

  static Future<ItineraryRoadRoute> load(
    Map itinerary, {
    http.Client? client,
  }) async {
    final items = orderedItems(itinerary);
    if (items.isEmpty) {
      throw const ApiException('This itinerary has no map stops yet.');
    }
    final tours = <int, Map<String, dynamic>?>{};
    final stops = <ItineraryRouteStop>[];
    final missingStops = <String>[];
    for (final item in items) {
      var point = coordinates(item);
      if (point == null) {
        final id = int.tryParse('${item['tourId']}');
        if (id != null && id > 0) {
          if (!tours.containsKey(id)) {
            tours[id] = await ApiService.getTour(
              id,
            ).timeout(const Duration(seconds: 15));
          }
          final tour = tours[id];
          if (tour != null) point = coordinates(tour);
        }
      }
      if (point == null) {
        missingStops.add(item['tourName']?.toString() ?? 'Unnamed tour');
        continue;
      }
      stops.add(ItineraryRouteStop(item, point));
    }
    final travelSchedule = itinerary['travelSchedule'];
    if (travelSchedule is List) {
      final dayRoutes = <int, List<LatLng>>{};
      final hotels = <LatLng>{};
      final airports = <LatLng>{};
      final allPoints = <LatLng>[];
      double distance = 0;
      for (final day in travelSchedule.whereType<Map>()) {
        final dayNumber = int.tryParse('${day['day_number']}');
        final legs = day['travel_legs'];
        if (dayNumber == null || legs is! List) continue;
        final waypoints = <LatLng>[];
        for (final leg in legs.whereType<Map>()) {
          for (final endpoint in [leg['from'], leg['to']]) {
            if (endpoint is! Map) continue;
            final p = coordinates(endpoint);
            if (p == null) {
              throw const ApiException(
                'A planned travel leg has missing GPS coordinates.',
              );
            }
            if (endpoint['kind'] == 'hotel') hotels.add(p);
            if (endpoint['kind'] == 'airport') airports.add(p);
            if (waypoints.isEmpty || waypoints.last != p) waypoints.add(p);
          }
        }
        final road = await _cachedRoadRoute(waypoints, client: client);
        dayRoutes[dayNumber] = road.points;
        allPoints.addAll(road.points);
        distance += road.distanceMeters;
      }
      if (stops.isEmpty) {
        throw const ApiException('This itinerary has no map stops yet.');
      }
      return ItineraryRoadRoute(
        stops,
        allPoints,
        distance,
        missingStops: missingStops,
        dayRoutes: dayRoutes,
        hotelPoints: hotels.toList(),
        airportPoints: airports.toList(),
      );
    }
    // Remove only consecutive duplicates; preserve return visits and stop order.
    final waypoints = <LatLng>[];
    for (final stop in stops) {
      if (waypoints.isEmpty || waypoints.last != stop.point) {
        waypoints.add(stop.point);
      }
    }
    if (stops.isEmpty) {
      throw ApiException(
        'Add tour GPS coordinates to show directions: ${missingStops.toSet().join(', ')}.',
      );
    }
    if (waypoints.length < 2) {
      return ItineraryRoadRoute(
        stops,
        waypoints,
        0,
        missingStops: missingStops,
      );
    }
    final key = waypoints.map((p) => '${p.longitude},${p.latitude}').join(';');
    final cached = _cache[key];
    if (cached != null) {
      return ItineraryRoadRoute(
        stops,
        cached.points,
        cached.distanceMeters,
        missingStops: missingStops,
      );
    }
    final route = await fetchRoadRoute(waypoints, client: client);
    final result = ItineraryRoadRoute(
      stops,
      route.points,
      route.distanceMeters,
      missingStops: missingStops,
    );
    if (_cache.length >= 20) _cache.remove(_cache.keys.first);
    _cache[key] = result;
    return result;
  }

  static Future<ItineraryRoadRoute> _cachedRoadRoute(
    List<LatLng> points, {
    http.Client? client,
  }) async {
    if (points.length < 2) return ItineraryRoadRoute([], points, 0);
    final key = points.map((p) => '${p.longitude},${p.latitude}').join(';');
    if (_cache.containsKey(key)) return _cache[key]!;
    final route = await fetchRoadRoute(points, client: client);
    if (_cache.length >= 20) _cache.remove(_cache.keys.first);
    return _cache[key] = route;
  }

  static Future<ItineraryRoadRoute> fetchRoadRoute(
    List<LatLng> points, {
    http.Client? client,
  }) async {
    final coordinates = points
        .map((p) => '${p.longitude},${p.latitude}')
        .join(';');
    final uri = Uri.parse(
      '${_routingBase.replaceFirst(RegExp(r'/+$'), '')}/route/v1/driving/$coordinates',
    ).replace(queryParameters: {'overview': 'full', 'geometries': 'geojson'});
    final ownedClient = client ?? http.Client();
    try {
      final response = await ownedClient
          .get(uri)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw const ApiException(
          'Road directions are unavailable. Please retry.',
        );
      }
      final body = jsonDecode(response.body);
      if (body['code'] != 'Ok' ||
          body['routes'] is! List ||
          (body['routes'] as List).isEmpty) {
        throw const ApiException(
          'No driving route was found between these stops.',
        );
      }
      final route = body['routes'][0];
      final raw = route['geometry']['coordinates'] as List;
      final geometry = raw
          .map(
            (p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()),
          )
          .toList();
      if (geometry.length < 2) {
        throw const ApiException(
          'Road directions are unavailable. Please retry.',
        );
      }
      return ItineraryRoadRoute(
        [],
        geometry,
        (route['distance'] as num).toDouble(),
      );
    } finally {
      if (client == null) ownedClient.close();
    }
  }
}
