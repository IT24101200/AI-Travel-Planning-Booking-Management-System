using backend.DTOs;

namespace backend.Services;

public interface IAgentLogStreamService
{
    AgentLogSubscription Subscribe(int tripRequestId);
    void PublishAgentLog(AgentLogDto log);
    void PublishTripStatus(int tripRequestId, string status, string? failureReason = null);
}

public sealed record AgentLogStreamEvent(string EventName, object Payload);

public sealed class AgentLogSubscription : IDisposable
{
    internal AgentLogSubscription(
        System.Threading.Channels.ChannelReader<AgentLogStreamEvent> reader,
        Action dispose)
    {
        Reader = reader;
        _dispose = dispose;
    }

    internal System.Threading.Channels.ChannelReader<AgentLogStreamEvent> Reader { get; }
    private readonly Action _dispose;
    private int _disposed;

    public void Dispose()
    {
        if (Interlocked.Exchange(ref _disposed, 1) == 0)
            _dispose();
    }
}
