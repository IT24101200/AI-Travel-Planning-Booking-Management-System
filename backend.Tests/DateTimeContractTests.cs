using System.Text.Json;
using backend.DTOs;
using backend.Services;

namespace backend.Tests;

public sealed class DateTimeContractTests
{
    [Fact]
    public void StoredUtc_marks_database_wall_clock_as_utc_without_shifting_it()
    {
        var stored = new DateTime(2026, 10, 8, 12, 0, 0, DateTimeKind.Unspecified);

        var result = DateTimeContract.AsStoredUtc(stored);

        Assert.Equal(stored.Ticks, result.Ticks);
        Assert.Equal(DateTimeKind.Utc, result.Kind);
    }

    [Fact]
    public void Notification_instant_serializes_with_an_unambiguous_utc_marker()
    {
        var dto = new NotificationDto
        {
            SentAt = DateTimeContract.AsStoredUtc(
                new DateTime(2026, 10, 8, 12, 0, 0, DateTimeKind.Unspecified))
        };

        var json = JsonSerializer.Serialize(dto);

        Assert.Contains("2026-10-08T12:00:00Z", json);
    }

    [Fact]
    public void Agent_log_input_preserves_the_supplied_offset()
    {
        var dto = JsonSerializer.Deserialize<AgentLogCreateDto>(
            "{\"Timestamp\":\"2026-10-08T12:00:00+05:30\"}");

        Assert.NotNull(dto?.Timestamp);
        Assert.Equal(6, dto!.Timestamp.Value.UtcDateTime.Hour);
        Assert.Equal(30, dto.Timestamp.Value.UtcDateTime.Minute);
    }
}
