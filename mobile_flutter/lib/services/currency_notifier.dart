import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class CurrencyNotifier extends ValueNotifier<String> {
  CurrencyNotifier() : super('LKR');

  static const supported = <String>['LKR', 'USD'];

  String normalize(String? currency) => supported.contains(currency?.toUpperCase())
      ? currency!.toUpperCase()
      : 'LKR';

  void setCurrency(String? currency) => value = normalize(currency);
}

String formatMoney(num? amount, String currency) {
  final code = CurrencyNotifier().normalize(currency);
  final formatted = NumberFormat('#,##0.00', 'en_US').format(amount ?? 0);
  return code == 'USD' ? '\$$formatted' : 'LKR $formatted';
}
