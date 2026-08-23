using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using backend.DTOs;
using backend.Services;

namespace backend.Controllers
{
    /// <summary>
    /// REST API for Transport Option management.
    /// Same pattern as TourController.
    /// </summary>
    [ApiController]
    [Route("api/[controller]")]
    public class TransportController : ControllerBase
    {
        private readonly ITransportService _transportService;
        private readonly IAvailabilityService _availabilityService;

        public TransportController(
            ITransportService transportService,
            IAvailabilityService availabilityService)
        {
            _transportService = transportService;
            _availabilityService = availabilityService;
        }

        /// <summary>
        /// Search transport options with filters and pagination.
        /// GET /api/transport?type=Flight&routeFrom=Colombo&page=1&pageSize=10
        /// </summary>
        [HttpGet]
        [Authorize]
        public async Task<IActionResult> Search(
            [FromQuery] string? type,
            [FromQuery] string? routeFrom,
            [FromQuery] string? routeTo,
            [FromQuery] decimal? minPrice,
            [FromQuery] decimal? maxPrice,
            [FromQuery] string? status,
            [FromQuery] string? sortBy,
            [FromQuery] bool descending = false,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 10)
        {
            if (page < 1) page = 1;
            if (pageSize < 1) pageSize = 10;
            if (pageSize > 50) pageSize = 50;

            var results = await _transportService.SearchAsync(
                type, routeFrom, routeTo, minPrice, maxPrice, status,
                sortBy, descending, page, pageSize);
            var totalCount = await _transportService.GetTotalCountAsync(
                type, routeFrom, routeTo, minPrice, maxPrice, status);

            return Ok(new
            {
                data = results,
                totalCount,
                page,
                pageSize,
                totalPages = (int)Math.Ceiling((double)totalCount / pageSize)
            });
        }

        /// <summary>
        /// Get a single transport option by ID.
        /// GET /api/transport/5
        /// </summary>
        [HttpGet("{id}")]
        [Authorize]
        public async Task<IActionResult> GetById(int id)
        {
            var transport = await _transportService.GetByIdAsync(id);
            if (transport is null) return NotFound();
            return Ok(transport);
        }

        /// <summary>
        /// Create a new transport option. Only TravelAgent or Admin.
        /// POST /api/transport
        /// </summary>
        [HttpPost]
        [Authorize(Roles = "TravelAgent,Admin")]
        public async Task<IActionResult> Create([FromBody] CreateTransportOptionDto dto)
        {
            var created = await _transportService.CreateAsync(dto);
            return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
        }

        /// <summary>
        /// Update a transport option. Only TravelAgent or Admin.
        /// PUT /api/transport/5
        /// </summary>
        [HttpPut("{id}")]
        [Authorize(Roles = "TravelAgent,Admin")]
        public async Task<IActionResult> Update(int id, [FromBody] CreateTransportOptionDto dto)
        {
            var updated = await _transportService.UpdateAsync(id, dto);
            if (!updated) return NotFound();
            return NoContent();
        }

        /// <summary>
        /// Soft delete a transport option (sets status to Inactive).
        /// DELETE /api/transport/5
        /// </summary>
        [HttpDelete("{id}")]
        [Authorize(Roles = "TravelAgent,Admin")]
        public async Task<IActionResult> Delete(int id)
        {
            var deleted = await _transportService.SoftDeleteAsync(id);
            if (!deleted) return NotFound();
            return NoContent();
        }

        // ══════════════════════════════════════════════════════════════════
        //  AVAILABILITY
        // ══════════════════════════════════════════════════════════════════

        /// <summary>
        /// Check availability (remaining seats) for a transport option.
        /// GET /api/transport/5/availability
        /// 
        /// This is what the Booking Agent calls via check_transport_availability tool.
        /// </summary>
        [HttpGet("{id}/availability")]
        [Authorize]
        public async Task<IActionResult> CheckAvailability(int id)
        {
            var availability = await _availabilityService.CheckTransportAvailabilityAsync(id);
            if (availability is null) return NotFound();
            return Ok(availability);
        }
    }
}
