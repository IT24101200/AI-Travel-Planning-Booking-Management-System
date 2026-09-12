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
        private readonly ICustomerService _customerService;

        public TripRequestController(ITripRequestService tripRequestService, ICustomerService customerService)
        {
            _tripRequestService = tripRequestService;
            _customerService = customerService;
        }

        /// <summary>
        /// Create a new trip request.
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
                return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
            }
            catch (ArgumentException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        /// <summary>
        /// List trip requests for the current customer.
        /// </summary>
        [HttpGet]
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
        [ProducesResponseType(typeof(List<AgentLogDto>), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> GetAgentLogs(int id)
        {
            var userId = GetUserId();
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

        private string GetUserId()
        {
            return User.FindFirstValue(ClaimTypes.NameIdentifier)
                ?? throw new UnauthorizedAccessException("User ID not found in token.");
        }
    }
}
