import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/services/date_time_contract.dart';

void main() {
  test('instant parser handles explicit UTC and legacy no-offset UTC', () {
    expect(parseInstant('2026-10-08T12:00:00Z')!.toUtc().hour, 12);
    expect(parseInstant('2026-10-08T12:00:00')!.toUtc().hour, 12);
    expect(parseInstant('2026-10-08T12:00:00+05:30')!.toUtc().hour, 6);
  });

  test('date-only parser preserves the calendar date', () {
    final date = parseDateOnly('2026-10-15T00:00:00Z');
    expect(date, isNotNull);
    expect('${date!.year}-${date.month}-${date.day}', '2026-10-15');
  });

  test('local schedule parser preserves wall-clock components', () {
    final schedule = parseLocalSchedule('2026-10-15T08:00:00');
    expect(schedule, isNotNull);
    expect(schedule!.hour, 8);
    expect(schedule.minute, 0);
  });
}
