using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using backend.DTOs;
using backend.Services;

namespace backend.Controllers
{
    /// <summary>
    /// REST API for Hotel & Room management.
    /// 
    /// Pattern: Same as TourController/DestinationController.
    /// - GET endpoints: any authenticated user can read
    /// - POST/PUT/DELETE: only TravelAgent or Admin roles
    /// 
    /// Rooms are nested under hotels: /api/hotel/{hotelId}/rooms
    /// </summary>
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class HotelController : ControllerBase
    {
        private readonly IHotelService _hotelService;
        private readonly IAvailabilityService _availabilityService;

        public HotelController(IHotelService hotelService, IAvailabilityService availabilityService)
        {
            _hotelService = hotelService;
            _availabilityService = availabilityService;
        }

        private bool CanManageInactive =>
            User.IsInRole("TravelAgent") || User.IsInRole("Admin");

        // ══════════════════════════════════════════════════════════════════
        //  HOTEL ENDPOINTS
        // ══════════════════════════════════════════════════════════════════

        /// <summary>
        /// Search hotels with optional filters and pagination.
        /// GET /api/hotel?search=Hilton&destinationId=1&minStarRating=3&page=1&pageSize=10
        /// </summary>
        [HttpGet]
        [AllowAnonymous]
        public async Task<IActionResult> GetAll(
            [FromQuery] string? search,
            [FromQuery] int? destinationId,
            [FromQuery] int? minStarRating,
            [FromQuery] string? status,
            [FromQuery] string? sortBy,
            [FromQuery] bool descending = false,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 10,
            [FromQuery] string? currency = null)
        {
            // Validate pagination (same as CustomerController)
            if (page < 1) page = 1;
            if (pageSize < 1) pageSize = 10;
            if (pageSize > 50) pageSize = 50;

            // Public/customer catalog reads never accept an inactive/all status
            // scope. Staff can use status=All or status=Inactive for management.
            var effectiveStatus = status;
            if (!CanManageInactive &&
                (string.IsNullOrWhiteSpace(status) ||
                 !status.Equals("Active", StringComparison.OrdinalIgnoreCase)))
            {
                effectiveStatus = "Active";
            }

            var hotels = await _hotelService.GetAllAsync(
                search, destinationId, minStarRating, effectiveStatus, sortBy, descending, page, pageSize, currency,
                includeInactive: CanManageInactive);
            var totalCount = await _hotelService.GetTotalCountAsync(
                search, destinationId, minStarRating, effectiveStatus);

            return Ok(new
            {
                data = hotels,
                totalCount,
                page,
                pageSize,
                totalPages = (int)Math.Ceiling((double)totalCount / pageSize)
            });
        }

        /// <summary>
        /// Get a single hotel by ID, including its rooms.
        /// GET /api/hotel/5
        /// </summary>
        [HttpGet("{id}")]
        [AllowAnonymous]
        public async Task<IActionResult> GetById(int id, [FromQuery] string? currency = null)
        {
            var hotel = await _hotelService.GetByIdAsync(id, currency, includeInactive: CanManageInactive);
            if (hotel is null) return NotFound();
            return Ok(hotel);
        }

        /// <summary>
        /// Create a new hotel. Only TravelAgent or Admin.
        /// POST /api/hotel
        /// </summary>
        [HttpPost]
        [Authorize(Roles = "TravelAgent,Admin")]
        public async Task<IActionResult> Create([FromBody] CreateHotelDto dto)
        {
            try
            {
                var created = await _hotelService.CreateAsync(dto);
                return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
            }
            catch (ArgumentException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        /// <summary>
        /// Update a hotel. Only TravelAgent or Admin.
        /// PUT /api/hotel/5
        /// </summary>
        [HttpPut("{id}")]
        [Authorize(Roles = "TravelAgent,Admin")]
        public async Task<IActionResult> Update(int id, [FromBody] HotelUpdateDto dto)
        {
            try
            {
                var updated = await _hotelService.UpdateAsync(id, dto);
                if (!updated) return NotFound();
                return NoContent();
            }
            catch (ArgumentException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        /// <summary>
        /// Update only the hotel lifecycle status. This prevents a status
        /// toggle from rewriting unrelated hotel fields such as GPS data.
        /// </summary>
        [HttpPatch("{id}/status")]
        [Authorize(Roles = "TravelAgent,Admin")]
        public async Task<IActionResult> UpdateStatus(int id, [FromBody] HotelStatusUpdateDto dto)
        {
            try
            {
                var updated = await _hotelService.UpdateStatusAsync(id, dto.Status);
                if (!updated) return NotFound();
                return NoContent();
            }
            catch (ArgumentException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        /// <summary>
        /// Soft delete a hotel (sets status to Inactive).
        /// DELETE /api/hotel/5
        /// </summary>
        [HttpDelete("{id}")]
        [Authorize(Roles = "TravelAgent,Admin")]
        public async Task<IActionResult> Delete(int id)
        {
            var deleted = await _hotelService.SoftDeleteAsync(id);
            if (!deleted) return NotFound();
            return NoContent();
        }

        // ══════════════════════════════════════════════════════════════════
        //  ROOM ENDPOINTS (nested under a hotel)
        // ══════════════════════════════════════════════════════════════════

        /// <summary>
        /// Search rooms globally with optional filters and pagination.
        /// GET /api/hotel/rooms/search
        /// </summary>
        [HttpGet("rooms/search")]
        [AllowAnonymous]
        public async Task<IActionResult> SearchRooms(
            [FromQuery] string? roomType,
            [FromQuery] int? minCapacity,
            [FromQuery] decimal? maxPrice,
            [FromQuery] string? sortBy,
            [FromQuery] bool descending = false,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 10,
            [FromQuery] string? currency = null)
        {
            if (page < 1) page = 1;
            if (pageSize < 1) pageSize = 10;
            if (pageSize > 50) pageSize = 50;

            var rooms = await _hotelService.SearchRoomsAsync(roomType, minCapacity, maxPrice, sortBy, descending, page, pageSize, currency);
            return Ok(rooms);
        }

        /// <summary>
        /// List all room types for a hotel.
        /// GET /api/hotel/5/rooms
        /// </summary>
        [HttpGet("{hotelId}/rooms")]
        [AllowAnonymous]
        public async Task<IActionResult> GetRooms(int hotelId, [FromQuery] string? currency = null)
        {
            var rooms = await _hotelService.GetRoomsByHotelAsync(
                hotelId, currency, includeInactive: CanManageInactive);
            if (rooms is null) return NotFound();
            return Ok(rooms);
        }

        /// <summary>
        /// Get a specific room.
        /// GET /api/hotel/5/rooms/3
        /// </summary>
        [HttpGet("{hotelId}/rooms/{roomId}")]
        [AllowAnonymous]
        public async Task<IActionResult> GetRoom(int hotelId, int roomId, [FromQuery] string? currency = null)
        {
            var room = await _hotelService.GetRoomByIdAsync(
                hotelId, roomId, currency, includeInactive: CanManageInactive);
            if (room is null) return NotFound();
            return Ok(room);
        }

        /// <summary>
        /// Add a room type to a hotel.
        /// POST /api/hotel/5/rooms
        /// </summary>
        [HttpPost("{hotelId}/rooms")]
        [Authorize(Roles = "TravelAgent,Admin")]
        public async Task<IActionResult> AddRoom(int hotelId, [FromBody] CreateRoomDto dto)
        {
            var room = await _hotelService.AddRoomAsync(hotelId, dto);
            if (room is null) return NotFound(new { message = "Hotel not found." });
            return CreatedAtAction(nameof(GetRoom), new { hotelId, roomId = room.Id }, room);
        }

        /// <summary>
        /// Update a room type.
        /// PUT /api/hotel/5/rooms/3
        /// </summary>
        [HttpPut("{hotelId}/rooms/{roomId}")]
        [Authorize(Roles = "TravelAgent,Admin")]
        public async Task<IActionResult> UpdateRoom(int hotelId, int roomId, [FromBody] CreateRoomDto dto)
        {
            var updated = await _hotelService.UpdateRoomAsync(hotelId, roomId, dto);
            if (!updated) return NotFound();
            return NoContent();
        }

        /// <summary>
        /// Delete a room type.
        /// DELETE /api/hotel/5/rooms/3
        /// </summary>
        [HttpDelete("{hotelId}/rooms/{roomId}")]
        [Authorize(Roles = "TravelAgent,Admin")]
        public async Task<IActionResult> DeleteRoom(int hotelId, int roomId)
        {
            var deleted = await _hotelService.DeleteRoomAsync(hotelId, roomId);
            if (!deleted) return NotFound();
            return NoContent();
        }

        /// <summary>
        /// Reactivate or deactivate a room without deleting its historical row.
        /// </summary>
        [HttpPatch("{hotelId}/rooms/{roomId}/status")]
        [Authorize(Roles = "TravelAgent,Admin")]
        public async Task<IActionResult> UpdateRoomStatus(
            int hotelId, int roomId, [FromBody] RoomStatusUpdateDto dto)
        {
            try
            {
                var updated = await _hotelService.UpdateRoomStatusAsync(hotelId, roomId, dto.Status);
                if (!updated) return NotFound();
                return NoContent();
            }
            catch (ArgumentException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        // ══════════════════════════════════════════════════════════════════
        //  AVAILABILITY ENDPOINT
        // ══════════════════════════════════════════════════════════════════

        /// <summary>
        /// Check room availability for specific dates.
        /// GET /api/hotel/5/rooms/3/availability?checkIn=2026-09-10&checkOut=2026-09-15
        /// 
        /// This is what the Booking Agent calls via check_hotel_availability tool.
        /// </summary>
        [HttpGet("{hotelId}/rooms/{roomId}/availability")]
        [AllowAnonymous]
        public async Task<IActionResult> CheckRoomAvailability(
            int hotelId, int roomId,
            [FromQuery] DateTime checkIn,
            [FromQuery] DateTime checkOut)
        {
            // Basic validation
            if (DateOnly.FromDateTime(checkIn) >= DateOnly.FromDateTime(checkOut))
                return BadRequest(new { message = "Check-in date must be before check-out date." });

            if (DateOnly.FromDateTime(checkIn) < BusinessClock.Today)
                return BadRequest(new { message = "Check-in date cannot be in the past." });

            // Verify the room belongs to this hotel
            var room = await _hotelService.GetRoomByIdAsync(
                hotelId, roomId, includeInactive: CanManageInactive);
            if (room is null) return NotFound();

            var availability = await _availabilityService.CheckRoomAvailabilityAsync(
                roomId, checkIn, checkOut, includeInactive: CanManageInactive);
            if (availability is null) return NotFound();

            return Ok(availability);
        }
    }
}
