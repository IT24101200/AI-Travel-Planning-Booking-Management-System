using backend.DTOs;
using backend.Services;
using Xunit;

namespace backend.Tests;

public class AgentLogStreamServiceTests
{
    [Fact]
    public async Task SubscribersReceiveOnlyTheirTripEvents()
    {
        var service = new AgentLogStreamService();
        using var first = service.Subscribe(57);
        using var second = service.Subscribe(58);

        var log = new AgentLogDto { Id = Guid.NewGuid(), TripRequestId = 57, AgentName = "BookingAgent", Status = "Success" };
        service.PublishAgentLog(log);

        Assert.True(await first.Reader.WaitToReadAsync());
        Assert.True(first.Reader.TryRead(out var firstEvent));
        Assert.Equal("agent-log", firstEvent.EventName);
        Assert.False(second.Reader.TryRead(out _));
    }

    [Fact]
    public async Task StatusEventsAreDeliveredAndDisposeCompletesSubscriber()
    {
        var service = new AgentLogStreamService();
        var subscription = service.Subscribe(57);

        service.PublishTripStatus(57, "Failed", "A safe failure reason");
        Assert.True(await subscription.Reader.WaitToReadAsync());
        Assert.True(subscription.Reader.TryRead(out var statusEvent));
        Assert.Equal("trip-status", statusEvent.EventName);

        subscription.Dispose();
        Assert.False(await subscription.Reader.WaitToReadAsync());
    }
}
