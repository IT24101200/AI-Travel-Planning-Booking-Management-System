import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/services/currency_notifier.dart';

void main() {
  test('supports only LKR and USD and defaults to LKR', () {
    final notifier = CurrencyNotifier();
    expect(notifier.value, 'LKR');
    expect(notifier.normalize('usd'), 'USD');
    expect(notifier.normalize('EUR'), 'LKR');
  });

  test('formats LKR and USD using one reusable formatter', () {
    expect(formatMoney(150000, 'LKR'), 'LKR 150,000.00');
    expect(formatMoney(500, 'USD'), '\$500.00');
  });
}
