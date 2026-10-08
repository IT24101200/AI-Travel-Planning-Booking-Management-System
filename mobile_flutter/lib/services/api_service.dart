import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'app_navigation.dart';
import 'agent_health_service.dart';

// Override: flutter run --dart-define=API_BASE_URL=https://ai-travel-planning-booking-backend.onrender.com/api
// Both a server root and a URL ending in /api are accepted.
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://ai-travel-planning-booking-backend.onrender.com/api',
);

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.errorCode});

  final String message;
  final int? statusCode;
  final String? errorCode;

  @override
  String toString() => message;
}

class AgentLogStreamEvent {
  const AgentLogStreamEvent(this.event, this.data);

  final String event;
  final Map<String, dynamic> data;
}

/// Single HTTP client for all backend API calls.
/// Stores JWT token via flutter_secure_storage and attaches it to every request.
class ApiService {
  static const _requestTimeout = Duration(seconds: 30);
  // ── Backend URLs ──
  static String get baseUrl {
    final url = kApiBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    return url.endsWith('/api') ? url : '$url/api';
  }

  /// Convert backend-relative media paths into URLs reachable by this client.
  static String resolveMediaUrl(String? path) {
    if (path == null || path.trim().isEmpty) return '';
    final value = path.trim();
    if (value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('assets/')) {
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
    await Future.wait([
      _storage.delete(key: 'jwt_token'),
      _storage.delete(key: 'user_id'),
      _storage.delete(key: 'user_name'),
    ]);
  }

  // ── Favorite Tours Storage ──

  /// Load set of favorited tour IDs from persistent storage
  static Future<Set<int>> getFavoriteTourIds() async {
    try {
      final raw = await _storage.read(key: 'user_favorite_tours');
      if (raw == null || raw.trim().isEmpty) return {};
      final list = jsonDecode(raw) as List;
      return list.map((e) => int.parse(e.toString())).toSet();
    } catch (_) {
      return {};
    }
  }

  /// Toggle favorite status of a tour and save to persistent storage
  static Future<bool> toggleFavorite(int tourId) async {
    final favorites = await getFavoriteTourIds();
    final bool isNowFav;
    if (favorites.contains(tourId)) {
      favorites.remove(tourId);
      isNowFav = false;
    } else {
      favorites.add(tourId);
      isNowFav = true;
    }
    await _storage.write(
      key: 'user_favorite_tours',
      value: jsonEncode(favorites.toList()),
    );
    return isNowFav;
  }

  /// Check if a tour ID is currently favorited
  static Future<bool> isFavorite(int tourId) async {
    final favorites = await getFavoriteTourIds();
    return favorites.contains(tourId);
  }

  static Future<Map<String, dynamic>> Function(Map<String, dynamic>)?
  mockUpdateProfile;
  static Future<http.Response> Function(Map<String, dynamic>)?
  mockUpdatePreferences;
  static Future<Map<String, dynamic>> Function(Map<String, dynamic>)?
  mockCreateTripRequest;
  static Future<List<dynamic>> Function()? mockGetMyTripRequests;
  static Future<List<dynamic>> Function()? mockGetMyBookings;
  static Future<AgentConnectionStatus> Function()? mockGetAgentConnectionStatus;
  static Future<List<dynamic>> Function({String? currency})? mockGetHotels;
  static Future<List<dynamic>> Function({String? currency})?
  mockGetTransportOptions;
  static Future<http.Response> Function({
    required int page,
    required int pageSize,
    String? currency,
  })? mockGetTransportPage;
  static Future<Map<String, dynamic>> Function(Map<String, dynamic>)?
  mockCreateBooking;
  static Future<Map<String, dynamic>?> Function(int id)? mockGetBooking;
  static Future<Map<String, dynamic>> Function(Map<String, dynamic>)?
  mockCreatePayment;
  static Future<Map<String, dynamic>> Function({
    required String email,
    required String password,
  })?
  mockLogin;
  static Future<Map<String, dynamic>> Function({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  })?
  mockRegister;

  static void _requireSuccess(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _responseError(response, 'Request failed'),
        statusCode: response.statusCode,
      );
    }
  }

  static dynamic _decode(http.Response response) {
    _requireSuccess(response);
    if (response.statusCode == 204) return null;
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw const ApiException(
        'The server returned an invalid response. Please retry.',
      );
    }
  }

  static List<dynamic> _list(http.Response response) {
    final decoded = _decode(response);
    if (decoded == null) return [];
    if (decoded is List) return decoded;
    if (decoded is Map && decoded['data'] is List)
      return decoded['data'] as List<dynamic>;
    throw const ApiException(
      'The server returned an invalid list. Please retry.',
    );
  }

  static Map<String, dynamic>? _object(http.Response response) {
    final decoded = _decode(response);
    if (decoded == null) return null;
    if (decoded is Map<String, dynamic>)
      return decoded.isEmpty ? null : decoded;
    throw const ApiException(
      'The server returned an invalid record. Please retry.',
    );
  }

  static Future<void>? _sessionExpiry;

  static Future<void> _expireSession() async {
    await logout();
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (_) => false);
  }

  static Future<http.Response> _handleResponse(
    http.Response response, {
    bool isAuth = false,
  }) async {
    // Only expire session and redirect for protected endpoints, never for auth/login or auth/register
    if (response.statusCode == 401 && !isAuth) {
      final expiry = _sessionExpiry ??= _expireSession();
      try {
        await expiry;
      } finally {
        if (identical(_sessionExpiry, expiry)) _sessionExpiry = null;
      }
      throw ApiException(
        _responseError(response, 'Please sign in again'),
        statusCode: 401,
      );
    }
    return response;
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
    return switch (response.statusCode) {
      401 => 'Your session has expired. Please sign in again.',
      403 => 'You do not have permission to perform this action.',
      404 => 'The requested information could not be found.',
      408 ||
      504 => 'The planning service took too long to respond. Please retry.',
      429 => 'The service is busy. Please retry shortly.',
      500 ||
      502 ||
      503 => 'The planning service is temporarily unavailable. Please retry.',
      _ => fallback,
    };
  }

  static Future<T> _withTimeout<T>(Future<T> request) async {
    try {
      return await request.timeout(_requestTimeout);
    } on TimeoutException {
      throw const ApiException(
        'The service is temporarily unavailable. Please retry.',
        errorCode: 'REQUEST_TIMEOUT',
      );
    } on http.ClientException {
      throw const ApiException(
        'The service is temporarily unavailable. Please retry.',
        errorCode: 'NETWORK_ERROR',
      );
    }
  }

  /// Generic GET request
  static Future<http.Response> get(
    String endpoint, {
    bool isAuth = false,
  }) async {
    final headers = await _headers();
    final isAuthReq = isAuth || endpoint.startsWith('auth/');
    return _handleResponse(
      await _withTimeout(
        http.get(Uri.parse('$baseUrl/$endpoint'), headers: headers),
      ),
      isAuth: isAuthReq,
    );
  }

  /// Generic POST request
  static Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool isAuth = false,
  }) async {
    final headers = await _headers();
    final isAuthReq = isAuth || endpoint.startsWith('auth/');
    return _handleResponse(
      await _withTimeout(
        http.post(
          Uri.parse('$baseUrl/$endpoint'),
          headers: headers,
          body: jsonEncode(body),
        ),
      ),
      isAuth: isAuthReq,
    );
  }

  /// Generic PUT request
  static Future<http.Response> put(
    String endpoint,
    Map<String, dynamic> body, {
    bool isAuth = false,
  }) async {
    final headers = await _headers();
    final isAuthReq = isAuth || endpoint.startsWith('auth/');
    return _handleResponse(
      await _withTimeout(
        http.put(
          Uri.parse('$baseUrl/$endpoint'),
          headers: headers,
          body: jsonEncode(body),
        ),
      ),
      isAuth: isAuthReq,
    );
  }

  /// Generic PATCH request
  static Future<http.Response> patch(
    String endpoint,
    Map<String, dynamic> body, {
    bool isAuth = false,
  }) async {
    final headers = await _headers();
    final isAuthReq = isAuth || endpoint.startsWith('auth/');
    return _handleResponse(
      await _withTimeout(
        http.patch(
          Uri.parse('$baseUrl/$endpoint'),
          headers: headers,
          body: jsonEncode(body),
        ),
      ),
      isAuth: isAuthReq,
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
    if (mockRegister != null) {
      return await mockRegister!(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
      );
    }
    final response = await post('auth/register', {
      'email': email,
      'password': password,
      'fullName': fullName,
      'phone': phone,
    }, isAuth: true);

    Map<String, dynamic> data = {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        data = decoded;
      }
    } catch (_) {}

    if (response.statusCode == 201) {
      // Save token and user info on successful registration
      if (data['token'] != null) await saveToken(data['token'].toString());
      if (data['userId'] != null) await saveUserId(data['userId'].toString());
      if (data['fullName'] != null)
        await saveUserName(data['fullName'].toString());
    }
    return {'statusCode': response.statusCode, ...data};
  }

  /// Login with email and password
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    if (mockLogin != null) {
      return await mockLogin!(email: email, password: password);
    }
    final response = await post('auth/login', {
      'email': email,
      'password': password,
    }, isAuth: true);

    Map<String, dynamic> data = {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        data = decoded;
      }
    } catch (_) {}

    if (response.statusCode == 200) {
      if (data['token'] != null) await saveToken(data['token'].toString());
      if (data['userId'] != null) await saveUserId(data['userId'].toString());
      if (data['fullName'] != null)
        await saveUserName(data['fullName'].toString());
    }
    return {'statusCode': response.statusCode, ...data};
  }

  // Optional mock delegates for unit and widget tests
  static Future<Map<String, dynamic>> Function()? mockGetProfile;
  static Future<http.Response> Function()? mockGetPreferences;

  static Future<Map<String, dynamic>> getProfile() async {
    if (mockGetProfile != null) return mockGetProfile!();
    final response = await get('customer/me');
    _requireSuccess(response);
    final data = _object(response);
    return {'statusCode': data == null ? 204 : response.statusCode, ...?data};
  }

  static Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> data,
  ) async {
    if (mockUpdateProfile != null) return mockUpdateProfile!(data);
    final response = await put('customer/me', data);
    _requireSuccess(response);
    return {...?_object(response), 'statusCode': response.statusCode};
  }

  static Future<http.Response> getPreferences() async {
    if (mockGetPreferences != null) return mockGetPreferences!();
    final response = await get('preference');
    _requireSuccess(response);
    return response;
  }

  static Future<http.Response> updatePreferences(
    Map<String, dynamic> data,
  ) async {
    if (mockUpdatePreferences != null) return mockUpdatePreferences!(data);
    final response = await put('preference', data);
    _requireSuccess(response);
    return response;
  }

  static Future<List<dynamic>> Function()? mockGetDestinations;

  static Future<List<dynamic>> getDestinations() async {
    if (mockGetDestinations != null) {
      return await mockGetDestinations!();
    }
    return _list(await get('destination'));
  }

  static Future<List<dynamic>> Function({String? search, String? sortBy})?
  mockGetTours;
  static Future<Map<String, dynamic>?> Function(int id)? mockGetTour;

  static Future<List<dynamic>> getTours({
    String? search,
    String? sortBy,
    String? currency,
  }) async {
    if (mockGetTours != null) {
      return await mockGetTours!(search: search, sortBy: sortBy);
    }
    String endpoint = 'tour';
    List<String> params = [];
    if (search != null && search.isNotEmpty) {
      params.add('search=${Uri.encodeQueryComponent(search)}');
    }
    if (sortBy != null) {
      params.add('sortBy=${Uri.encodeQueryComponent(sortBy)}');
    }
    if (currency != null)
      params.add('currency=${Uri.encodeQueryComponent(currency)}');
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

  static Future<Map<String, dynamic>?> getTour(
    int id, {
    String? currency,
  }) async {
    if (mockGetTour != null) return mockGetTour!(id);
    return _object(
      await get(
        'tour/$id${currency == null ? '' : '?currency=${Uri.encodeQueryComponent(currency)}'}',
      ),
    );
  }

  static Future<Map<String, dynamic>> getTourOrThrow(
    int id, {
    String? currency,
  }) async {
    final response = await get(
      'tour/$id${currency == null ? '' : '?currency=${Uri.encodeQueryComponent(currency)}'}',
    );
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
  static Future<bool> Function(int itineraryId, String comment)?
  mockRequestItineraryChanges;
  static Future<Map<String, dynamic>> Function(int tripRequestId)?
  mockCancelTripRequest;

  static Future<List<dynamic>> getMyItineraries() async {
    if (mockGetMyItineraries != null) return mockGetMyItineraries!();
    final userId = await getUserId();
    if (userId == null || userId.isEmpty) {
      throw const ApiException(
        'Your session is missing a customer ID. Please sign in again.',
      );
    }
    return _list(await get('itinerary/customer/$userId'));
  }

  static Future<List<dynamic>> getMyItinerariesOrThrow() => getMyItineraries();

  static Future<Map<String, dynamic>?> getItinerary(int id) async {
    if (mockGetItinerary != null) return mockGetItinerary!(id);
    return _object(await get('itinerary/$id'));
  }

  static Future<Map<String, dynamic>?> createItinerary({
    required int tripRequestId,
    required DateTime startDate,
    required DateTime endDate,
    String currency = 'LKR',
  }) async {
    final userId = await getUserId();
    if (userId == null || userId.isEmpty) {
      throw const ApiException('Please sign in again.');
    }
    return _object(
      await post('itinerary', {
        'customerId': userId,
        'tripRequestId': tripRequestId,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'currency': currency,
      }),
    );
  }

  static Future<bool> updateItineraryStatus(
    int itineraryId,
    String status, {
    String? notes,
  }) async {
    final response = await patch('itinerary/$itineraryId/status', {
      'status': status,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    _requireSuccess(response);
    return true;
  }

  static Future<bool> acceptItinerary(int itineraryId) async {
    if (mockAcceptItinerary != null) {
      return await mockAcceptItinerary!(itineraryId);
    }
    // TODO(backend): Customer approval is forbidden by ItineraryController.
    // Keep the server error visible until a customer acceptance contract exists.
    return await updateItineraryStatus(itineraryId, 'Accepted');
  }

  /// Requests changes by setting status back to Draft with customer comment notes
  static Future<bool> requestItineraryChanges(
    int itineraryId, [
    String comment = '',
  ]) async {
    if (mockRequestItineraryChanges != null) {
      return await mockRequestItineraryChanges!(itineraryId, comment);
    }
    // TODO(backend): No customer revision endpoint persists notes. The status
    // controller only permits customers to set Discarded and ignores Notes.
    throw const ApiException(
      'Change requests are not supported by the API yet. Please contact your travel agent.',
    );
  }

  static Future<Map<String, dynamic>> cancelTripRequest(
    int tripRequestId,
  ) async {
    if (mockCancelTripRequest != null) {
      return mockCancelTripRequest!(tripRequestId);
    }
    final response = await patch('triprequest/$tripRequestId/cancel', {});
    final result = _object(response);
    if (result == null) {
      throw const ApiException(
        'The server returned no cancellation result. Please retry.',
      );
    }
    return result;
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

  static Future<List<dynamic>> getHotels({String? currency}) async {
    if (mockGetHotels != null) return mockGetHotels!(currency: currency);
    final hotels = <dynamic>[];
    var page = 1;
    var totalPages = 1;
    do {
      final query = Uri(
        queryParameters: {
          'status': 'Active',
          'pageSize': '50',
          'page': '$page',
          'currency': ?currency,
        },
      ).query;
      final response = await get(
        'hotel?$query',
      ).timeout(const Duration(seconds: 60));
      hotels.addAll(_list(response));
      final body = jsonDecode(response.body);
      totalPages = body is Map ? int.tryParse('${body['totalPages']}') ?? 1 : 1;
      page++;
    } while (page <= totalPages);
    return hotels;
  }

  static Future<List<dynamic>> getTransportOptions({String? currency}) async {
    if (mockGetTransportOptions != null) {
      return mockGetTransportOptions!(currency: currency);
    }

    const pageSize = 50;
    const maxPages = 100;
    final options = <dynamic>[];
    final seenIds = <String>{};
    var page = 1;
    var totalPages = 1;

    do {
      final response = mockGetTransportPage != null
          ? await mockGetTransportPage!(
              page: page,
              pageSize: pageSize,
              currency: currency,
            )
          : await get(
              Uri(
                path: 'transport',
                queryParameters: {
                  'page': '$page',
                  'pageSize': '$pageSize',
                  'currency': ?currency,
                },
              ).toString(),
            );

      final decoded = _decode(response);
      if (decoded is! Map || decoded['data'] is! List) {
        throw const ApiException(
          'The transport catalogue returned an invalid page. Please retry.',
          errorCode: 'TRANSPORT_PAGINATION_INVALID',
        );
      }

      final rawTotalPages = decoded['totalPages'];
      final parsedTotalPages = int.tryParse('$rawTotalPages');
      final pageData = decoded['data'] as List;
      if (parsedTotalPages == null ||
          parsedTotalPages < 0 ||
          parsedTotalPages > maxPages ||
          (parsedTotalPages == 0 && pageData.isNotEmpty)) {
        throw const ApiException(
          'The transport catalogue returned invalid pagination data. Please retry.',
          errorCode: 'TRANSPORT_PAGINATION_INVALID',
        );
      }
      totalPages = parsedTotalPages == 0 ? 1 : parsedTotalPages;

      for (final item in pageData) {
        if (item is! Map || item['id'] == null) {
          throw const ApiException(
            'The transport catalogue returned an invalid record. Please retry.',
            errorCode: 'TRANSPORT_PAGINATION_INVALID',
          );
        }
        final id = '${item['id']}';
        if (seenIds.add(id)) options.add(item);
      }

      if (page >= totalPages) break;
      page++;
    } while (page <= maxPages);

    if (page > maxPages && page <= totalPages) {
      throw const ApiException(
        'The transport catalogue is too large to load safely. Please retry.',
        errorCode: 'TRANSPORT_PAGINATION_LIMIT',
      );
    }

    return options;
  }

  static Future<Map<String, dynamic>> createTripRequest(
    Map<String, dynamic> data,
  ) async {
    if (mockCreateTripRequest != null) return mockCreateTripRequest!(data);
    final response = await post('triprequest', data);
    final result = _object(response);
    if (result == null)
      throw const ApiException(
        'The server returned no trip request. Please retry.',
      );
    return {...result, 'statusCode': response.statusCode};
  }

  static Future<List<dynamic>> getMyTripRequests() async {
    if (mockGetMyTripRequests != null) return mockGetMyTripRequests!();
    return _list(await get('triprequest/my'));
  }

  static Future<Map<String, dynamic>> Function()? mockGetAgentHealth;
  static Future<Map<String, dynamic>> Function(int tripRequestId)?
  mockTriggerAgentPipeline;

  /// Returns the current health/state reported by the agent service.
  static Future<Map<String, dynamic>> getAgentHealth() async {
    if (mockGetAgentHealth != null) return mockGetAgentHealth!();
    final health = await AgentHealthService.fetch(
      request: () => get('AgentTrigger/health', isAuth: true),
    );
    // Preserve the legacy itinerary consumer's `healthy` contract while the
    // trip-request form uses the richer normalized connection model below.
    if (health['status']?.toString().toLowerCase() == 'connected' &&
        health['reachable'] == true) {
      return {...health, 'status': 'healthy'};
    }
    return health;
  }

  /// Checks AI reachability through the backend's anonymous health proxy.
  ///
  /// `isAuth: true` prevents a health-probe 401 from triggering the global
  /// session-expiry flow. The backend never forwards this request's JWT to the
  /// Python service.
  static Future<AgentConnectionStatus> getAgentConnectionStatus() async {
    if (mockGetAgentConnectionStatus != null) {
      return mockGetAgentConnectionStatus!();
    }
    return AgentHealthService.fetchStatus(
      request: () => get('AgentTrigger/health', isAuth: true),
    );
  }

  static Future<Map<String, dynamic>> triggerAgentPipeline(
    int tripRequestId,
  ) async {
    if (mockTriggerAgentPipeline != null) {
      return mockTriggerAgentPipeline!(tripRequestId);
    }
    final response = await post(
      'AgentTrigger/trigger/$tripRequestId?runAsync=true',
      {},
    );
    return {...?_object(response), 'statusCode': response.statusCode};
  }

  static String userMessage(Object error) {
    if (error is ApiException) return error.message;
    if (error is TimeoutException || error is http.ClientException) {
      return 'The service is temporarily unavailable. Please retry.';
    }
    return 'Something went wrong. Please retry.';
  }

  static String safeAgentFailureMessage(String? reason) {
    if (reason == null || reason.trim().isEmpty) {
      return 'The planning service is temporarily unavailable. Please retry.';
    }
    final lower = reason.toLowerCase();
    final unsafe =
        lower.contains('exception') ||
        lower.contains('stack trace') ||
        lower.contains('traceback') ||
        lower.contains('httpclient') ||
        lower.contains('sql') ||
        lower.contains('apikey') ||
        lower.contains('api key');
    return unsafe
        ? 'The planning service is temporarily unavailable. Please retry.'
        : reason;
  }

  static Future<Map<String, dynamic>?> Function(int id)? mockGetTripRequest;

  static Future<Map<String, dynamic>?> getTripRequest(int id) async {
    if (mockGetTripRequest != null) return mockGetTripRequest!(id);
    return _object(await get('triprequest/$id'));
  }

  static Future<List<dynamic>> Function(int tripRequestId)? mockGetAgentLogs;
  static Stream<AgentLogStreamEvent> Function(int tripRequestId)?
  mockStreamAgentLogs;

  static Future<List<dynamic>> getAgentLogs(int tripRequestId) async {
    if (mockGetAgentLogs != null) return mockGetAgentLogs!(tripRequestId);
    try {
      final response = await get('triprequest/$tripRequestId/logs');
      return _list(response);
    } catch (_) {
      return [];
    }
  }

  static Stream<AgentLogStreamEvent> streamAgentLogs(int tripRequestId) async* {
    if (mockStreamAgentLogs != null) {
      yield* mockStreamAgentLogs!(tripRequestId);
      return;
    }
    final client = http.Client();
    try {
      final token = await getToken();
      final request =
          http.Request(
              'GET',
              Uri.parse('$baseUrl/triprequest/$tripRequestId/logs/stream'),
            )
            ..headers.addAll({
              'Accept': 'text/event-stream',
              if (token != null) 'Authorization': 'Bearer $token',
            });
      final response = await client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.stream.drain();
        throw ApiException(
          'Unable to connect to live agent updates.',
          statusCode: response.statusCode,
        );
      }
      var eventName = 'message';
      var dataLines = <String>[];
      await for (final line
          in response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (line.isEmpty) {
          if (dataLines.isNotEmpty) {
            try {
              final decoded = jsonDecode(dataLines.join('\n'));
              if (decoded is Map)
                yield AgentLogStreamEvent(
                  eventName,
                  Map<String, dynamic>.from(decoded),
                );
            } catch (_) {}
          }
          eventName = 'message';
          dataLines = <String>[];
        } else if (line.startsWith(':')) {
          continue;
        } else if (line.startsWith('event:')) {
          eventName = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          dataLines.add(line.substring(5).trimLeft());
        }
      }
    } finally {
      client.close();
    }
  }

  static Future<List<dynamic>> getMyBookings() async {
    if (mockGetMyBookings != null) return mockGetMyBookings!();
    return _list(await get('booking/my'));
  }

  static Future<Map<String, dynamic>> createBooking(
    Map<String, dynamic> data,
  ) async {
    if (mockCreateBooking != null) return mockCreateBooking!(data);
    final response = await post('booking', data);
    _requireSuccess(response);
    final result = _object(response);
    return {'statusCode': response.statusCode, ...?result};
  }

  static Future<Map<String, dynamic>?> getBooking(int id) async {
    if (mockGetBooking != null) return mockGetBooking!(id);
    return _object(await get('booking/$id'));
  }

  static Future<Map<String, dynamic>> createPayment(
    Map<String, dynamic> data,
  ) async {
    if (mockCreatePayment != null) return mockCreatePayment!(data);
    final response = await post('payment', data);
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return {'statusCode': response.statusCode, ...decoded};
      }
    } catch (_) {}
    return {'statusCode': response.statusCode};
  }

  // ── Notifications ──

  // Optional mock delegates for unit and widget tests
  static Future<List<dynamic>> Function()? mockGetMyNotifications;
  static Future<void> Function(String id)? mockMarkNotificationRead;
  static Future<void> Function(String id)? mockMarkNotificationUnread;
  static Future<void> Function()? mockMarkAllNotificationsRead;

  static Future<List<dynamic>> getMyNotifications() async {
    if (mockGetMyNotifications != null) return mockGetMyNotifications!();

    // The notification screen has no local pagination control. Fetch every
    // server page (the API caps pageSize at 100) so its list and unread count
    // are not silently limited to the backend's default first page.
    final notifications = <dynamic>[];
    var page = 1;
    var totalPages = 1;

    do {
      final response = await get('notification/my?page=$page&pageSize=100');
      final decoded = _decode(response);

      if (decoded is List) {
        notifications.addAll(decoded);
        break;
      }
      if (decoded is! Map || decoded['data'] is! List) {
        throw const ApiException(
          'The server returned an invalid notification list. Please retry.',
        );
      }

      notifications.addAll(decoded['data'] as List<dynamic>);
      totalPages = int.tryParse('${decoded['totalPages'] ?? page}') ?? page;
      page++;
    } while (page <= totalPages);

    return notifications;
  }

  static Future<void> markNotificationRead(String id) async {
    if (mockMarkNotificationRead != null) {
      return await mockMarkNotificationRead!(id);
    }
    _requireSuccess(await patch('notification/$id/read', {}));
  }

  static Future<void> markNotificationUnread(String id) async {
    if (mockMarkNotificationUnread != null) {
      return await mockMarkNotificationUnread!(id);
    }
    _requireSuccess(await patch('notification/$id/unread', {}));
  }

  static Future<void> markAllNotificationsRead() async {
    if (mockMarkAllNotificationsRead != null) {
      return await mockMarkAllNotificationsRead!();
    }
    _requireSuccess(await post('notification/mark-all-read', {}));
  }
}
