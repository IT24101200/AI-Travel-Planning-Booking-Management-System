using backend.Data;
using backend.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace backend.Controllers
{
    /// <summary>
    /// Student B — Tours & Itinerary Review Controller.
    /// Manages the assembly, conflict checking, and travel agent review of AI-generated itineraries.
    /// </summary>
    [ApiController]
    [Route("api/[controller]")]
    public class ItineraryController : ControllerBase
    {
        private readonly AppDbContext _db;

        public ItineraryController(AppDbContext db)
        {
            _db = db;
        }

        /// <summary>
        /// Get all itineraries available for review.
        /// </summary>
        [HttpGet("review")]
        public async Task<IActionResult> GetForReview([FromQuery] string? status)
        {
            var query = _db.Itineraries
                .Include(i => i.Customer)
                .Include(i => i.Items)
                    .ThenInclude(item => item.Tour)
                .AsQueryable();

            if (!string.IsNullOrWhiteSpace(status) && status != "All")
                query = query.Where(i => i.Status == status);

            var list = await query
                .OrderByDescending(i => i.CreatedAt)
                .Select(i => new
                {
                    i.Id,
                    Title = $"{Math.Max(1, (i.EndDate - i.StartDate).Days)} days · Tour Route",
                    Customer = i.Customer != null ? i.Customer.FullName : "Traveler",
                    i.Status,
                    i.TotalEstimatedCost,
                    i.Currency,
                    StartDate = i.StartDate.ToString("yyyy-MM-dd"),
                    EndDate = i.EndDate.ToString("yyyy-MM-dd"),
                    Days = i.Items.GroupBy(item => item.DayNumber)
                        .OrderBy(g => g.Key)
                        .Select(g => new
                        {
                            Day = g.Key,
                            Items = g.Select(it => it.Tour != null ? it.Tour.Name : "Activity").ToList()
                        })
                })
                .ToListAsync();

            return Ok(list);
        }

        /// <summary>
        /// Update itinerary status (e.g. Approved, Accepted, Discarded).
        /// </summary>
        [HttpPatch("{id}/status")]
        public async Task<IActionResult> UpdateStatus(int id, [FromBody] UpdateItineraryStatusDto dto)
        {
            var itinerary = await _db.Itineraries.FindAsync(id);
            if (itinerary == null)
                return NotFound(new { message = "Itinerary not found." });

            itinerary.Status = dto.Status;
            await _db.SaveChangesAsync();

            return Ok(new { message = $"Itinerary updated to {itinerary.Status}.", itinerary.Id, itinerary.Status });
        }
    }

    public class UpdateItineraryStatusDto
    {
        public string Status { get; set; } = "Proposed"; // Proposed, Accepted, Discarded
    }
}
