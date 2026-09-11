using backend.Data;
using backend.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace backend.Controllers
{
    /// <summary>
    /// Student C — Transport Fleet & Route Management Controller.
    /// Manages vehicles, trains, and inter-city transport segments.
    /// </summary>
    [ApiController]
    [Route("api/[controller]")]
    public class TransportController : ControllerBase
    {
        private readonly AppDbContext _db;

        public TransportController(AppDbContext db)
        {
            _db = db;
        }

        /// <summary>
        /// List all transport options with optional type and route filtering.
        /// </summary>
        [HttpGet]
        public async Task<IActionResult> GetAll([FromQuery] string? type, [FromQuery] string? search)
        {
            var query = _db.TransportOptions.AsQueryable();

            if (!string.IsNullOrWhiteSpace(type) && type != "All")
                query = query.Where(t => t.Type == type);

            if (!string.IsNullOrWhiteSpace(search))
                query = query.Where(t => t.RouteFrom.Contains(search) ||
                                         t.RouteTo.Contains(search) ||
                                         t.Provider.Contains(search));

            var list = await query
                .OrderBy(t => t.RouteFrom)
                .Select(t => new
                {
                    t.Id,
                    t.Type,
                    t.Provider,
                    Route = $"{t.RouteFrom} → {t.RouteTo}",
                    t.RouteFrom,
                    t.RouteTo,
                    Departure = t.DepartureTime.ToString(@"hh\:mm"),
                    Arrival = t.ArrivalTime.ToString(@"hh\:mm"),
                    t.Capacity,
                    t.Price,
                    t.Currency,
                    t.Status
                })
                .ToListAsync();

            return Ok(list);
        }

        /// <summary>
        /// Add a new transit route or vehicle option.
        /// </summary>
        [HttpPost]
        public async Task<IActionResult> Create([FromBody] CreateTransportDto dto)
        {
            var item = new TransportOption
            {
                Type = dto.Type,
                Provider = dto.Provider,
                RouteFrom = dto.RouteFrom,
                RouteTo = dto.RouteTo,
                DepartureTime = TimeSpan.TryParse(dto.Departure, out var dep) ? dep : new TimeSpan(8, 0, 0),
                ArrivalTime = TimeSpan.TryParse(dto.Arrival, out var arr) ? arr : new TimeSpan(12, 0, 0),
                Capacity = dto.Capacity > 0 ? dto.Capacity : 30,
                Price = dto.Price,
                Currency = "USD",
                Status = dto.Status ?? "Active"
            };

            _db.TransportOptions.Add(item);
            await _db.SaveChangesAsync();

            return CreatedAtAction(nameof(GetAll), new { id = item.Id }, item);
        }

        /// <summary>
        /// Update transit option.
        /// </summary>
        [HttpPut("{id}")]
        public async Task<IActionResult> Update(int id, [FromBody] CreateTransportDto dto)
        {
            var item = await _db.TransportOptions.FindAsync(id);
            if (item == null)
                return NotFound(new { message = "Transport option not found." });

            item.Type = dto.Type;
            item.Provider = dto.Provider;
            item.RouteFrom = dto.RouteFrom;
            item.RouteTo = dto.RouteTo;
            if (TimeSpan.TryParse(dto.Departure, out var dep)) item.DepartureTime = dep;
            if (TimeSpan.TryParse(dto.Arrival, out var arr)) item.ArrivalTime = arr;
            if (dto.Capacity > 0) item.Capacity = dto.Capacity;
            item.Price = dto.Price;
            item.Status = dto.Status ?? item.Status;

            await _db.SaveChangesAsync();
            return Ok(item);
        }

        /// <summary>
        /// Remove transit option.
        /// </summary>
        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            var item = await _db.TransportOptions.FindAsync(id);
            if (item == null)
                return NotFound(new { message = "Transport option not found." });

            _db.TransportOptions.Remove(item);
            await _db.SaveChangesAsync();

            return Ok(new { message = "Transport option deleted." });
        }
    }

    public class CreateTransportDto
    {
        public string Type { get; set; } = "Train";
        public string Provider { get; set; } = string.Empty;
        public string RouteFrom { get; set; } = string.Empty;
        public string RouteTo { get; set; } = string.Empty;
        public string? Departure { get; set; }
        public string? Arrival { get; set; }
        public int Capacity { get; set; } = 40;
        public decimal Price { get; set; }
        public string? Status { get; set; } = "Active";
    }
}
