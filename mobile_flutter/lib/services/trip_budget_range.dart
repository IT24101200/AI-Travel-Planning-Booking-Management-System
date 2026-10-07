class TripBudgetRange {
  const TripBudgetRange(this.minimum, this.maximum);

  static const lowerLimit = 35000.0;
  static const upperLimit = 1000000.0;
  static const minimumMaximum = 50000.0;
  static const maximumMinimumRatio = 0.70;

  final double minimum;
  final double maximum;

  bool get isValid =>
      minimum.isFinite &&
      maximum.isFinite &&
      minimum >= lowerLimit &&
      maximum >= minimumMaximum &&
      maximum <= upperLimit &&
      minimum * 10 <= maximum * 7;

  TripBudgetRange moveMinimum(double value) {
    final rounded = (value / 1000).round() * 1000.0;
    final allowed = (maximum * 7 / 10 / 1000).floor() * 1000.0;
    return TripBudgetRange(rounded.clamp(lowerLimit, allowed), maximum);
  }

  TripBudgetRange moveMaximum(double value) {
    final rounded = (value / 1000).round() * 1000.0;
    final required = (minimum * 10 / 7 / 1000).ceil() * 1000.0;
    return TripBudgetRange(minimum, rounded.clamp(required, upperLimit));
  }
}
