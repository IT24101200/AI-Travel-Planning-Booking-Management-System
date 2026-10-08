using System.Text.Json;
using System.Text.Json.Nodes;
using backend.Models;

namespace backend.Services;

public static class CustomerRevisionContract
{
    public static JsonObject? Read(TripRequest trip)
    {
        if (string.IsNullOrWhiteSpace(trip.PlanJson)) return null;
        return JsonNode.Parse(trip.PlanJson)?["revision_request"] as JsonObject;
    }

    public static bool Pending(JsonObject? request) => request?["status"]?.GetValue<string>() == "Pending";

    public static void ValidateCallback(TripRequest trip, JsonElement? proposal)
    {
        var expected = Read(trip);
        var incomingId = proposal.HasValue && proposal.Value.ValueKind == JsonValueKind.Object &&
            proposal.Value.TryGetProperty("revision_request", out var revision) && revision.ValueKind == JsonValueKind.Object &&
            revision.TryGetProperty("id", out var id) && id.ValueKind == JsonValueKind.String ? id.GetString() : null;
        if (expected is null && incomingId is null) return;
        if (incomingId != expected?["id"]?.GetValue<string>())
            throw new ProposalPersistenceException("STALE_REVISION", "This result belongs to an earlier planning request.");
    }
}
