using System.Security.Claims;
using backend.DTOs;
using backend.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace backend.Controllers
{
    /// <summary>
    /// Student D — Booking Approval API Controller.
    /// Manages human travel agent decisions (Approved, Rejected, RevisionRequested)
    /// and maintains an immutable audit trail.
    /// </summary>
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class ApprovalController : ControllerBase
    {
        private readonly IApprovalService _approvalService;
        private readonly IBookingService _bookingService;

        public ApprovalController(IApprovalService approvalService, IBookingService bookingService)
        {
            _approvalService = approvalService;
            _bookingService = bookingService;
        }

        /// <summary>
        /// Record a human approval decision (Approved / Rejected / RevisionRequested).
        /// Only TravelAgent or Admin can submit approval decisions.
        /// Automatically updates booking status.
        /// </summary>
        [HttpPost]
        [Authorize(Roles = "TravelAgent,Admin")]
        [ProducesResponseType(typeof(ApprovalDto), StatusCodes.Status201Created)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> SubmitApproval([FromBody] ApprovalCreateDto dto)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "agent-system";

            try
            {
                var result = await _approvalService.CreateApprovalAsync(userId, dto);
                return CreatedAtAction(nameof(GetApprovalsByBooking), new { bookingId = dto.BookingId }, result);
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

        /// <summary>
        /// Get all human approval decisions recorded for a specific booking.
        /// Only TravelAgent or Admin can view approval records.
        /// </summary>
        [HttpGet("booking/{bookingId}")]
        [Authorize(Roles = "TravelAgent,Admin")]
        [ProducesResponseType(typeof(IEnumerable<ApprovalDto>), StatusCodes.Status200OK)]
        public async Task<IActionResult> GetApprovalsByBooking(int bookingId)
        {
            var result = await _approvalService.GetApprovalsByBookingIdAsync(bookingId);
            return Ok(result);
        }

        /// <summary>
        /// Get all pending bookings awaiting travel agent approval.
        /// Only TravelAgent or Admin can view the pending queue.
        /// </summary>
        [HttpGet("pending")]
        [Authorize(Roles = "TravelAgent,Admin")]
        [ProducesResponseType(typeof(IEnumerable<BookingDto>), StatusCodes.Status200OK)]
        public async Task<IActionResult> GetPendingApprovals()
        {
            var pendingBookings = await _bookingService.GetPendingBookingsForApprovalAsync();
            return Ok(pendingBookings);
        }

        /// <summary>
        /// Get all historical approval audit records.
        /// Only TravelAgent or Admin can view all approvals.
        /// </summary>
        [HttpGet]
        [Authorize(Roles = "TravelAgent,Admin")]
        [ProducesResponseType(typeof(IEnumerable<ApprovalDto>), StatusCodes.Status200OK)]
        public async Task<IActionResult> GetAllApprovals()
        {
            var result = await _approvalService.GetAllApprovalsAsync();
            return Ok(result);
        }
    }
}
