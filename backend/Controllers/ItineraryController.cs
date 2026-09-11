using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using backend.DTOs;
using backend.Models.Enums;
using backend.Services;

namespace backend.Controllers
{
    /// <summary>
    /// Manages Itineraries and their scheduled ItineraryItems.
    /// </summary>
    [ApiController]
    [Route("api/itinerary")]
    [Authorize]
    public class ItineraryController : ControllerBase
    {
        private readonly IItineraryService _service;

        public ItineraryController(IItineraryService service)
        {
            _service = service;
        }

        /// <summary>
        /// Creates a new Itinerary in Draft status.
        /// </summary>
        [HttpPost]
        [ProducesResponseType(typeof(ItineraryDto), StatusCodes.Status201Created)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        public async Task<IActionResult> Create([FromBody] CreateItineraryRequest request)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            var created = await _service.CreateItineraryAsync(
                request.CustomerId,
                request.TripRequestId,
                request.StartDate,
                request.EndDate,
                request.Currency);

            return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
        }

        /// <summary>
        /// Retrieves a single Itinerary by Id, including its scheduled items.
        /// Customers can only view their own itinerary.
        /// </summary>
        [HttpGet("{id}")]
        [ProducesResponseType(typeof(ItineraryDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        [ProducesResponseType(StatusCodes.Status403Forbidden)]
        public async Task<IActionResult> GetById(int id)
        {
            var itinerary = await _service.GetItineraryByIdAsync(id);

            if (itinerary is null)
                return NotFound(new { message = $"Itinerary with Id {id} was not found." });

            // Ownership check: customers can only see their own itinerary
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var isStaff = User.IsInRole("TravelAgent") || User.IsInRole("Admin");

            if (!isStaff && itinerary.CustomerId != userId)
                return StatusCode(StatusCodes.Status403Forbidden, new { message = "You do not have access to this itinerary." });

            return Ok(itinerary);
        }

        /// <summary>
        /// Returns all Itineraries belonging to a given customer, ordered by most recent first.
        /// Customers can only query their own ID.
        /// </summary>
        [HttpGet("customer/{customerId}")]
        [ProducesResponseType(typeof(List<ItineraryDto>), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status403Forbidden)]
        public async Task<IActionResult> GetByCustomer(string customerId)
        {
            // Customers can only list their own itineraries
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var isStaff = User.IsInRole("TravelAgent") || User.IsInRole("Admin");

            if (!isStaff && customerId != userId)
                return StatusCode(StatusCodes.Status403Forbidden, new { message = "You can only view your own itineraries." });

            var itineraries = await _service.GetItinerariesByCustomerAsync(customerId);
            return Ok(itineraries);
        }

        /// <summary>
        /// Adds a tour as a scheduled item to an Itinerary.
        /// Validates tour existence, active status, and time-overlap conflicts.
        /// Returns 400 Bad Request for any validation failure.
        /// </summary>
        [HttpPost("{id}/items")]
        [ProducesResponseType(typeof(ItineraryDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status403Forbidden)]
        public async Task<IActionResult> AddItem(int id, [FromBody] ItineraryItemCreateDto dto)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            // Ownership check before modifying
            var itinerary = await _service.GetItineraryByIdAsync(id);
            if (itinerary is null)
                return NotFound(new { message = $"Itinerary with Id {id} was not found." });

            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var isStaff = User.IsInRole("TravelAgent") || User.IsInRole("Admin");

            if (!isStaff && itinerary.CustomerId != userId)
                return StatusCode(StatusCodes.Status403Forbidden, new { message = "You do not have access to this itinerary." });

            var (success, errorMessage, data) = await _service.AddItemToItineraryAsync(id, dto);

            if (!success)
                return BadRequest(new { message = errorMessage });

            return Ok(data);
        }

        /// <summary>
        /// Removes a scheduled item from an Itinerary and recalculates the total cost.
        /// </summary>
        [HttpDelete("{id}/items/{itemId}")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        [ProducesResponseType(StatusCodes.Status403Forbidden)]
        public async Task<IActionResult> RemoveItem(int id, int itemId)
        {
            // Ownership check before modifying
            var itinerary = await _service.GetItineraryByIdAsync(id);
            if (itinerary is null)
                return NotFound(new { message = $"Itinerary with Id {id} was not found." });

            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var isStaff = User.IsInRole("TravelAgent") || User.IsInRole("Admin");

            if (!isStaff && itinerary.CustomerId != userId)
                return StatusCode(StatusCodes.Status403Forbidden, new { message = "You do not have access to this itinerary." });

            var (success, errorMessage) = await _service.RemoveItemFromItineraryAsync(id, itemId);

            if (!success)
                return NotFound(new { message = errorMessage });

            return Ok(new { message = "Item removed successfully." });
        }

        /// <summary>
        /// Updates the status of an existing Itinerary (e.g. Draft → Proposed → Accepted).
        /// </summary>
        [HttpPatch("{id}/status")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status403Forbidden)]
        public async Task<IActionResult> UpdateStatus(int id, [FromBody] UpdateItineraryStatusRequest request)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            // Ownership check before modifying
            var itinerary = await _service.GetItineraryByIdAsync(id);
            if (itinerary is null)
                return NotFound(new { message = $"Itinerary with Id {id} was not found." });

            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var isStaff = User.IsInRole("TravelAgent") || User.IsInRole("Admin");

            if (!isStaff && itinerary.CustomerId != userId)
                return StatusCode(StatusCodes.Status403Forbidden, new { message = "You do not have access to this itinerary." });

            var (success, errorMessage) = await _service.UpdateItineraryStatusAsync(id, request.NewStatus);

            if (!success)
                return NotFound(new { message = errorMessage });

            return Ok(new { message = $"Itinerary status updated to {request.NewStatus}." });
        }
    }

    // ── Inline request DTOs ─────────────────────────────────────────────────

    /// <summary>
    /// Request body for creating a new Itinerary.
    /// </summary>
    public class CreateItineraryRequest
    {
        public string CustomerId { get; set; } = string.Empty;
        public int TripRequestId { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public string Currency { get; set; } = "USD";
    }

    /// <summary>
    /// Request body for updating an Itinerary's status.
    /// </summary>
    public class UpdateItineraryStatusRequest
    {
        public ItineraryStatus NewStatus { get; set; }
    }
}
