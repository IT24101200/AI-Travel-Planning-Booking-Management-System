import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:mobile_flutter/services/api_service.dart';

void main() {
  tearDown(() {
    ApiService.mockGetTransportOptions = null;
    ApiService.mockGetTransportPage = null;
  });

  http.Response transportPage(List<int> ids, int totalPages) => http.Response(
        jsonEncode({
          'data': ids.map((id) => {'id': id, 'status': 'Active'}).toList(),
          'totalPages': totalPages,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );

  test('follows every page and deduplicates transport IDs', () async {
    final requestedPages = <int>[];
    ApiService.mockGetTransportPage = ({
      required int page,
      required int pageSize,
      String? currency,
    }) async {
      requestedPages.add(page);
      return switch (page) {
        1 => transportPage(List.generate(10, (index) => index + 1), 3),
        2 => transportPage([10, ...List.generate(10, (index) => index + 11)], 3),
        _ => transportPage([21, 22], 3),
      };
    };

    final result = await ApiService.getTransportOptions(currency: 'LKR');

    expect(result.map((item) => item['id']), orderedEquals(List.generate(22, (i) => i + 1)));
    expect(requestedPages, [1, 2, 3]);
  });

  test('later page failure is surfaced instead of returning partial results', () async {
    ApiService.mockGetTransportPage = ({
      required int page,
      required int pageSize,
      String? currency,
    }) async {
      if (page == 1) return transportPage([1], 2);
      throw const ApiException(
        'The service is temporarily unavailable. Please retry.',
        errorCode: 'NETWORK_ERROR',
      );
    };

    await expectLater(
      ApiService.getTransportOptions(),
      throwsA(
        isA<ApiException>().having(
          (error) => error.errorCode,
          'errorCode',
          'NETWORK_ERROR',
        ),
      ),
    );
  });

  test('malformed pagination metadata fails safely', () async {
    ApiService.mockGetTransportPage = ({
      required int page,
      required int pageSize,
      String? currency,
    }) async => transportPage([1], 101);

    await expectLater(
      ApiService.getTransportOptions(),
      throwsA(
        isA<ApiException>().having(
          (error) => error.errorCode,
          'errorCode',
          'TRANSPORT_PAGINATION_INVALID',
        ),
      ),
    );
  });
}
