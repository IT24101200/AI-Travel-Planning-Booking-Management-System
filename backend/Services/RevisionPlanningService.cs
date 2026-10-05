using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using backend.Data;
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

        var payload = new
        {
            trip_request_id = trip.Id,
            customer_id = trip.CustomerId,
            destination_id = trip.DestinationId,
            destination_name = trip.Destination?.Name ?? "Destination",
            raw_request_text = trip.RawRequestText,
            start_date = trip.StartDate.ToString("o"),
            end_date = trip.EndDate.ToString("o"),
            traveller_count = trip.TravellerCount,
            budget_ceiling = (double)trip.BudgetCeiling,
            currency = trip.Currency,
            retry_count = 0,
            revision_feedback = revisionComment,
            preferred_activities = activities,
            access_token = authorizationHeader["Bearer ".Length..].Trim()
        };

        var baseUrl = _configuration["AGENT_SERVICE_URL"] ?? "http://127.0.0.1:8005";
        using var request = new HttpRequestMessage(HttpMethod.Post, $"{baseUrl}/run-pipeline-async")
        {
            Content = new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json")
        };
        request.Headers.Authorization = AuthenticationHeaderValue.Parse(authorizationHeader);

        var client = _httpClientFactory.CreateClient();
        client.Timeout = TimeSpan.FromSeconds(5);
        using var response = await client.SendAsync(request, cancellationToken);
        if (!response.IsSuccessStatusCode)
            throw new HttpRequestException($"Agent revision planning returned HTTP {(int)response.StatusCode}.");
    }

    private static bool authenticationHeaderIsBearer(string value) =>
        value.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase) && value.Length > "Bearer ".Length;
}
