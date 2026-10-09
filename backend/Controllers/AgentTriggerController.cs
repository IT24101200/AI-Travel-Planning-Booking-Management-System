using backend.Services;
using backend.DTOs;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Diagnostics;
using System.Security.Claims;
using System.Text.Json;

namespace backend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AgentTriggerController : ControllerBase
    {
        private readonly ITripRequestService _tripRequestService;
        private readonly IPreferenceService _preferenceService;
        private readonly IHttpClientFactory _httpClientFactory;
        private readonly IConfiguration _configuration;
        private readonly ILogger<AgentTriggerController> _logger;

        public AgentTriggerController(
            ITripRequestService tripRequestService,
            IPreferenceService preferenceService,
            IHttpClientFactory httpClientFactory,
            IConfiguration configuration,
            ILogger<AgentTriggerController> logger)
        {
            _tripRequestService = tripRequestService;
            _preferenceService = preferenceService;
            _httpClientFactory = httpClientFactory;
            _configuration = configuration;
            _logger = logger;
        }

        /// <summary>
        /// Check agent service health and connectivity.
        /// </summary>
        [HttpGet("health")]
        [AllowAnonymous]
        public async Task<IActionResult> CheckAgentHealth()
        {
            var agentBaseUrl = _configuration["AGENT_SERVICE_URL"] ?? "http://127.0.0.1:8005";
            var checkedAtUtc = DateTime.UtcNow;
            var stopwatch = Stopwatch.StartNew();

            try
            {
                var client = _httpClientFactory.CreateClient();
                client.Timeout = AgentServiceTimeouts.Connection(_configuration);
                using var response = await client.GetAsync($"{agentBaseUrl.TrimEnd('/')}/health");
                var content = await response.Content.ReadAsStringAsync();

                stopwatch.Stop();
                var isHealthyResponse = response.IsSuccessStatusCode && HasHealthyStatus(content);
                var latencyMs = ToLatencyMilliseconds(stopwatch.Elapsed);
                var status = isHealthyResponse
                    ? stopwatch.Elapsed <= AgentServiceTimeouts.HealthDegradedThreshold(_configuration)
                        ? "connected"
                        : "degraded"
                    : "unavailable";

                return Ok(new AgentConnectionStatusDto
                {
                    Status = status,
                    Reachable = isHealthyResponse,
                    LatencyMs = latencyMs,
                    CheckedAtUtc = checkedAtUtc
                });
            }
            catch (Exception ex)
            {
                stopwatch.Stop();
                _logger.LogWarning(ex, "Agent health check failed for {AgentBaseUrl}.", agentBaseUrl);
                return Ok(new AgentConnectionStatusDto
                {
                    Status = "unavailable",
                    Reachable = false,
                    LatencyMs = null,
                    CheckedAtUtc = checkedAtUtc
                });
            }
        }

        private static bool HasHealthyStatus(string content)
        {
            try
            {
                using var document = JsonDocument.Parse(content);
                if (document.RootElement.ValueKind != JsonValueKind.Object ||
                    !document.RootElement.TryGetProperty("status", out var status))
                    return false;

                var value = status.GetString();
                return string.Equals(value, "healthy", StringComparison.OrdinalIgnoreCase) ||
                    string.Equals(value, "ok", StringComparison.OrdinalIgnoreCase) ||
                    string.Equals(value, "connected", StringComparison.OrdinalIgnoreCase);
            }
            catch (JsonException)
            {
                return false;
            }
        }

        private static int ToLatencyMilliseconds(TimeSpan elapsed) =>
            elapsed.TotalMilliseconds <= 0
                ? 0
                : (int)Math.Min(int.MaxValue, Math.Ceiling(elapsed.TotalMilliseconds));

        /// <summary>
        /// Manually trigger the multi-agent planning pipeline for a specific trip request.
        /// </summary>
        [HttpPost("trigger/{id}")]
        [Authorize]
        public async Task<IActionResult> TriggerPipeline(int id, [FromQuery] bool runAsync = false)
        {
            var trip = await _tripRequestService.GetByIdAsync(id);
            if (trip == null)
            {
                return NotFound(new { message = $"Trip request #{id} not found." });
            }

            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var isStaff = User.IsInRole("TravelAgent") || User.IsInRole("Admin");
            if (!isStaff && (string.IsNullOrWhiteSpace(userId) || trip.CustomerId != userId))
            {
                return Forbid();
            }

            if (runAsync && string.Equals(trip.Status, "Planning", StringComparison.OrdinalIgnoreCase))
                return Conflict(new { message = "This trip request is already being planned." });

            if (runAsync && string.Equals(trip.Status, "Failed", StringComparison.OrdinalIgnoreCase))
            {
                try
                {
                    var retry = await _tripRequestService.UpdateAgentPlanAsync(id, new TripRequestAgentUpdateDto
                    {
                        Status = "Planning",
                        RetryCount = trip.RetryCount + 1,
                        FailureReason = null
                    });
                    if (retry == null)
                        return NotFound(new { message = $"Trip request #{id} not found." });
                    trip = retry;
                }
                catch (InvalidOperationException ex)
                {
                    _logger.LogWarning(ex, "TripRequest #{TripRequestId} could not be retried.", id);
                    return Conflict(new { message = "This trip request cannot be retried yet." });
                }
            }

            var agentBaseUrl = _configuration["AGENT_SERVICE_URL"] ?? "http://127.0.0.1:8005";
            var client = _httpClientFactory.CreateClient();
            client.Timeout = runAsync
                ? AgentServiceTimeouts.Connection(_configuration)
                : AgentServiceTimeouts.Pipeline(_configuration);

            var preference = await _preferenceService.GetByCustomerIdAsync(trip.CustomerId);
            var preferredActivities = string.IsNullOrWhiteSpace(preference?.PreferredActivities)
                ? Array.Empty<string>()
                : preference.PreferredActivities
                    .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

            var payload = new
            {
                trip_request_id = trip.Id,
                customer_id = trip.CustomerId,
                destination_id = trip.DestinationId,
                destination_name = trip.DestinationName ?? "Destination",
                destination_ids = trip.DestinationIds,
                requested_destinations = trip.Destinations.Select(destination => new
                {
                    destination_id = destination.Id,
                    destination_name = destination.Name,
                    order = destination.Order,
                    is_starter = destination.IsStarter
                }),
                starter_location_id = trip.StarterLocationId,
                raw_request_text = trip.RawRequestText,
                start_date = trip.StartDate.ToString("o"),
                end_date = trip.EndDate.ToString("o"),
                traveller_count = trip.TravellerCount,
                budget_ceiling = (double)trip.BudgetCeiling,
                currency = trip.Currency,
                airport_pickup = trip.AirportPickup,
                airport_code = trip.AirportCode,
                airport_arrival_time = trip.AirportArrivalTime.ToString(@"hh\:mm"),
                retry_count = trip.RetryCount,
                preferred_activities = preferredActivities
            };

            _logger.LogInformation(
                "Dispatching TripRequest #{TripRequestId} with {DestinationCount} destination(s): {DestinationIds}.",
                trip.Id,
                trip.DestinationIds.Count,
                string.Join(",", trip.DestinationIds));

            var endpoint = runAsync
                ? $"{agentBaseUrl.TrimEnd('/')}/run-pipeline-async"
                : $"{agentBaseUrl.TrimEnd('/')}/run-pipeline";

            try
            {
                var jsonContent = new StringContent(
                    System.Text.Json.JsonSerializer.Serialize(payload),
                    System.Text.Encoding.UTF8,
                    "application/json");

                var response = await client.PostAsync(endpoint, jsonContent);
                var responseBody = await response.Content.ReadAsStringAsync();

                if (!response.IsSuccessStatusCode)
                {
                    return StatusCode((int)response.StatusCode, new
                    {
                        message = "Agent service returned an error.",
                        tripRequestId = id
                    });
                }

                return new ContentResult
                {
                    Content = responseBody,
                    ContentType = "application/json",
                    StatusCode = (int)response.StatusCode
                };
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to invoke agent service for TripRequest #{Id}", id);
                return StatusCode(StatusCodes.Status503ServiceUnavailable, new
                {
                    message = "The planning service is temporarily unavailable.",
                    tripRequestId = id
                });
            }
        }
    }
}
