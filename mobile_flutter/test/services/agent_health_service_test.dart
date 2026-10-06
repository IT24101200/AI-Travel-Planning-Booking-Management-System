import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_flutter/services/agent_health_service.dart';
import 'package:mobile_flutter/services/api_service.dart';

void main() {
  test(
    'retries temporary gateway failures and returns recovered health',
    () async {
      var calls = 0;
      final health = await AgentHealthService.fetch(
        retryDelay: Duration.zero,
        request: () async => ++calls < 3
            ? http.Response('<html>Render gateway</html>', 502)
            : http.Response('{"status":"healthy"}', 200),
      );
      expect(calls, 3);
      expect(health['status'], 'healthy');
    },
  );

  test('stops after bounded retries and hides the gateway HTML', () async {
    var calls = 0;
    await expectLater(
      AgentHealthService.fetch(
        retryDelay: Duration.zero,
        request: () async {
          calls++;
          return http.Response('<html>gateway internals</html>', 503);
        },
      ),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'status code', 503)
            .having(
              (error) => error.message,
              'safe message',
              isNot(contains('<html>')),
            ),
      ),
    );
    expect(calls, 3);
  });

  test('a timed-out check can recover on the next attempt', () async {
    var calls = 0;
    final health = await AgentHealthService.fetch(
      retryDelay: Duration.zero,
      requestTimeout: const Duration(milliseconds: 5),
      request: () {
        calls++;
        return calls == 1
            ? Completer<http.Response>().future
            : Future.value(http.Response('{"status":"healthy"}', 200));
      },
    );
    expect(calls, 2);
    expect(health['status'], 'healthy');
  });

  test('does not retry permanent client errors', () async {
    var calls = 0;
    await expectLater(
      AgentHealthService.fetch(
        request: () async {
          calls++;
          return http.Response('{}', 401);
        },
      ),
      throwsA(
        isA<ApiException>().having(
          (error) => error.statusCode,
          'status code',
          401,
        ),
      ),
    );
    expect(calls, 1);
  });

  test('rejects a successful response that has no health status', () async {
    await expectLater(
      AgentHealthService.fetch(request: () async => http.Response('{}', 200)),
      throwsA(isA<ApiException>()),
    );
  });
}
