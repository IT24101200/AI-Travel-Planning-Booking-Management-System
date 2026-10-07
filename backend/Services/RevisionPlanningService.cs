using System.Text;
using System.Text.Json;
using backend.Data;
using backend.Models;
using Microsoft.EntityFrameworkCore;

namespace backend.Services;

public sealed class RevisionPlanningService : IRevisionPlanningService
{
    private readonly AppDbContext _db;
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly IConfiguration _configuration;

    public RevisionPlanningService(AppDbContext db, IHttpClientFactory httpClientFactory, IConfiguration configuration)
    {
        _db = db;
        _httpClientFactory = httpClientFactory;
        _configuration = configuration;
    }

    public async Task TriggerAsync(int tripRequestId, string revisionComment, string authorizationHeader, CancellationToken cancellationToken = default)
    {
        var trip = await _db.TripRequests.Include(t => t.Destination)
            .SingleOrDefaultAsync(t => t.Id == tripRequestId, cancellationToken)
            ?? throw new KeyNotFoundException($"Trip request #{tripRequestId} was not found.");

        if (string.IsNullOrWhiteSpace(authorizationHeader) ||
            !authenticationHeaderIsBearer(authorizationHeader))
            throw new InvalidOperationException("A Bearer token is required to trigger revision planning.");

        var preference = await _db.Preferences.FirstOrDefaultAsync(p => p.CustomerId == trip.CustomerId, cancellationToken);
        var activities = string.IsNullOrWhiteSpace(preference?.PreferredActivities)
            ? Array.Empty<string>()
            : preference!.PreferredActivities.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

        var destinations = ParseDestinations(trip);

        var payload = new
        {
            trip_request_id = trip.Id,
            customer_id = trip.CustomerId,
            destination_id = trip.DestinationId,
            destination_name = trip.Destination?.Name ?? "Destination",
            destination_ids = destinations.Select(destination => destination.Id).ToArray(),
            requested_destinations = destinations.Select(destination => new
            {
                destination_id = destination.Id,
                destination_name = destination.Name,
                order = destination.Order
            }).ToArray(),
            raw_request_text = trip.RawRequestText,
            start_date = trip.StartDate.ToString("o"),
            end_date = trip.EndDate.ToString("o"),
            traveller_count = trip.TravellerCount,
            budget_ceiling = (double)trip.BudgetCeiling,
            currency = trip.Currency,
            retry_count = 0,
            revision_feedback = revisionComment,
            preferred_activities = activities,
        };

        var baseUrl = _configuration["AGENT_SERVICE_URL"] ?? "http://127.0.0.1:8005";
        using var request = new HttpRequestMessage(HttpMethod.Post, $"{baseUrl.TrimEnd('/')}/run-pipeline-async")
        {
            Content = new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json")
        };
        var client = _httpClientFactory.CreateClient();
        client.Timeout = AgentServiceTimeouts.Connection(_configuration);
        using var response = await client.SendAsync(request, cancellationToken);
        if (!response.IsSuccessStatusCode)
            throw new HttpRequestException($"Agent revision planning returned HTTP {(int)response.StatusCode}.");
    }

    private static bool authenticationHeaderIsBearer(string value) =>
        value.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase) && value.Length > "Bearer ".Length;

    private static List<TripRequestDestinationSelection> ParseDestinations(TripRequest trip)
    {
        if (!string.IsNullOrWhiteSpace(trip.DestinationSelectionsJson))
        {
            try
            {
                var parsed = JsonSerializer.Deserialize<List<TripRequestDestinationSelection>>(
                    trip.DestinationSelectionsJson);
                if (parsed is not null && parsed.Count > 0)
                    return parsed.OrderBy(destination => destination.Order).ToList();
            }
            catch (JsonException)
            {
                // Legacy rows use the singular FK below.
            }
        }

        return trip.DestinationId.HasValue
            ? new List<TripRequestDestinationSelection>
            {
                new()
                {
                    Id = trip.DestinationId.Value,
                    Name = trip.Destination?.Name ?? "Destination",
                    Order = 0
                }
            }
            : new List<TripRequestDestinationSelection>();
    }
}
