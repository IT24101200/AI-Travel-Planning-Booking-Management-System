import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Single HTTP client for all backend API calls.
/// Stores JWT token via flutter_secure_storage and attaches it to every request.
class ApiService {
  // ── Backend URLs ──
  // Web (Chrome): runs on localhost
  static const String _webUrl = 'http://localhost:5138/api';
  // Mobile (Physical phone / Emulator): PC's local Wi-Fi IP (192.168.1.4) or emulator 10.0.2.2
  static const String _mobileUrl = 'http://192.168.1.4:5138/api';

  static String get baseUrl {
    // When running in Chrome (Flutter Web):
    if (kIsWeb) {
      return _webUrl;
    }
    // When running on a physical Android phone (or change to 10.0.2.2 for emulator):
    return _mobileUrl;
  }

  /// Convert backend-relative media paths into URLs reachable by this client.
  static String resolveMediaUrl(String? path) {
    if (path == null || path.trim().isEmpty) return '';
    final value = path.trim();
    if (value.startsWith('http://') || value.startsWith('https://') || value.startsWith('assets/')) {
      return value;
    }
    final serverRoot = baseUrl.endsWith('/api')
        ? baseUrl.substring(0, baseUrl.length - 4)
        : baseUrl;
    return '$serverRoot/${value.replaceFirst(RegExp(r'^/+'), '')}';
  }

  static final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // ── Token management ──

  static Future<void> saveToken(String token) async {
    await _storage.write(key: 'jwt_token', value: token);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  static Future<void> saveUserId(String userId) async {
    await _storage.write(key: 'user_id', value: userId);
  }

  static Future<String?> getUserId() async {
    return await _storage.read(key: 'user_id');
  }

  static Future<void> saveUserName(String name) async {
    await _storage.write(key: 'user_name', value: name);
  }

  static Future<String?> getUserName() async {
    return await _storage.read(key: 'user_name');
  }

  static Future<void> logout() async {
    await _storage.deleteAll();
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ── HTTP helpers ──

  static Future<Map<String, String>> _headers() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static String _responseError(http.Response response, String fallback) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'] ?? decoded['title'] ?? decoded['error'];
        if (message != null && message.toString().trim().isNotEmpty) {
          return message.toString();
        }

        final errors = decoded['errors'];
        if (errors is Map) {
          final messages = errors.values
              .expand((value) => value is List ? value : [value])
              .map((value) => value.toString())
              .where((value) => value.trim().isNotEmpty)
              .toList();
          if (messages.isNotEmpty) return messages.join('\n');
        }
      }
    } catch (_) {
      // Use the supplied fallback when the server response is not JSON.
    }

