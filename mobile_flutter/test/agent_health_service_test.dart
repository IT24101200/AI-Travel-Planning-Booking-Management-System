import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_flutter/services/agent_health_service.dart';

void main() {
  group('AgentHealthService.fetchStatus', () {
    test('maps a normalized connected response', () async {
      final result = await AgentHealthService.fetchStatus(
        request: () async => http.Response(
          '{"status":"connected","reachable":true,"latencyMs":42}',
          200,
        ),
        maxAttempts: 1,
      );

      expect(result.state, AgentConnectionState.connected);
      expect(result.latencyMs, 42);
    });

    test('maps degraded and unavailable responses safely', () async {
      final degraded = await AgentHealthService.fetchStatus(
        request: () async =>
            http.Response('{"status":"degraded","reachable":true}', 200),
        maxAttempts: 1,
      );
      final unavailable = await AgentHealthService.fetchStatus(
        request: () async => http.Response('{"status":"broken"}', 200),
        maxAttempts: 1,
      );

      expect(degraded.state, AgentConnectionState.degraded);
      expect(unavailable.state, AgentConnectionState.unavailable);
    });

    test('retries a transient backend failure once', () async {
      var calls = 0;
      final result = await AgentHealthService.fetchStatus(
        request: () async {
          calls++;
          return calls == 1
              ? http.Response('', 503)
              : http.Response('{"status":"connected","reachable":true}', 200);
        },
        retryDelay: Duration.zero,
      );

      expect(calls, 2);
      expect(result.state, AgentConnectionState.connected);
    });

    test('maps timeout and malformed JSON to unavailable', () async {
      final timeout = await AgentHealthService.fetchStatus(
        request: () =>
            Future<http.Response>.error(TimeoutException('test timeout')),
        maxAttempts: 1,
      );
      final malformed = await AgentHealthService.fetchStatus(
        request: () async => http.Response('not-json', 200),
        maxAttempts: 1,
      );

      expect(timeout.state, AgentConnectionState.unavailable);
      expect(malformed.state, AgentConnectionState.unavailable);
    });
  });
}
