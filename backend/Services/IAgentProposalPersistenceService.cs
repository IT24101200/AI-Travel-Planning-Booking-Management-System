using System.Text.Json;

namespace backend.Services;

public interface IAgentProposalPersistenceService
{
    Task<AgentProposalPersistenceResult> PersistAsync(
        int tripRequestId,
        JsonElement planJson,
        int retryCount,
        CancellationToken cancellationToken = default);
}

public sealed class AgentProposalPersistenceResult
{
    public int TripRequestId { get; init; }
    public int ItineraryId { get; init; }
    public int BookingId { get; init; }
    public string BookingReference { get; init; } = string.Empty;
    public string BookingStatus { get; init; } = string.Empty;
    public bool AlreadyPersisted { get; init; }
}
