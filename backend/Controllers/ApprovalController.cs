using backend.Data;
using backend.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace backend.Controllers
{
    /// <summary>
    /// Student D — Human-in-the-Loop Booking Approval Controller.
    /// Manages the approval gate where travel agents review AI itineraries before payment.
    /// </summary>
    [ApiController]
    [Route("api/[controller]")]
    public class ApprovalController : ControllerBase
    {
        private readonly AppDbContext _db;

        public ApprovalController(AppDbContext db)
        {
            _db = db;
        }

        /// <summary>
        /// Get all bookings pending travel agent approval, complete with itinerary and AI agent log trails.
        /// </summary>
        [HttpGet("pending")]
        public async Task<IActionResult> GetPendingApprovals()
        {
            var pending = await _db.Bookings
                .Include(b => b.Customer)
                .Include(b => b.Itinerary)
                    .ThenInclude(i => i.Items)
                        .ThenInclude(item => item.Tour)
                .Include(b => b.Approvals)
                .Where(b => b.Status == "AwaitingApproval")
                .OrderByDescending(b => b.CreatedAt)
                .ToListAsync();

            var result = pending.Select(b => new
            {
                b.Id,
                Reference = b.BookingReference,
                Customer = b.Customer?.FullName ?? "Valued Traveler",
                CustomerEmail = b.Customer?.Id,
                Destination = b.Itinerary?.Items?.FirstOrDefault()?.Tour?.DestinationId.ToString() ?? "Sri Lanka",
                StartDate = b.Itinerary?.StartDate.ToString("yyyy-MM-dd"),
                EndDate = b.Itinerary?.EndDate.ToString("yyyy-MM-dd"),
                Days = b.Itinerary != null ? Math.Max(1, (b.Itinerary.EndDate - b.Itinerary.StartDate).Days) : 5,
                b.TotalCost,
                b.Currency,
                b.Status,
                RequestedAt = b.CreatedAt.ToString("yyyy-MM-dd HH:mm"),
                Items = b.Itinerary?.Items.Select(item => new
                {
                    item.DayNumber,
                    TourName = item.Tour?.Name ?? "Scheduled Excursion",
                    item.PriceAtSelection
                }),
                Approvals = b.Approvals.Select(a => new
                {
                    a.Decision,
                    a.Comment,
                    a.DecidedAt
                })
            });

            return Ok(result);
        }

        /// <summary>
        /// Record a human travel agent's decision (Approved, Rejected, RevisionRequested) with comments.
        /// </summary>
        [HttpPost("{bookingId}/decide")]
        public async Task<IActionResult> DecideApproval(int bookingId, [FromBody] ApprovalDecisionDto dto)
        {
            var booking = await _db.Bookings.FindAsync(bookingId);
            if (booking == null)
                return NotFound(new { message = "Booking not found." });

            var agentId = User?.FindFirstValue(ClaimTypes.NameIdentifier) ?? "agent-system";

            // Ensure travel agent record exists for foreign key
            var agentExists = await _db.TravelAgents.AnyAsync(a => a.Id == agentId);
            if (!agentExists)
            {
                _db.TravelAgents.Add(new TravelAgent
                {
                    Id = agentId,
                    FullName = "Travel Consultant",
                    Department = "Operations"
                });
                await _db.SaveChangesAsync();
            }

            // Create permanent human-in-the-loop decision row
            var approval = new BookingApproval
            {
                BookingId = bookingId,
                TravelAgentId = agentId,
                Decision = dto.Decision,
                Comment = dto.Comment,
                DecidedAt = DateTime.UtcNow
            };

            _db.BookingApprovals.Add(approval);

            // Update booking status according to decision
            if (dto.Decision == "Approved")
            {
                booking.Status = "Confirmed";
            }
            else if (dto.Decision == "Rejected")
            {
                booking.Status = "Rejected";
            }
            else if (dto.Decision == "RevisionRequested")
            {
                booking.Status = "Draft";
            }

            booking.UpdatedAt = DateTime.UtcNow;
            await _db.SaveChangesAsync();

            return Ok(new
            {
                message = $"Booking {booking.BookingReference} updated to {booking.Status}.",
                booking.Id,
                booking.BookingReference,
                booking.Status,
                Decision = dto.Decision,
                dto.Comment,
                DecidedAt = approval.DecidedAt
            });
        }
    }

    public class ApprovalDecisionDto
    {
        public string Decision { get; set; } = "Approved"; // Approved, Rejected, RevisionRequested
        public string? Comment { get; set; }
    }
}
