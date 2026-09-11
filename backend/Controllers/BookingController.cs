using backend.Data;
using backend.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace backend.Controllers
{
    /// <summary>
    /// Student D — Commercial Booking Management Controller.
    /// Sole source of commercial truth for bookings and reservations.
    /// </summary>
    [ApiController]
    [Route("api/[controller]")]
    public class BookingController : ControllerBase
    {
        private readonly AppDbContext _db;

        public BookingController(AppDbContext db)
        {
            _db = db;
        }

        /// <summary>
        /// List all bookings with optional status filter and customer search.
        /// </summary>
        [HttpGet]
        public async Task<IActionResult> GetAll([FromQuery] string? status, [FromQuery] string? search)
        {
            var query = _db.Bookings
                .Include(b => b.Customer)
                .Include(b => b.Itinerary)
                .AsQueryable();

            if (!string.IsNullOrWhiteSpace(status) && status != "All")
            {
                query = query.Where(b => b.Status == status);
            }

            if (!string.IsNullOrWhiteSpace(search))
            {
                query = query.Where(b => b.BookingReference.Contains(search) ||
                                         (b.Customer != null && b.Customer.FullName.Contains(search)));
            }

            var bookings = await query
                .OrderByDescending(b => b.CreatedAt)
                .Select(b => new
                {
                    b.Id,
                    Reference = b.BookingReference,
                    CustomerName = b.Customer != null ? b.Customer.FullName : "Customer",
                    b.Status,
                    b.TotalCost,
                    b.Currency,
                    CreatedAt = b.CreatedAt.ToString("yyyy-MM-dd HH:mm"),
                    UpdatedAt = b.UpdatedAt.ToString("yyyy-MM-dd HH:mm")
                })
                .ToListAsync();

            return Ok(bookings);
        }

        /// <summary>
        /// Get detailed booking record including line items and approval status.
        /// </summary>
        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(int id)
        {
            var booking = await _db.Bookings
                .Include(b => b.Customer)
                .Include(b => b.Itinerary)
                .Include(b => b.Items)
                .Include(b => b.Approvals)
                .Include(b => b.Payment)
                .FirstOrDefaultAsync(b => b.Id == id);

            if (booking == null)
                return NotFound(new { message = "Booking not found." });

            return Ok(booking);
        }
    }
}
