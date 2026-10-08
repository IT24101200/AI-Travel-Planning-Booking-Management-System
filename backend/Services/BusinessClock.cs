namespace backend.Services;

/// <summary>
/// Calendar policy for Sri Lanka travel operations. This is used only for
/// date-only eligibility rules; it does not convert stored instants or local
/// transport schedules.
/// </summary>
public static class BusinessClock
{
    public const string IanaTimeZoneId = "Asia/Colombo";

    private static readonly TimeZoneInfo SriLankaTimeZone = ResolveTimeZone();

    public static DateOnly Today =>
        DateOnly.FromDateTime(TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, SriLankaTimeZone));

    private static TimeZoneInfo ResolveTimeZone()
    {
        try
        {
            return TimeZoneInfo.FindSystemTimeZoneById(IanaTimeZoneId);
        }
        catch (TimeZoneNotFoundException)
        {
            return TimeZoneInfo.FindSystemTimeZoneById("Sri Lanka Standard Time");
        }
        catch (InvalidTimeZoneException)
        {
            return TimeZoneInfo.FindSystemTimeZoneById("Sri Lanka Standard Time");
        }
    }
}
