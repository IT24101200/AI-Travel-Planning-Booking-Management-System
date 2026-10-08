/// Date/time parsing helpers for the three API field categories.
///
/// Instant fields are emitted with Z/offset after the backend remediation.
/// The no-offset fallback is intentionally only for legacy instant endpoints
/// whose database values are proven UTC wall-clock values. Do not use it for
/// date-only or local-schedule fields.
DateTime? parseInstant(Object? value) {
  if (value is DateTime) return value.isUtc ? value.toLocal() : value;
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) return null;

  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;

  final hasExplicitZone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(raw);
  if (hasExplicitZone) return parsed.toLocal();

  // Legacy instant payloads omitted the marker but were written from
  // DateTime.UtcNow. Reinterpret the unchanged wall-clock value as UTC.
  final asUtc = DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
    parsed.millisecond,
    parsed.microsecond,
  );
  return asUtc.toLocal();
}

/// Parses YYYY-MM-DD calendar values without applying timezone conversion.
DateTime? parseDateOnly(Object? value) {
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})',
  ).firstMatch(value?.toString().trim() ?? '');
  if (match == null) return null;
  final year = int.tryParse(match.group(1)!);
  final month = int.tryParse(match.group(2)!);
  final day = int.tryParse(match.group(3)!);
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

/// Parses an offset-less local schedule as wall-clock components.
DateTime? parseLocalSchedule(Object? value) {
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2}))?',
  ).firstMatch(value?.toString().trim() ?? '');
  if (match == null) return null;
  return DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
    int.parse(match.group(4)!),
    int.parse(match.group(5)!),
    int.tryParse(match.group(6) ?? '0') ?? 0,
  );
}
