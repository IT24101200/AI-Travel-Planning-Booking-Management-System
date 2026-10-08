import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/services/api_service.dart';

void main() {
  group('ApiService Tour pagination', () {
    test('encodes filters with page 1 and pageSize 20', () {
      final endpoint = ApiService.buildToursEndpoint(
        search: 'tea trail',
        sortBy: 'price',
        currency: 'LKR',
        page: 1,
        pageSize: 20,
      );
      final uri = Uri.parse('https://example.test/api/$endpoint');

      expect(uri.path, '/api/tour');
      expect(uri.queryParameters, {
        'search': 'tea trail',
        'sortBy': 'price',
        'currency': 'LKR',
        'page': '1',
        'pageSize': '20',
      });
    });

    test('keeps the existing no-parameter endpoint compatible', () {
      expect(ApiService.buildToursEndpoint(), 'tour');
    });
  });
}
