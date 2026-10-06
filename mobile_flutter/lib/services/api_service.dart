import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Single HTTP client for all backend API calls.
/// Stores JWT token via flutter_secure_storage and attaches it to every request.
class ApiService {
  // ── Backend URLs ──
  // Web (Chrome): runs on localhost
  static const String _webUrl = 'http://localhost:5138/api';
  // Mobile (Physical phone / Emulator): PC's local Wi-Fi IP or emulator 10.0.2.2
  static const String _mobileUrl = 'http://192.168.1.3:5138/api';

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

  // ── Customer & Preferences ──

  static Future<Map<String, dynamic>> getProfile() async {
    final userId = await getUserId();
    final response = await get('customer/$userId');
    return {'statusCode': response.statusCode, ...jsonDecode(response.body)};
  }

  static Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final userId = await getUserId();
    final response = await put('customer/$userId', data);
    return {'statusCode': response.statusCode, ...jsonDecode(response.body)};
  }

  static Future<http.Response> getPreferences() async {
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

  static Future<List<dynamic>> getTours({
    String? search,
    int? destinationId,
    String? category,
    num? minPrice,
    num? maxPrice,
    String? sortBy,
    bool descending = false,
    int page = 1,
    int pageSize = 10,
  }) async {
    String endpoint = 'tour';
    List<String> params = [];
    if (search != null && search.trim().isNotEmpty) {
      params.add('search=${Uri.encodeComponent(search.trim())}');
    }
    if (destinationId != null) params.add('destinationId=$destinationId');
    if (category != null && category.isNotEmpty && category != 'All') {
      params.add('category=${Uri.encodeComponent(category)}');
    }
    if (minPrice != null) params.add('minPrice=$minPrice');
    if (maxPrice != null) params.add('maxPrice=$maxPrice');
    if (sortBy != null && sortBy.isNotEmpty) params.add('sortBy=$sortBy');
    if (descending) params.add('descending=true');
    params.add('page=$page');
    params.add('pageSize=$pageSize');

    if (params.isNotEmpty) endpoint += '?${params.join('&')}';

    final response = await get(endpoint);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    return [];
  }

  static Future<Map<String, dynamic>?> getTour(int id) async {
    final response = await get('tour/$id');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
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
  static Future<bool> requestItineraryChanges(int itineraryId, String comment) async {
    if (mockRequestItineraryChanges != null) {
      return await mockRequestItineraryChanges!(itineraryId, comment);
    }
    return await updateItineraryStatus(itineraryId, 'Draft', notes: comment);
  }

  /// Adds a scheduled tour item to an itinerary: POST api/itinerary/{id}/items
  static Future<Map<String, dynamic>> addItemToItinerary({
    required int itineraryId,
    required int tourId,
    int dayNumber = 1,
    int sequenceOrder = 1,
    String startTime = '09:00:00',
    String endTime = '12:00:00',
  }) async {
    try {
      final response = await post('itinerary/$itineraryId/items', {
        'tourId': tourId,
        'dayNumber': dayNumber,
        'sequenceOrder': sequenceOrder,
        'startTime': startTime,
        'endTime': endTime,
      });

      final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      final bool success = response.statusCode == 200 || response.statusCode == 201;
      String message = '';
      if (decoded is Map && decoded['message'] != null) {
        message = decoded['message'].toString();
      }

      return {
        'success': success,
        'statusCode': response.statusCode,
        'message': message,
        'data': decoded,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to connect to server: $e',
      };
    }
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
    await patch('notification/$id/read', {});
  }

  static Future<void> markAllNotificationsRead() async {
    await post('notification/mark-all-read', {});
  }
}
