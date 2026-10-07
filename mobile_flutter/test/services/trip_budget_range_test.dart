import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/services/trip_budget_range.dart';

void main() {
  test('accepts the requested low and high budget boundaries', () {
    expect(const TripBudgetRange(35000, 50000).isValid, isTrue);
    expect(const TripBudgetRange(700000, 1000000).isValid, isTrue);
    expect(const TripBudgetRange(701000, 1000000).isValid, isFalse);
    expect(const TripBudgetRange(36000, 50000).isValid, isFalse);
  });

  test('minimum handle stops at seventy percent of maximum', () {
    final result = const TripBudgetRange(35000, 1000000).moveMinimum(900000);
    expect(result.minimum, 700000);
    expect(result.maximum, 1000000);
    expect(result.isValid, isTrue);
  });

  test('maximum handle cannot reduce the required gap', () {
    final result = const TripBudgetRange(35000, 100000).moveMaximum(40000);
    expect(result.minimum, 35000);
    expect(result.maximum, 50000);
    expect(result.isValid, isTrue);
  });

  test('rounding preserves the gap at intermediate budgets', () {
    final result = const TripBudgetRange(175000, 250000).moveMaximum(249000);
    expect(result.maximum, 250000);
    expect(result.isValid, isTrue);
    final minimum = const TripBudgetRange(35000, 51000).moveMinimum(36000);
    expect(minimum.minimum, 35000);
    expect(minimum.isValid, isTrue);
  });

  test('rejects out of bounds and non-finite budgets', () {
    expect(const TripBudgetRange(34000, 50000).isValid, isFalse);
    expect(const TripBudgetRange(35000, 1000001).isValid, isFalse);
    expect(const TripBudgetRange(double.nan, 100000).isValid, isFalse);
  });
}
