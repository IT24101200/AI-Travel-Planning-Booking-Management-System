namespace backend.Services;

/// <summary>
/// Makes the repository's existing instant contract explicit at API boundaries.
/// The shared database currently stores application instants as UTC wall-clock
/// values in timestamp-without-time-zone columns. This helper marks those values
/// as UTC without changing the stored clock value or converting local schedules.
/// </summary>
public static class DateTimeContract
{
    public static DateTime AsStoredUtc(DateTime value) =>
        DateTime.SpecifyKind(value, DateTimeKind.Utc);

    public static DateTime? AsStoredUtc(DateTime? value) =>
        value.HasValue ? AsStoredUtc(value.Value) : null;
}
