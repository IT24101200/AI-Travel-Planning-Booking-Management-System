using backend.Data;
using backend.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace backend.Controllers
{
    /// <summary>
    /// Student D — Payment & Revenue Controller.
    /// Manages transaction records (Stripe Sandbox integration) and financial summaries.
    /// All endpoints require authentication. Customers can only see their own payments.
    /// Staff/agents can see all payments and the revenue summary.
    /// </summary>
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class PaymentController : ControllerBase
    {
        private readonly AppDbContext _db;

        public PaymentController(AppDbContext db)
        {
            _db = db;
        }

        /// <summary>
        /// List payments. Staff see all; customers only see their own (IDOR protection).
        /// </summary>
        [HttpGet]
        public async Task<IActionResult> GetAll([FromQuery] string? status)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var isStaff = IsStaffUser(userId);

            var query = _db.Payments
                .Include(p => p.Booking)
                    .ThenInclude(b => b.Customer)
                .AsQueryable();

            // IDOR protection: customers can only see their own payments
            if (!isStaff)
            {
                query = query.Where(p => p.Booking.CustomerId == userId);
            }

            if (!string.IsNullOrWhiteSpace(status) && status != "All")
            {
                query = query.Where(p => p.Status == status);
            }

            var list = await query
                .OrderByDescending(p => p.PaymentDate)
                .Select(p => new
                {
                    p.Id,
                    BookingReference = p.Booking.BookingReference,
                    CustomerName = p.Booking.Customer != null ? p.Booking.Customer.FullName : "Customer",
                    p.Amount,
                    p.Currency,
                    p.Status,
                    p.StripeReference,
                    PaymentDate = p.PaymentDate.ToString("yyyy-MM-dd HH:mm")
                })
                .ToListAsync();

            return Ok(list);
        }

        /// <summary>
        /// Get a single payment by ID with IDOR check.
        /// Customers can only access their own payment records.
        /// </summary>
        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(int id)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var isStaff = IsStaffUser(userId);

            var payment = await _db.Payments
                .Include(p => p.Booking)
                    .ThenInclude(b => b.Customer)
                .FirstOrDefaultAsync(p => p.Id == id);

            if (payment == null)
                return NotFound(new { message = "Payment not found." });

            // IDOR check: verify this payment belongs to the logged-in customer
            if (!isStaff && payment.Booking.CustomerId != userId)
                return Forbid();

            return Ok(new
            {
                payment.Id,
                BookingReference = payment.Booking.BookingReference,
                CustomerName = payment.Booking.Customer?.FullName ?? "Customer",
                payment.Amount,
                payment.Currency,
                payment.Status,
                payment.StripeReference,
                PaymentDate = payment.PaymentDate.ToString("yyyy-MM-dd HH:mm")
            });
        }

        /// <summary>
        /// Get high-level revenue and business health metrics for staff dashboards.
        /// Staff-only endpoint — customers cannot access revenue summaries.
        /// </summary>
        [HttpGet("revenue-summary")]
        public async Task<IActionResult> GetRevenueSummary()
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (!IsStaffUser(userId))
                return Forbid();

            var totalRevenue = await _db.Payments
                .Where(p => p.Status == "Paid")
                .SumAsync(p => (decimal?)p.Amount) ?? 0m;

            var paidCount = await _db.Payments.CountAsync(p => p.Status == "Paid");
            var pendingCount = await _db.Bookings.CountAsync(b => b.Status == "AwaitingApproval");
            var confirmedCount = await _db.Bookings.CountAsync(b => b.Status == "Confirmed");

            var averageOrder = paidCount > 0 ? totalRevenue / paidCount : 0m;

            return Ok(new
            {
                TotalRevenue = totalRevenue,
                Currency = "USD",
                PaidBookingsCount = paidCount,
                PendingApprovalsCount = pendingCount,
                ConfirmedBookingsCount = confirmedCount,
                AverageOrderValue = Math.Round(averageOrder, 2)
            });
        }

        /// <summary>
        /// Check if the user is a staff member (travel agent) by looking up TravelAgents table.
        /// </summary>
        private bool IsStaffUser(string? userId)
        {
            if (string.IsNullOrEmpty(userId)) return false;
            return _db.TravelAgents.Any(a => a.Id == userId);
        }
    }
}
