import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/utils/transport_leg_utils.dart';

void main() {
  test('orders multi-leg transport items by persisted leg index', () {
    final items = orderedTransportItems([
      {
        'id': 12,
        'itemType': 'Transport',
        'transportLegIndex': 1,
        'routeFrom': 'Dambulla',
        'routeTo': 'Arugam Bay',
      },
      {
        'id': 11,
        'itemType': 'Transport',
        'transportLegIndex': 0,
        'routeFrom': 'Colombo',
        'routeTo': 'Dambulla',
      },
    ]);

    expect(items.map(transportLegIndex), [0, 1]);
    expect(transportLegLabel(items[0]), 'Leg 1');
    expect(transportLegLabel(items[1]), 'Leg 2');
  });

  test('keeps legacy unindexed transport readable after indexed legs', () {
    final items = orderedTransportItems([
      {'id': 3, 'itemType': 2, 'transportType': 'Bus'},
      {'id': 2, 'itemType': 2, 'transportType': 'Van', 'transportLegIndex': 0},
    ]);

    expect(items.first['id'], 2);
    expect(items.last['id'], 3);
    expect(transportLegLabel(items.last), isNull);
  });
}
