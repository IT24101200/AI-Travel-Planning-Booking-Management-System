using System.Collections.Concurrent;
using System.Threading.Channels;
using backend.DTOs;

namespace backend.Services;

public sealed class AgentLogStreamService : IAgentLogStreamService
{
    private readonly ConcurrentDictionary<Guid, Subscriber> _subscribers = new();

    public AgentLogSubscription Subscribe(int tripRequestId)
    {
        var id = Guid.NewGuid();
        var subscriber = new Subscriber(tripRequestId);
        _subscribers[id] = subscriber;
        return new AgentLogSubscription(subscriber.Channel.Reader, () =>
        {
            if (_subscribers.TryRemove(id, out var removed))
                removed.Channel.Writer.TryComplete();
        });
    }

    public void PublishAgentLog(AgentLogDto log)
    {
        foreach (var subscriber in _subscribers.Values)
        {
            if (subscriber.TripRequestId == log.TripRequestId)
                subscriber.Channel.Writer.TryWrite(new AgentLogStreamEvent("agent-log", log));
        }
    }

    public void PublishTripStatus(int tripRequestId, string status, string? failureReason = null)
    {
        var payload = new
        {
            tripRequestId,
            status,
            failureReason
        };

        foreach (var subscriber in _subscribers.Values)
        {
            if (subscriber.TripRequestId == tripRequestId)
                subscriber.Channel.Writer.TryWrite(new AgentLogStreamEvent("trip-status", payload));
        }
    }

    private sealed class Subscriber
    {
        public Subscriber(int tripRequestId)
        {
            TripRequestId = tripRequestId;
            Channel = System.Threading.Channels.Channel.CreateUnbounded<AgentLogStreamEvent>(
                new UnboundedChannelOptions { SingleReader = true, SingleWriter = false });
        }

        public int TripRequestId { get; }
        public Channel<AgentLogStreamEvent> Channel { get; }
    }
}
