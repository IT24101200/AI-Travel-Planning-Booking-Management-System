import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/services/api_service.dart';
import 'package:http/http.dart' as http;

void main() {
  tearDown(() {
    ApiService.mockGetPreferences = null;
    ApiService.mockTriggerAgentPipeline = null;
  });

  test('preference absence is represented as an empty 204 response', () async {
    ApiService.mockGetPreferences = () async => http.Response('', 204);

    final response = await ApiService.getPreferences();

    expect(response.statusCode, 204);
  });

  test('agent retry returns the accepted job response', () async {
    ApiService.mockTriggerAgentPipeline = (tripRequestId) async => {
      'statusCode': 202,
      'tripRequestId': tripRequestId,
      'status': 'Planning',
    };

    final result = await ApiService.triggerAgentPipeline(17);

    expect(result['statusCode'], 202);
    expect(result['tripRequestId'], 17);
  });
}
