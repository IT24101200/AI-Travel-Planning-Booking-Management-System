using System.Security.Claims;
using backend.DTOs;
using backend.Models.Enums;
using backend.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace backend.Controllers
{
    /// <summary>
    /// Student D — Booking Management API Controller.
    /// Handles Booking CRUD and status workflow state transitions.
    /// </summary>
    [ApiController]
    [Route("api/[controller]")]
    public class BookingController : ControllerBase
    {
        private readonly IBookingService _bookingService;

        public BookingController(IBookingService bookingService)
        {
            _bookingService = bookingService;
        }

        /// <summary>
        /// Create a new booking (Initial status: AwaitingApproval).
        /// </summary>
        [HttpPost]
        [ProducesResponseType(typeof(BookingDto), StatusCodes.Status201Created)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> CreateBooking([FromBody] BookingCreateDto dto)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            try
            {
                var created = await _bookingService.CreateBookingAsync(dto);
                return CreatedAtAction(nameof(GetBookingById), new { id = created.Id }, created);
            }
            catch (ArgumentException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
            catch (KeyNotFoundException ex)
            {
                return NotFound(new { message = ex.Message });
            }
            catch (Exception ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        /// <summary>
        /// Get all bookings (Supports filtering by CustomerId and BookingStatus).
        /// </summary>
        [HttpGet]
        [ProducesResponseType(typeof(IEnumerable<BookingDto>), StatusCodes.Status200OK)]
        public async Task<IActionResult> GetBookings([FromQuery] string? customerId, [FromQuery] BookingStatus? status)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var isStaff = User.IsInRole("TravelAgent") || User.IsInRole("Admin");

            // Customer users can only view their own bookings
            if (!isStaff && !string.IsNullOrEmpty(userId))
            {
                customerId = userId;
            }

            var result = await _bookingService.GetBookingsAsync(customerId, status);
            return Ok(result);
        }

        /// <summary>
        /// Get a single booking by ID (IDOR security check enforced).
        /// </summary>
        [HttpGet("{id}")]
        [ProducesResponseType(typeof(BookingDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        [ProducesResponseType(StatusCodes.Status403Forbidden)]
        public async Task<IActionResult> GetBookingById(int id)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var isStaff = User.IsInRole("TravelAgent") || User.IsInRole("Admin");

            try
            {
                var booking = await _bookingService.GetBookingByIdAsync(id, userId, isStaff);
                if (booking == null)
                    return NotFound(new { message = $"Booking with ID {id} not found." });

                return Ok(booking);
            }
            catch (UnauthorizedAccessException ex)
            {
                return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
            }
        }

        /// <summary>
        /// Update booking status (PUT method — enforces status transition rules).
        /// </summary>
        [HttpPut("{id}/status")]
        [ProducesResponseType(typeof(BookingDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> UpdateBookingStatusPut(int id, [FromBody] BookingStatusUpdateDto dto)
        {
            return await UpdateBookingStatusInternal(id, dto);
        }

        /// <summary>
        /// Update booking status (PATCH method — enforces status transition rules).
        /// </summary>
        [HttpPatch("{id}/status")]
        [ProducesResponseType(typeof(BookingDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> UpdateBookingStatusPatch(int id, [FromBody] BookingStatusUpdateDto dto)
        {
            return await UpdateBookingStatusInternal(id, dto);
        }

        /// <summary>
        /// Delete a booking by ID.
        /// </summary>
        [HttpDelete("{id}")]
        [ProducesResponseType(StatusCodes.Status204NoContent)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> DeleteBooking(int id)
        {
            var success = await _bookingService.DeleteBookingAsync(id);
            if (!success)
                return NotFound(new { message = $"Booking with ID {id} not found." });

            return NoContent();
        }

        private async Task<IActionResult> UpdateBookingStatusInternal(int id, BookingStatusUpdateDto dto)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            try
            {
                var updated = await _bookingService.UpdateBookingStatusAsync(id, dto.Status);
                return Ok(updated);
            }
            catch (KeyNotFoundException ex)
            {
                return NotFound(new { message = ex.Message });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }
    }
}
