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
    // TODO: Add [Authorize] and role-based policies once JWT role rules
    //       for the itinerary feature are finalized by the team.
    [ApiController]
    [Route("api/itinerary")]
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
        /// </summary>
        [HttpGet("{id}")]
        [ProducesResponseType(typeof(ItineraryDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> GetById(int id)
        {
            var itinerary = await _service.GetItineraryByIdAsync(id);

            if (itinerary is null)
                return NotFound(new { message = $"Itinerary with Id {id} was not found." });

            return Ok(itinerary);
        }

        /// <summary>
        /// Returns all Itineraries belonging to a given customer, ordered by most recent first.
        /// </summary>
        [HttpGet("customer/{customerId}")]
        [ProducesResponseType(typeof(List<ItineraryDto>), StatusCodes.Status200OK)]
        public async Task<IActionResult> GetByCustomer(string customerId)
        {
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
        public async Task<IActionResult> AddItem(int id, [FromBody] ItineraryItemCreateDto dto)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

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
        public async Task<IActionResult> RemoveItem(int id, int itemId)
        {
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
        public async Task<IActionResult> UpdateStatus(int id, [FromBody] UpdateItineraryStatusRequest request)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

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
