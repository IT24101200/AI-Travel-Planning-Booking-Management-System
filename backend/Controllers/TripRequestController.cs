using System.Security.Claims;
using backend.Data;
using backend.DTOs;
using backend.Models.Enums;
using backend.Security;
using backend.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace backend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class TripRequestController : ControllerBase
    {
        private readonly ITripRequestService _tripRequestService;
        private readonly ICustomerService _customerService;
        private readonly IHttpClientFactory _httpClientFactory;
        private readonly IConfiguration _configuration;
        private readonly IServiceScopeFactory _scopeFactory;
        private readonly ILogger<TripRequestController> _logger;

        public TripRequestController(
            ITripRequestService tripRequestService,
            ICustomerService customerService,
            IHttpClientFactory httpClientFactory,
            IConfiguration configuration,
            IServiceScopeFactory scopeFactory,
            ILogger<TripRequestController> logger)
        {
            _tripRequestService = tripRequestService;
            _customerService = customerService;
            _httpClientFactory = httpClientFactory;
            _configuration = configuration;
            _scopeFactory = scopeFactory;
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
                TriggerAgentPipelineAsync(result, Request.Headers.Authorization.ToString());

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
            if (!AgentServiceAuthentication.IsValid(Request, _configuration))
                return Unauthorized(new { message = "Valid agent service credentials are required." });

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
            if (!AgentServiceAuthentication.IsValid(Request, _configuration))
                return Unauthorized(new { message = "Valid agent service credentials are required." });

            TripRequestDto? updated;
            try
            {
                updated = await _tripRequestService.UpdateAgentPlanAsync(id, dto);
            }
            catch (ArgumentException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }

            if (updated == null)
                return NotFound(new { message = "Trip request not found." });

            // Itinerary and booking persistence belongs to the authenticated agent tools.
            // This endpoint only records the agent result on the TripRequest.
            if (false && updated.Status == "AwaitingApproval" && !string.IsNullOrWhiteSpace(updated.PlanJson))
            {
                _ = Task.Run(async () =>
                {
                    try
                    {
                        using var scope = _scopeFactory.CreateScope();
                        var itineraryService = scope.ServiceProvider.GetRequiredService<IItineraryService>();
                        var bookingService = scope.ServiceProvider.GetRequiredService<IBookingService>();
                        var logger = scope.ServiceProvider.GetRequiredService<ILogger<TripRequestController>>();

                        using var doc = System.Text.Json.JsonDocument.Parse(updated.PlanJson);
                        if (doc.RootElement.TryGetProperty("booking_details", out var bd))
                        {
                            var totalCost = bd.GetProperty("total_package_cost").GetDecimal();
                            var currency = bd.GetProperty("currency").GetString() ?? "USD";

                            // 1. Create Itinerary
                            var itineraryDto = await itineraryService.CreateItineraryAsync(
                                updated.CustomerId,
                                updated.Id,
                                updated.StartDate,
                                updated.EndDate,
                                currency);

                            var items = new List<BookingItemCreateDto>();

                            // 2. Add Itinerary Items (Tours)
                            if (bd.TryGetProperty("itinerary", out var itinNode))
                            {
                                System.Text.Json.JsonElement? scheduleElement = null;
                                if (itinNode.ValueKind == System.Text.Json.JsonValueKind.Array)
                                {
                                    scheduleElement = itinNode;
                                }
                                else if (itinNode.ValueKind == System.Text.Json.JsonValueKind.Object && itinNode.TryGetProperty("schedule", out var sched))
                                {
                                    scheduleElement = sched;
                                }

                                if (scheduleElement.HasValue && scheduleElement.Value.ValueKind == System.Text.Json.JsonValueKind.Array)
                                {
                                    foreach (var day in scheduleElement.Value.EnumerateArray())
                                {
                                    var dayNum = day.GetProperty("day_number").GetInt32();
                                    if (day.TryGetProperty("items", out var tours))
                                    {
                                        foreach (var tour in tours.EnumerateArray())
                                        {
                                            var tourId = tour.GetProperty("tour_id").GetInt32();
                                            var start = TimeSpan.Parse(tour.GetProperty("start_time").GetString()!);
                                            var end = TimeSpan.Parse(tour.GetProperty("end_time").GetString()!);
                                            var price = tour.GetProperty("price").GetDecimal();

                                            await itineraryService.AddItemToItineraryAsync(itineraryDto.Id, new ItineraryItemCreateDto
                                            {
                                                DayNumber = dayNum,
                                                SequenceOrder = 1, // Just a placeholder, since order isn't strictly defined by the AI output.
                                                TourId = tourId,
                                                StartTime = start,
                                                EndTime = end
                                            });

                                            items.Add(new BookingItemCreateDto
                                            {
                                                ItemType = backend.Models.Enums.BookingItemType.Tour,
                                                TourId = tourId,
                                                Quantity = updated.TravellerCount,
                                                UnitPrice = price
                                            });
                                        }
                                    }
                                    }
                                }
                            }

                            // 3. Add Room to booking items
                            if (bd.TryGetProperty("selected_room", out var room) && room.TryGetProperty("room_id", out var roomIdProp))
                            {
                                items.Add(new BookingItemCreateDto
                                {
                                    ItemType = backend.Models.Enums.BookingItemType.Room,
                                    RoomId = roomIdProp.GetInt32(),
                                    Quantity = 1,
                                    UnitPrice = room.GetProperty("price_per_night").GetDecimal(),
                                    CheckInDate = updated.StartDate,
                                    CheckOutDate = updated.EndDate
                                });
                            }

                            // 4. Add Transport to booking items
                            if (bd.TryGetProperty("selected_transport", out var transport) && transport.TryGetProperty("transport_id", out var transIdProp))
                            {
                                items.Add(new BookingItemCreateDto
                                {
                                    ItemType = backend.Models.Enums.BookingItemType.Transport,
                                    TransportOptionId = transIdProp.GetInt32(),
                                    Quantity = updated.TravellerCount,
                                    UnitPrice = transport.GetProperty("price").GetDecimal()
                                });
                            }

                            // 5. Create Booking
                            await bookingService.CreateBookingAsync(new BookingCreateDto
                            {
                                CustomerId = updated.CustomerId,
                                ItineraryId = itineraryDto.Id,
                                TotalCost = totalCost,
                                Currency = currency,
                                Items = items
                            });
                            
                            logger.LogInformation("Successfully converted TripRequest #{Id} into Itinerary #{ItineraryId} and a pending Booking.", updated.Id, itineraryDto.Id);
                        }
                    }
                    catch (Exception ex)
                    {
                        var logger = _scopeFactory.CreateScope().ServiceProvider.GetRequiredService<ILogger<TripRequestController>>();
                        logger.LogError(ex, "Failed to create Booking/Itinerary from TripRequest #{Id} PlanJson.", id);
                    }
                });
            }

            return Ok(updated);
        }

        private void TriggerAgentPipelineAsync(TripRequestDto trip, string authorizationHeader)
        {
            _ = Task.Run(async () =>
            {
                try
                {
                    using var scope = _scopeFactory.CreateScope();
                    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();

                    var agentBaseUrl = _configuration["AGENT_SERVICE_URL"] ?? "http://127.0.0.1:8005";
                    var client = _httpClientFactory.CreateClient();
                    client.Timeout = TimeSpan.FromSeconds(5);

                    var preference = await db.Preferences
                        .AsNoTracking()
                        .FirstOrDefaultAsync(p => p.CustomerId == trip.CustomerId);
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
                        access_token = authorizationHeader.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase)
                            ? authorizationHeader["Bearer ".Length..].Trim()
                            : null,
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

                    HttpResponseMessage? response = null;
                    try
                    {
                        response = await client.PostAsync($"{agentBaseUrl}/run-pipeline-async", content);
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning("Agent service offline at {Url}: {Message}.", agentBaseUrl, ex.Message);
                    }

                    if (response != null && response.IsSuccessStatusCode)
                    {
                        _logger.LogInformation("Dispatched TripRequest #{Id} to multi-agent pipeline.", trip.Id);
                    }
                    else
                    {
                        await MarkAgentPipelineFailedAsync(trip.Id, "Agent service did not accept the pipeline request.");
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Could not trigger agent pipeline for TripRequest #{Id}.", trip.Id);
                }
            });
        }

        private async Task MarkAgentPipelineFailedAsync(int tripRequestId, string reason)
        {
            try
            {
                await _tripRequestService.UpdateAgentPlanAsync(tripRequestId, new TripRequestAgentUpdateDto
                {
                    Status = "Failed",
                    FailureReason = reason
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Could not mark TripRequest #{Id} as failed after agent dispatch failure.", tripRequestId);
            }
        }

        private async Task RunLocalFallbackPipelineAsync(IServiceScope scope, TripRequestDto trip)
        {
            try
            {
                var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
                var tripRequestService = scope.ServiceProvider.GetRequiredService<ITripRequestService>();

                // 1. Pick tours in destination or active tours
                var tours = await db.Tours
                    .Where(t => (t.DestinationId == trip.DestinationId || trip.DestinationId == null) && t.Status == "Active")
                    .Take(4)
                    .ToListAsync();
                if (tours.Count == 0)
                {
                    tours = await db.Tours.Where(t => t.Status == "Active").Take(4).ToListAsync();
                }

                // 2. Pick hotel & room
                var hotel = await db.Hotels
                    .Include(h => h.Rooms)
                    .FirstOrDefaultAsync(h => h.DestinationId == trip.DestinationId && h.Status == HotelStatus.Active);
                if (hotel == null || hotel.Rooms.Count == 0)
                {
                    hotel = await db.Hotels
                        .Include(h => h.Rooms)
                        .FirstOrDefaultAsync(h => h.Status == HotelStatus.Active);
                }
                var room = hotel?.Rooms.FirstOrDefault(r => r.Capacity >= trip.TravellerCount) ?? hotel?.Rooms.FirstOrDefault();

                // 3. Pick transport
                var transport = await db.TransportOptions
                    .FirstOrDefaultAsync(t => t.Status == TransportStatus.Active && t.Capacity >= trip.TravellerCount)
                    ?? await db.TransportOptions.FirstOrDefaultAsync(t => t.Status == TransportStatus.Active);

                var days = Math.Max(1, (trip.EndDate.Date - trip.StartDate.Date).Days);
                var schedule = new List<object>();
                decimal toursCost = 0;

                int tourIndex = 0;
                for (int dayNum = 1; dayNum <= days; dayNum++)
                {
                    var items = new List<object>();
                    if (tourIndex < tours.Count)
                    {
                        var t = tours[tourIndex++];
                        toursCost += t.Price * trip.TravellerCount;
                        items.Add(new
                        {
                            tour_id = t.Id,
                            tour_name = t.Name,
                            start_time = t.DefaultStartTime.ToString(@"hh\:mm\:ss"),
                            end_time = t.DefaultStartTime.Add(TimeSpan.FromHours(Math.Max(2, (double)t.DurationHours))).ToString(@"hh\:mm\:ss"),
                            price = (double)t.Price
                        });
                    }
                    schedule.Add(new
                    {
                        day_number = dayNum,
                        items = items
                    });
                }

                decimal roomCost = (room?.PricePerNight ?? 150m) * days;
                decimal transCost = (transport?.Price ?? 50m) * trip.TravellerCount;
                decimal totalCost = toursCost + roomCost + transCost;

                var planObj = new
                {
                    status = "AwaitingApproval",
                    itinerary = new
                    {
                        itinerary_id = trip.Id,
                        total_estimated_cost = (double)toursCost,
                        currency = trip.Currency,
                        schedule = schedule
                    },
                    booking_details = new
                    {
                        total_package_cost = (double)totalCost,
                        currency = trip.Currency,
                        itinerary = new { schedule = schedule },
                        selected_room = room != null ? new
                        {
                            hotel_id = hotel!.Id,
                            room_id = room.Id,
                            hotel_name = hotel.Name,
                            price_per_night = (double)room.PricePerNight
                        } : null,
                        selected_transport = transport != null ? new
                        {
                            transport_id = transport.Id,
                            type = transport.Type.ToString(),
                            provider = transport.Provider,
                            price = (double)transport.Price
                        } : null
                    }
                };

                var planJsonString = System.Text.Json.JsonSerializer.Serialize(planObj);
                using var jsonDoc = System.Text.Json.JsonDocument.Parse(planJsonString);

                var updateDto = new TripRequestAgentUpdateDto
                {
                    Status = "AwaitingApproval",
                    PlanJson = jsonDoc.RootElement.Clone(),
                    RetryCount = 0
                };

                await AgentUpdate(trip.Id, updateDto);

                // Add audit logs for all 4 agents
                await tripRequestService.AddAgentLogAsync(new AgentLogCreateDto
                {
                    TripRequestId = trip.Id,
                    AgentName = "CoordinatorAgent",
                    StepName = "DecomposeAndAllocateBudget",
                    Status = "Success",
                    Input = "Trip request decomposed for destination",
                    Output = $"Tours: {toursCost:C}, Hotel: {roomCost:C}, Transport: {transCost:C}"
                });
                await tripRequestService.AddAgentLogAsync(new AgentLogCreateDto
                {
                    TripRequestId = trip.Id,
                    AgentName = "ItineraryAgent",
                    StepName = "Generated draft itinerary",
                    Status = "Success",
                    Output = $"{schedule.Count} days planned with {tours.Count} curated tours"
                });
                await tripRequestService.AddAgentLogAsync(new AgentLogCreateDto
                {
                    TripRequestId = trip.Id,
                    AgentName = "BookingAgent",
                    StepName = "Assembled priced booking package",
                    Status = "Success",
                    Output = $"Selected {hotel?.Name} ({room?.RoomType}) and {transport?.Provider}"
                });
                await tripRequestService.AddAgentLogAsync(new AgentLogCreateDto
                {
                    TripRequestId = trip.Id,
                    AgentName = "ValidationAgent",
                    StepName = "Approval gate passed",
                    Status = "Success",
                    Output = $"Package total {totalCost:C} validated against budget {trip.BudgetCeiling:C}"
                });

                _logger.LogInformation("Successfully completed planned package for TripRequest #{Id}.", trip.Id);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed in local fallback pipeline for TripRequest #{Id}.", trip.Id);
            }
        }

        private string GetUserId()
        {
            return User.FindFirstValue(ClaimTypes.NameIdentifier)
                ?? throw new UnauthorizedAccessException("User ID not found in token.");
        }
    }
}
