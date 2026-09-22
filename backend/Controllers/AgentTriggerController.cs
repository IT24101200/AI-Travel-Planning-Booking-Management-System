using backend.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace backend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AgentTriggerController : ControllerBase
    {
        private readonly ITripRequestService _tripRequestService;
        private readonly IHttpClientFactory _httpClientFactory;
        private readonly IConfiguration _configuration;
        private readonly ILogger<AgentTriggerController> _logger;

        public AgentTriggerController(
            ITripRequestService tripRequestService,
            IHttpClientFactory httpClientFactory,
            IConfiguration configuration,
            ILogger<AgentTriggerController> logger)
        {
            _tripRequestService = tripRequestService;
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
                client.Timeout = TimeSpan.FromSeconds(3);
                var response = await client.GetAsync($"{agentBaseUrl}/health");
                var content = await response.Content.ReadAsStringAsync();
                return Content(content, "application/json");
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

            var agentBaseUrl = _configuration["AGENT_SERVICE_URL"] ?? "http://127.0.0.1:8005";
            var client = _httpClientFactory.CreateClient();
            client.Timeout = TimeSpan.FromSeconds(runAsync ? 5 : 60);

            var payload = new
            {
                trip_request_id = trip.Id,
                customer_id = trip.CustomerId,
                destination_name = trip.DestinationName ?? "Destination",
                raw_request_text = trip.RawRequestText,
                start_date = trip.StartDate.ToString("o"),
                end_date = trip.EndDate.ToString("o"),
                traveller_count = trip.TravellerCount,
                budget_ceiling = (double)trip.BudgetCeiling,
                currency = trip.Currency,
                retry_count = trip.RetryCount
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
