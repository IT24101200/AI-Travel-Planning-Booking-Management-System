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

  static Future<List<dynamic>> getTours({String? search, String? sortBy}) async {
    String endpoint = 'tour';
    List<String> params = [];
    if (search != null && search.isNotEmpty) params.add('search=$search');
    if (sortBy != null) params.add('sortBy=$sortBy');
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

  static Future<List<dynamic>> getMyItineraries() async {
    final response = await get('itinerary/my');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    return [];
  }

  static Future<Map<String, dynamic>?> getItinerary(int id) async {
    final response = await get('itinerary/$id');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
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
    final response = await get('triprequest/my');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    return [];
  }

  // ── Bookings ──

  static Future<List<dynamic>> getMyBookings() async {
    final response = await get('booking/my');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    return [];
  }

  static Future<Map<String, dynamic>?> getBooking(int id) async {
    final response = await get('booking/$id');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  // ── Payments ──

  static Future<Map<String, dynamic>> createPayment(Map<String, dynamic> data) async {
    final response = await post('payment', data);
    return {'statusCode': response.statusCode, ...jsonDecode(response.body)};
  }

  // ── Notifications ──

  static Future<List<dynamic>> getMyNotifications() async {
    final response = await get('notification/my');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    return [];
  }

  static Future<void> markNotificationRead(String id) async {
    await put('notification/$id/read', {});
  }

  static Future<void> markAllNotificationsRead() async {
    await put('notification/mark-all-read', {});
  }
}
