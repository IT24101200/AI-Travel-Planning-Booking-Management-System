import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';

class AgentHealthService {
  static Future<Map<String, dynamic>> fetch({
    required Future<http.Response> Function() request,
    Duration requestTimeout = const Duration(seconds: 45),
    Duration retryDelay = const Duration(seconds: 2),
    int maxAttempts = 3,
  }) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final response = await request().timeout(requestTimeout);
        final retryable = const [
          408,
          502,
          503,
          504,
        ].contains(response.statusCode);
        if (!retryable || attempt == maxAttempts - 1) {
          if (response.statusCode < 200 || response.statusCode >= 300) {
            throw ApiException(
              'Agent connection unavailable (HTTP ${response.statusCode}). Please retry shortly.',
              statusCode: response.statusCode,
            );
          }
          dynamic data;
          try {
            data = jsonDecode(response.body);
          } on FormatException {
            throw const ApiException(
              'The agent service returned an invalid health response.',
            );
          }
          if (data is! Map<String, dynamic> || data['status'] is! String) {
            throw const ApiException(
              'The agent service returned no health status.',
            );
          }
          return data;
        }
      } on TimeoutException {
        if (attempt == maxAttempts - 1) {
          throw const ApiException(
            'The agent connection timed out. Please retry shortly.',
          );
        }
      } on http.ClientException {
        if (attempt == maxAttempts - 1) {
          throw const ApiException(
            'Unable to check the agent connection. Please retry shortly.',
          );
        }
      }
      await Future<void>.delayed(retryDelay * (attempt + 1));
    }
    throw const ApiException('Unable to check the agent connection.');
  }
}
