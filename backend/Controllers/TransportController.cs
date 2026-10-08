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
    [Authorize]
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

        private bool CanManageInactive =>
            User.IsInRole("TravelAgent") || User.IsInRole("Admin");

        /// <summary>
        /// Search transport options with filters and pagination.
        /// GET /api/transport?type=Flight&routeFrom=Colombo&page=1&pageSize=10
        /// </summary>
        [HttpGet]
        [AllowAnonymous]
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
            [FromQuery] int pageSize = 10,
            [FromQuery] string? currency = null)
        {
            if (page < 1) page = 1;
            if (pageSize < 1) pageSize = 10;
            if (pageSize > 50) pageSize = 50;

            if (!string.IsNullOrWhiteSpace(type) &&
                (!Enum.TryParse<backend.Models.Enums.TransportType>(type, true, out var parsedType) ||
                 !Enum.IsDefined(parsedType)))
            {
                return BadRequest(new
                {
                    code = "INVALID_TRANSPORT_TYPE",
                    message = "Transport type filter is invalid."
                });
            }

            if (!string.IsNullOrWhiteSpace(status) &&
                !status.Equals("All", StringComparison.OrdinalIgnoreCase) &&
                (!Enum.TryParse<backend.Models.Enums.TransportStatus>(status, true, out var parsedStatus) ||
                 !Enum.IsDefined(parsedStatus)))
            {
                return BadRequest(new
                {
                    code = "INVALID_TRANSPORT_STATUS",
                    message = "Transport status filter is invalid."
                });
            }

            // Public catalogue reads are always active-only. Staff may request
            // Inactive or All explicitly for fleet management.
            var effectiveStatus = CanManageInactive
                ? status
                : "Active";

            try
            {
                var results = await _transportService.SearchAsync(
                    type, routeFrom, routeTo, minPrice, maxPrice, effectiveStatus,
                    sortBy, descending, page, pageSize, currency);
                var totalCount = await _transportService.GetTotalCountAsync(
                    type, routeFrom, routeTo, minPrice, maxPrice, effectiveStatus);
                var activeCount = string.Equals(effectiveStatus, "Active", StringComparison.OrdinalIgnoreCase)
                    ? totalCount
                    : await _transportService.GetTotalCountAsync(
                        type, routeFrom, routeTo, minPrice, maxPrice, "Active");

                return Ok(new
                {
                    data = results,
                    totalCount,
                    activeCount,
                    page,
                    pageSize,
                    totalPages = Math.Max(1, (int)Math.Ceiling((double)totalCount / pageSize))
                });
            }
            catch (ArgumentException ex)
            {
                return BadRequest(new { code = "INVALID_TRANSPORT_FILTER", message = ex.Message });
            }
        }

        /// <summary>
        /// Read-only route/date/capacity/availability coverage for staff.
        /// GET /api/transport/coverage?routeFrom=Batticaloa&amp;routeTo=Colombo
        /// </summary>
        [HttpGet("coverage")]
        [Authorize(Roles = "TravelAgent,Admin")]
        public async Task<IActionResult> Coverage(
            [FromQuery] string? routeFrom,
            [FromQuery] string? routeTo,
            [FromQuery] DateTime? startDate,
            [FromQuery] DateTime? endDate,
            [FromQuery] int travellers = 1,
            CancellationToken cancellationToken = default)
        {
            try
            {
                if (!startDate.HasValue || !endDate.HasValue)
                    return BadRequest(new
                    {
                        code = "INVALID_COVERAGE_REQUEST",
                        message = "Start date and end date are required."
                    });

                var coverage = await _transportService.GetCoverageAsync(
                    routeFrom ?? string.Empty,
                    routeTo ?? string.Empty,
                    startDate.Value,
                    endDate.Value,
                    travellers,
                    cancellationToken);
                return Ok(coverage);
            }
            catch (ArgumentException ex)
            {
                return BadRequest(new { code = "INVALID_COVERAGE_REQUEST", message = ex.Message });
            }
        }

        /// <summary>
        /// Get a single transport option by ID.
        /// GET /api/transport/5
        /// </summary>
        [HttpGet("{id}")]
        [AllowAnonymous]
        public async Task<IActionResult> GetById(int id, [FromQuery] string? currency = null)
        {
            var transport = await _transportService.GetByIdAsync(
                id,
                currency,
                includeInactive: CanManageInactive);
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
            try
            {
                var created = await _transportService.CreateAsync(dto);
                return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
            }
            catch (ArgumentException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
            catch (TransportBusinessException ex)
            {
                return Conflict(new { code = ex.Code, message = ex.Message });
            }
        }

        /// <summary>
        /// Update a transport option. Only TravelAgent or Admin.
        /// PUT /api/transport/5
        /// </summary>
        [HttpPut("{id}")]
        [Authorize(Roles = "TravelAgent,Admin")]
        public async Task<IActionResult> Update(int id, [FromBody] CreateTransportOptionDto dto)
        {
            try
            {
                var updated = await _transportService.UpdateAsync(id, dto);
                if (!updated) return NotFound();
                return NoContent();
            }
            catch (ArgumentException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
            catch (TransportBusinessException ex)
            {
                return Conflict(new { code = ex.Code, message = ex.Message });
            }
        }

        /// <summary>
        /// Permanently delete an unreferenced transport option.
        /// DELETE /api/transport/5
        /// </summary>
        [HttpDelete("{id}")]
        [Authorize(Roles = "TravelAgent,Admin")]
        public async Task<IActionResult> Delete(int id)
        {
            var result = await _transportService.DeleteAsync(id);
            if (!result.Found) return NotFound();
            if (!result.Deleted)
            {
                return Conflict(new
                {
                    message = "This transport cannot be permanently deleted because it is referenced by booking history.",
                    bookingReferences = result.BookingReferences
                });
            }
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
        [AllowAnonymous]
        public async Task<IActionResult> CheckAvailability(int id)
        {
            var availability = await _availabilityService.CheckTransportAvailabilityAsync(
                id,
                includeInactive: CanManageInactive);
            if (availability is null) return NotFound();
            return Ok(availability);
        }
    }
}
