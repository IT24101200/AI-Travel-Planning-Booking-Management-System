using System.Security.Claims;
using backend.DTOs;
using backend.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace backend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class TripRequestController : ControllerBase
    {
        private readonly ITripRequestService _tripRequestService;
        private readonly IPreferenceService _preferenceService;
        private readonly ICustomerService _customerService;
        private readonly IHttpClientFactory _httpClientFactory;
        private readonly IConfiguration _configuration;
        private readonly ILogger<TripRequestController> _logger;

        public TripRequestController(
            ITripRequestService tripRequestService,
            IPreferenceService preferenceService,
            ICustomerService customerService,
            IHttpClientFactory httpClientFactory,
            IConfiguration configuration,
            ILogger<TripRequestController> logger)
        {
            _tripRequestService = tripRequestService;
            _preferenceService = preferenceService;
            _customerService = customerService;
            _httpClientFactory = httpClientFactory;
            _configuration = configuration;
            _logger = logger;
        }

        /// <summary>
        /// Create a new trip request. Automatically kicks off the agent planning pipeline (Option A).
        /// </summary>
        [HttpPost]
        [ProducesResponseType(typeof(TripRequestDto), StatusCodes.Status201Created)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        public async Task<IActionResult> Create([FromBody] TripRequestCreateDto dto)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            var userId = GetUserId();

            // Verify customer exists
            if (!await _customerService.ExistsAsync(userId))
                return NotFound(new { message = "Customer profile not found." });

            try
            {
                var result = await _tripRequestService.CreateAsync(userId, dto);

                // Option A: Automatically trigger the multi-agent pipeline in the background
                TriggerAgentPipelineAsync(result);

                return StatusCode(StatusCodes.Status201Created, result);
            }
            catch (ArgumentException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unexpected error creating trip request for customer {UserId}", userId);
                return StatusCode(StatusCodes.Status500InternalServerError, new { message = ex.Message });
            }
        }

        /// <summary>
        /// List trip requests for the current customer.
        /// </summary>
        [HttpGet]
        [HttpGet("my")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> GetMyTripRequests(
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 10)
        {
            if (page < 1) page = 1;
            if (pageSize < 1) pageSize = 10;
            if (pageSize > 50) pageSize = 50;

            var userId = GetUserId();
            var trips = await _tripRequestService.GetByCustomerIdAsync(userId, page, pageSize);
            var totalCount = await _tripRequestService.GetCountByCustomerIdAsync(userId);

            return Ok(new
            {
                data = trips,
                totalCount,
                page,
                pageSize,
                totalPages = (int)Math.Ceiling((double)totalCount / pageSize)
            });
        }

        /// <summary>
        /// Get a specific trip request by ID.
        /// </summary>
        [HttpGet("{id}")]
        [ProducesResponseType(typeof(TripRequestDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> GetById(int id)
        {
            var userId = GetUserId();
            var trip = await _tripRequestService.GetStatusAsync(id, userId);

            if (trip == null)
                return NotFound(new { message = "Trip request not found." });

            return Ok(trip);
        }

        /// <summary>
        /// Get the current status of a trip request.
        /// </summary>
        [HttpGet("{id}/status")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> GetStatus(int id)
        {
            var userId = GetUserId();
            var trip = await _tripRequestService.GetStatusAsync(id, userId);

            if (trip == null)
                return NotFound(new { message = "Trip request not found." });

            return Ok(new
            {
                trip.Id,
                trip.Status,
                trip.RetryCount,
                trip.FailureReason,
                trip.CreatedAt
            });
        }

        /// <summary>
        /// Cancel a trip request.
        /// </summary>
        [HttpPatch("{id}/cancel")]
        [ProducesResponseType(typeof(TripRequestDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> Cancel(int id)
        {
            var userId = GetUserId();

            try
            {
                var result = await _tripRequestService.CancelAsync(id, userId);

                if (result == null)
                    return NotFound(new { message = "Trip request not found." });

                return Ok(result);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        /// <summary>
        /// Get agent execution logs for a trip request.
        /// </summary>
        [HttpGet("{id}/logs")]
        [HttpGet("/api/AgentLog/{id}")]
        [ProducesResponseType(typeof(List<AgentLogDto>), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> GetAgentLogs(int id)
        {
            var isStaff = User.IsInRole("TravelAgent") || User.IsInRole("Admin");
            var userId = isStaff ? null : GetUserId();
            var logs = await _tripRequestService.GetAgentLogsAsync(id, userId);

            return Ok(logs);
        }

        /// <summary>
        /// Search trip requests globally. TravelAgent or Admin only.
        /// </summary>
        [HttpGet("search")]
        [Authorize(Roles = "TravelAgent,Admin")]
        [ProducesResponseType(typeof(List<TripRequestDto>), StatusCodes.Status200OK)]
        public async Task<IActionResult> Search(
            [FromQuery] string? customerId,
            [FromQuery] int? destinationId,
            [FromQuery] string? status,
            [FromQuery] string? sortBy,
            [FromQuery] bool descending = false,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 10)
        {
            if (page < 1) page = 1;
            if (pageSize < 1) pageSize = 10;
            if (pageSize > 50) pageSize = 50;

            var trips = await _tripRequestService.SearchAsync(customerId, destinationId, status, sortBy, descending, page, pageSize);
            return Ok(trips);
        }

        /// <summary>
        /// Record an agent audit log entry.
        /// </summary>
        [HttpPost("agent-log")]
        [HttpPost("/api/AgentLog")]
        [AllowAnonymous]
        [ProducesResponseType(typeof(AgentLogDto), StatusCodes.Status200OK)]
        public async Task<IActionResult> AddAgentLog([FromBody] AgentLogCreateDto dto)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            var log = await _tripRequestService.AddAgentLogAsync(dto);
            return Ok(log);
        }

        /// <summary>
        /// Update TripRequest status and generated PlanJson from the agent pipeline.
        /// </summary>
        [HttpPatch("{id}/agent-update")]
        [AllowAnonymous]
        [ProducesResponseType(typeof(TripRequestDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> AgentUpdate(int id, [FromBody] TripRequestAgentUpdateDto dto)
        {
            var updated = await _tripRequestService.UpdateAgentPlanAsync(id, dto);
            if (updated == null)
                return NotFound(new { message = "Trip request not found." });

            return Ok(updated);
        }

        private void TriggerAgentPipelineAsync(TripRequestDto trip)
        {
            _ = Task.Run(async () =>
            {
                try
                {
                    var agentBaseUrl = _configuration["AGENT_SERVICE_URL"] ?? "http://127.0.0.1:8005";
                    var client = _httpClientFactory.CreateClient();
                    client.Timeout = TimeSpan.FromSeconds(5);

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
                        preferred_activities = preferredActivities
                    };

                    var content = new StringContent(
                        System.Text.Json.JsonSerializer.Serialize(payload),
                        System.Text.Encoding.UTF8,
                        "application/json");

                    var response = await client.PostAsync($"{agentBaseUrl}/run-pipeline-async", content);
                    if (response.IsSuccessStatusCode)
                    {
                        _logger.LogInformation("Dispatched TripRequest #{Id} to multi-agent pipeline.", trip.Id);
                    }
                    else
                    {
                        _logger.LogWarning("Agent service returned HTTP {Status} for TripRequest #{Id}.", response.StatusCode, trip.Id);
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogWarning("Could not trigger agent pipeline for TripRequest #{Id}: {Message}", trip.Id, ex.Message);
                }
            });
        }

        private string GetUserId()
        {
            return User.FindFirstValue(ClaimTypes.NameIdentifier)
                ?? throw new UnauthorizedAccessException("User ID not found in token.");
        }
    }
}