    return '$fallback (${response.statusCode})';
  }

  /// Generic GET request
  static Future<http.Response> get(String endpoint) async {
    final headers = await _headers();
    return await http.get(Uri.parse('$baseUrl/$endpoint'), headers: headers);
  }

  /// Generic POST request
  static Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    final headers = await _headers();
    return await http.post(
      Uri.parse('$baseUrl/$endpoint'),
      headers: headers,
      body: jsonEncode(body),
    );
  }

  /// Generic PUT request
  static Future<http.Response> put(String endpoint, Map<String, dynamic> body) async {
    final headers = await _headers();
    return await http.put(
      Uri.parse('$baseUrl/$endpoint'),
      headers: headers,
      body: jsonEncode(body),
    );
  }

  /// Generic PATCH request
  static Future<http.Response> patch(String endpoint, Map<String, dynamic> body) async {
    final headers = await _headers();
    return await http.patch(
      Uri.parse('$baseUrl/$endpoint'),
      headers: headers,
      body: jsonEncode(body),
    );
  }

  // ── Auth endpoints ──

  /// Register a new customer account
  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    final response = await post('auth/register', {
      'email': email,
      'password': password,
      'fullName': fullName,
      'phone': phone,
    });

    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      // Save token and user info on successful registration
      await saveToken(data['token']);
      await saveUserId(data['userId']);
      await saveUserName(data['fullName']);
    }
    return {'statusCode': response.statusCode, ...data};
  }

  /// Login with email and password
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await post('auth/login', {
      'email': email,
      'password': password,
    });

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      await saveToken(data['token']);
      await saveUserId(data['userId']);
      await saveUserName(data['fullName'] ?? '');
    }
    return {'statusCode': response.statusCode, ...data};
  }

  // Optional mock delegates for unit and widget tests
  static Future<Map<String, dynamic>> Function()? mockGetProfile;
  static Future<http.Response> Function()? mockGetPreferences;

  static Future<Map<String, dynamic>> getProfile() async {
    if (mockGetProfile != null) {
      return await mockGetProfile!();
    }
    try {
      var response = await get('customer/me');
      if (response.statusCode == 200) {
        return {'statusCode': response.statusCode, ...jsonDecode(response.body)};
      }
      final userId = await getUserId();
      response = await get('customer/$userId');
      if (response.statusCode == 200) {
        return {'statusCode': response.statusCode, ...jsonDecode(response.body)};
      }
    } catch (_) {}
    return {'statusCode': 404};
  }

  static Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    try {
      var response = await put('customer/me', data);
      if (response.statusCode == 200 || response.statusCode == 204) {
        final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
        return {'statusCode': response.statusCode, ...body};
      }
      final userId = await getUserId();
      response = await put('customer/$userId', data);
      final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      return {'statusCode': response.statusCode, ...body};
    } catch (e) {
      return {'statusCode': 500, 'message': e.toString()};
    }
  }

  static Future<http.Response> getPreferences() async {
    if (mockGetPreferences != null) {
      return await mockGetPreferences!();
    }
    try {
      final response = await get('preference');
      if (response.statusCode == 200) return response;
    } catch (_) {}
    final userId = await getUserId();
    return await get('preference/$userId');
  }

  static Future<http.Response> updatePreferences(Map<String, dynamic> data) async {
    final headers = await _headers();
    return await http.put(
      Uri.parse('$baseUrl/preference'),
      headers: headers,
      body: jsonEncode(data),
    );
  }

  // ── Destinations ──

  static Future<List<dynamic>> getDestinations() async {
    final response = await get('destination');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    return [];
  }

  // ── Tours ──

  static Future<List<dynamic>> getTours({String? search, String? sortBy}) async {
    String endpoint = 'tour';
    List<String> params = [];
    if (search != null && search.isNotEmpty) {
      params.add('search=${Uri.encodeQueryComponent(search)}');
    }
    if (sortBy != null) {
      params.add('sortBy=${Uri.encodeQueryComponent(sortBy)}');
    }
    if (params.isNotEmpty) endpoint += '?${params.join('&')}';

    final response = await get(endpoint);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw ApiException(
      _responseError(response, 'Failed to load tours'),
      statusCode: response.statusCode,
    );
  }

  static Future<Map<String, dynamic>?> getTour(int id) async {
    final response = await get('tour/$id');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  static Future<Map<String, dynamic>> getTourOrThrow(int id) async {
    final response = await get('tour/$id');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw ApiException(
      _responseError(response, 'Failed to load tour details'),
      statusCode: response.statusCode,
    );
  }

  // ── Itineraries ──

  // Optional mock delegates for unit and widget tests
  static Future<List<dynamic>> Function()? mockGetMyItineraries;
  static Future<Map<String, dynamic>?> Function(int id)? mockGetItinerary;
  static Future<bool> Function(int itineraryId)? mockAcceptItinerary;
  static Future<bool> Function(int itineraryId, String comment)? mockRequestItineraryChanges;

  static Future<List<dynamic>> getMyItineraries() async {
    if (mockGetMyItineraries != null) {
      return await mockGetMyItineraries!();
    }
    try {
      final userId = await getUserId();
      if (userId == null || userId.isEmpty) return [];
      final response = await get('itinerary/customer/$userId');
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) return decoded;
        if (decoded is Map && decoded['data'] is List) return decoded['data'] as List<dynamic>;
      }
    } catch (_) {}
    return [];
  }

  /// Strict itinerary loader for screens that must distinguish an empty list
  /// from authentication and server failures.
  static Future<List<dynamic>> getMyItinerariesOrThrow() async {
    final userId = await getUserId();
    if (userId == null || userId.trim().isEmpty) {
      throw const ApiException('Your session is missing a customer ID. Please sign in again.');
    }

    final response = await get('itinerary/customer/$userId');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }

    throw ApiException(
      _responseError(response, 'Failed to load itineraries'),
      statusCode: response.statusCode,
    );
  }

  static Future<Map<String, dynamic>?> getItinerary(int id) async {
    if (mockGetItinerary != null) {
      return await mockGetItinerary!(id);
    }
    try {
      final response = await get('itinerary/$id');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (_) {}
    return null;
  }

  /// Creates a new Itinerary record in the database linked to a trip request: POST api/itinerary
  static Future<Map<String, dynamic>?> createItinerary({
    required int tripRequestId,
    required DateTime startDate,
    required DateTime endDate,
    String currency = 'LKR',
  }) async {
    try {
      final userId = await getUserId();
      if (userId == null || userId.isEmpty) return null;
      final body = {
        'customerId': userId,
        'tripRequestId': tripRequestId,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'currency': currency,
      };
      final response = await post('itinerary', body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Updates itinerary status (e.g. Accepted, Draft, Discarded) with optional notes
  static Future<bool> updateItineraryStatus(int itineraryId, String status, {String? notes}) async {
    try {
      final body = <String, dynamic>{
        'status': status,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      };
      final response = await patch('itinerary/$itineraryId/status', body);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Accepts an itinerary proposal (sets status to Accepted)
  static Future<bool> acceptItinerary(int itineraryId) async {
    if (mockAcceptItinerary != null) {
      return await mockAcceptItinerary!(itineraryId);
    }
    return await updateItineraryStatus(itineraryId, 'Accepted');
  }

  /// Requests changes by setting status back to Draft with customer comment notes
  static Future<bool> requestItineraryChanges(int itineraryId, [String comment = '']) async {
    if (mockRequestItineraryChanges != null) {
      return await mockRequestItineraryChanges!(itineraryId, comment);
    }
    return await updateItineraryStatus(itineraryId, 'Draft', notes: comment.isNotEmpty ? comment : null);
  }

  static Future<Map<String, dynamic>> addItineraryItem(
    int itineraryId,
    int tourId,
    int dayNumber,
    String startTime,
    String endTime,
  ) async {
    final response = await post('itinerary/$itineraryId/items', {
      'tourId': tourId,
      'dayNumber': dayNumber,
      'sequenceOrder': 0,
      'startTime': startTime,
      'endTime': endTime,
    });

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw ApiException(
      _responseError(response, 'Failed to add the tour to the itinerary'),
      statusCode: response.statusCode,
    );
  }

  // ── Hotels ──

  static Future<List<dynamic>> getHotels() async {
    final response = await get('hotel');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    return [];
  }

  // ── Transport ──

  static Future<List<dynamic>> getTransportOptions() async {
    final response = await get('transport');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    return [];
  }

  // ── Trip Requests ──

  static Future<Map<String, dynamic>> createTripRequest(Map<String, dynamic> data) async {
    final response = await post('triprequest', data);
    return {'statusCode': response.statusCode, ...jsonDecode(response.body)};
  }

  static Future<List<dynamic>> getMyTripRequests() async {
    try {
      final response = await get('triprequest/my');
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded;
        } else if (decoded is Map && decoded['data'] is List) {
          return decoded['data'] as List<dynamic>;
        }
      }
    } catch (_) {}
    return [];
  }

  static Future<Map<String, dynamic>?> getTripRequest(int id) async {
    try {
      final response = await get('triprequest/$id');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Get AI agent execution audit logs for a trip request
  static Future<List<dynamic>> getAgentLogs(int tripRequestId) async {
    try {
      final response = await get('triprequest/$tripRequestId/logs');
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded;
        } else if (decoded is Map && decoded['data'] is List) {
          return decoded['data'] as List<dynamic>;
        }
      }
    } catch (_) {}
    return [];
  }

  // ── Bookings ──

  static Future<List<dynamic>> getMyBookings() async {
    try {
      final response = await get('booking/my');
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded;
        } else if (decoded is Map && decoded['data'] is List) {
          return decoded['data'] as List<dynamic>;
        }
      }
    } catch (_) {}
    return [];
  }

  static Future<Map<String, dynamic>?> getBooking(int id) async {
    try {
      final response = await get('booking/$id');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (_) {}
    return null;
  }

  // ── Payments ──

  static Future<Map<String, dynamic>> createPayment(Map<String, dynamic> data) async {
    final response = await post('payment', data);
    return {'statusCode': response.statusCode, ...jsonDecode(response.body)};
  }

  // ── Notifications ──

  static Future<List<dynamic>> getMyNotifications() async {
    try {
      final response = await get('notification/my');
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded;
        } else if (decoded is Map && decoded['data'] is List) {
          return decoded['data'] as List<dynamic>;
        }
      }
    } catch (_) {}
    return [];
  }

  static Future<void> markNotificationRead(String id) async {
    await put('notification/$id/read', {});
  }

  static Future<void> markAllNotificationsRead() async {
    await put('notification/mark-all-read', {});
  }
}
