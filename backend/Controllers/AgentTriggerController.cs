using backend.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

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
            try
            {
                var client = _httpClientFactory.CreateClient();
                client.Timeout = AgentServiceTimeouts.Connection(_configuration);
                using var response = await client.GetAsync($"{agentBaseUrl.TrimEnd('/')}/health");
                var content = await response.Content.ReadAsStringAsync();
                return new ContentResult
                {
                    Content = content,
                    ContentType = "application/json",
                    StatusCode = (int)response.StatusCode
                };
            }
            catch (Exception ex)
            {
                return StatusCode(StatusCodes.Status503ServiceUnavailable, new
                {
                    status = "unavailable",
                    message = $"Agent service at {agentBaseUrl} could not be reached: {ex.Message}"
                });
            }
        }

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

            var authorization = Request.Headers.Authorization.ToString();
            const string bearerPrefix = "Bearer ";
            if (!authorization.StartsWith(bearerPrefix, StringComparison.OrdinalIgnoreCase))
            {
                return Unauthorized(new { message = "A Bearer token is required to run the agent pipeline." });
            }

            var accessToken = authorization[bearerPrefix.Length..].Trim();
            if (string.IsNullOrWhiteSpace(accessToken))
            {
                return Unauthorized(new { message = "The Bearer token is empty." });
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
                raw_request_text = trip.RawRequestText,
                start_date = trip.StartDate.ToString("o"),
                end_date = trip.EndDate.ToString("o"),
                traveller_count = trip.TravellerCount,
                budget_ceiling = (double)trip.BudgetCeiling,
                currency = trip.Currency,
                retry_count = trip.RetryCount,
                preferred_activities = preferredActivities,
                access_token = accessToken
            };

            var endpoint = runAsync ? $"{agentBaseUrl}/run-pipeline-async" : $"{agentBaseUrl}/run-pipeline";

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
                        details = responseBody
                    });
                }

                return Content(responseBody, "application/json");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to invoke agent service for TripRequest #{Id}", id);
                return StatusCode(StatusCodes.Status503ServiceUnavailable, new
                {
                    message = $"Agent service at {agentBaseUrl} could not be reached.",
                    error = ex.Message
                });
            }
        }
    }
}
