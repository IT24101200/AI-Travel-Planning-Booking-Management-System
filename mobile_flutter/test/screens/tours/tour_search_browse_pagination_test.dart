import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_flutter/main.dart' show currencyNotifier;
import 'package:mobile_flutter/screens/tours/tour_search_browse_screen.dart';
import 'package:mobile_flutter/services/api_service.dart';

Map<String, dynamic> _tour(int id) => {
  'id': id,
  'name': 'Tour $id',
  'category': 'Heritage',
  'price': id * 1000,
  'currency': currencyNotifier.value,
  'durationHours': 4,
  'destinationName': 'Destination $id',
  'imageUrl': '',
};

List<dynamic> _tours(int start, int count) =>
    List<dynamic>.generate(count, (index) => _tour(start + index));

Widget _testApp() => const MaterialApp(home: TourSearchBrowseScreen());

SliverChildBuilderDelegate _catalogueDelegate(WidgetTester tester) {
  final list = tester.widget<ListView>(
    find.byKey(const Key('tour_catalogue_list')),
  );
  return list.childrenDelegate as SliverChildBuilderDelegate;
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    ApiService.mockGetTours = null;
    currencyNotifier.setCurrency('LKR');
  });

  tearDown(() {
    ApiService.mockGetTours = null;
    currencyNotifier.setCurrency('LKR');
  });

  testWidgets('initial page renders every returned tour', (tester) async {
    ApiService.mockGetTours =
        ({
          String? search,
          String? sortBy,
          String? currency,
          int? page,
          int? pageSize,
        }) async {
          expect(page, 1);
          expect(pageSize, 20);
          return _tours(1, 20);
        };

    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    expect(find.text('20 experiences'), findsOneWidget);
    expect(_catalogueDelegate(tester).childCount, 20);
    expect(find.byKey(const Key('tour_load_more_button')), findsOneWidget);
  });

  testWidgets('page 2 appends, deduplicates IDs, and updates itemCount', (
    tester,
  ) async {
    final requestedPages = <int?>[];
    ApiService.mockGetTours =
        ({
          String? search,
          String? sortBy,
          String? currency,
          int? page,
          int? pageSize,
        }) async {
          requestedPages.add(page);
          if (page == 1) return _tours(1, 20);
          return [_tour(20), ..._tours(21, 5)];
        };

    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tour_load_more_button')));
    await tester.pumpAndSettle();

    expect(requestedPages, [1, 2]);
    expect(find.text('25 experiences'), findsOneWidget);
    expect(_catalogueDelegate(tester).childCount, 25);
    expect(find.byKey(const Key('tour_load_more_button')), findsNothing);
  });

  testWidgets('a short initial page marks the catalogue complete', (
    tester,
  ) async {
    ApiService.mockGetTours =
        ({
          String? search,
          String? sortBy,
          String? currency,
          int? page,
          int? pageSize,
        }) async => _tours(1, 3);

    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    expect(find.text('3 experiences'), findsOneWidget);
    expect(find.byKey(const Key('tour_load_more_button')), findsNothing);
  });

  testWidgets('search resets accumulated pages and requests page 1', (
    tester,
  ) async {
    final calls = <({String? search, int? page})>[];
    ApiService.mockGetTours =
        ({
          String? search,
          String? sortBy,
          String? currency,
          int? page,
          int? pageSize,
        }) async {
          calls.add((search: search, page: page));
          if (search == 'Ella') return [_tour(99)];
          return _tours(page == 1 ? 1 : 21, 20);
        };

    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tour_load_more_button')));
    await tester.pumpAndSettle();
    expect(find.text('40 experiences'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Ella');
    await tester.pump(const Duration(milliseconds: 401));
    await tester.pumpAndSettle();

    expect(calls.last, (search: 'Ella', page: 1));
    expect(find.text('1 experiences'), findsOneWidget);
    expect(_catalogueDelegate(tester).childCount, 1);
  });

  testWidgets('sort and currency changes restart at page 1', (tester) async {
    final calls = <({String? sortBy, String? currency, int? page})>[];
    ApiService.mockGetTours =
        ({
          String? search,
          String? sortBy,
          String? currency,
          int? page,
          int? pageSize,
        }) async {
          calls.add((sortBy: sortBy, currency: currency, page: page));
          return _tours(1, 2);
        };

    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Price: Low to High'));
    await tester.pumpAndSettle();
    expect(calls.last, (sortBy: 'price', currency: 'LKR', page: 1));

    currencyNotifier.setCurrency('USD');
    await tester.pumpAndSettle();
    expect(calls.last, (sortBy: 'price', currency: 'USD', page: 1));
  });

  testWidgets('page 2 failure preserves page 1 and retry appends results', (
    tester,
  ) async {
    var pageTwoAttempts = 0;
    ApiService.mockGetTours =
        ({
          String? search,
          String? sortBy,
          String? currency,
          int? page,
          int? pageSize,
        }) async {
          if (page == 1) return _tours(1, 20);
          pageTwoAttempts++;
          if (pageTwoAttempts == 1) {
            throw const ApiException('Temporary failure');
          }
          return _tours(21, 2);
        };

    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tour_load_more_button')));
    await tester.pumpAndSettle();

    expect(find.text('20 experiences'), findsOneWidget);
    expect(_catalogueDelegate(tester).childCount, 20);
    expect(find.byKey(const Key('tour_load_more_error')), findsOneWidget);

    await tester.tap(find.byKey(const Key('tour_load_more_retry')));
    await tester.pumpAndSettle();

    expect(pageTwoAttempts, 2);
    expect(find.text('22 experiences'), findsOneWidget);
    expect(_catalogueDelegate(tester).childCount, 22);
    expect(find.byKey(const Key('tour_load_more_error')), findsNothing);
  });
}
