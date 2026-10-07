import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';

enum AgentConnectionState { checking, connected, degraded, unavailable }

class AgentConnectionStatus {
  const AgentConnectionStatus({
    required this.state,
    this.latencyMs,
    this.checkedAtUtc,
  });

  const AgentConnectionStatus.checking()
    : this(state: AgentConnectionState.checking);

  final AgentConnectionState state;
  final int? latencyMs;
  final DateTime? checkedAtUtc;

  bool get canReachAgent =>
      state == AgentConnectionState.connected ||
      state == AgentConnectionState.degraded;

  factory AgentConnectionStatus.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status']?.toString().toLowerCase();
    final reachable = json['reachable'] == true;
    final state = switch (rawStatus) {
      'connected' || 'healthy' when reachable => AgentConnectionState.connected,
      'degraded' when reachable => AgentConnectionState.degraded,
      _ => AgentConnectionState.unavailable,
    };
    final rawLatency = json['latencyMs'];
    final checkedAt = DateTime.tryParse(json['checkedAtUtc']?.toString() ?? '');

    return AgentConnectionStatus(
      state: state,
      latencyMs: rawLatency is num ? rawLatency.toInt() : null,
      checkedAtUtc: checkedAt,
    );
  }

  const AgentConnectionStatus.unavailable()
    : this(state: AgentConnectionState.unavailable);
}

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

  /// Probes the backend health proxy with a short, bounded retry budget.
  ///
  /// The response is deliberately reduced to a small state model so malformed
  /// or unexpected upstream data cannot reach the UI as an error or secret.
  static Future<AgentConnectionStatus> fetchStatus({
    required Future<http.Response> Function() request,
    Duration requestTimeout = const Duration(seconds: 5),
    Duration retryDelay = const Duration(milliseconds: 500),
    int maxAttempts = 2,
  }) async {
    final attempts = maxAttempts < 1 ? 1 : maxAttempts;

    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        final response = await request().timeout(requestTimeout);
        final retryable = const [
          408,
          429,
          500,
          502,
          503,
          504,
        ].contains(response.statusCode);

        if (response.statusCode < 200 || response.statusCode >= 300) {
          if (retryable && attempt < attempts - 1) {
            await Future<void>.delayed(retryDelay);
            continue;
          }
          return const AgentConnectionStatus.unavailable();
        }

        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          return const AgentConnectionStatus.unavailable();
        }
        return AgentConnectionStatus.fromJson(decoded);
      } on TimeoutException {
        if (attempt < attempts - 1) {
          await Future<void>.delayed(retryDelay);
          continue;
        }
        return const AgentConnectionStatus.unavailable();
      } on http.ClientException {
        if (attempt < attempts - 1) {
          await Future<void>.delayed(retryDelay);
          continue;
        }
        return const AgentConnectionStatus.unavailable();
      } on ApiException catch (error) {
        final retryable = const [
          408,
          429,
          500,
          502,
          503,
          504,
        ].contains(error.statusCode);
        if (retryable && attempt < attempts - 1) {
          await Future<void>.delayed(retryDelay);
          continue;
        }
        return const AgentConnectionStatus.unavailable();
      } on FormatException {
        return const AgentConnectionStatus.unavailable();
      } catch (_) {
        return const AgentConnectionStatus.unavailable();
      }
    }

    return const AgentConnectionStatus.unavailable();
  }
}
