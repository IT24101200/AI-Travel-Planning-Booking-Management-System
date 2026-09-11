using backend.Data;
using backend.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace backend.Controllers
{
    /// <summary>
    /// Student C — Hotel & Vendor Management Controller.
    /// Manages hotel properties and room inventories.
    /// </summary>
    [ApiController]
    [Route("api/[controller]")]
    public class HotelController : ControllerBase
    {
        private readonly AppDbContext _db;

        public HotelController(AppDbContext db)
        {
            _db = db;
        }

        /// <summary>
        /// List all hotels with optional destination filter.
        /// </summary>
        [HttpGet]
        public async Task<IActionResult> GetAll([FromQuery] int? destinationId, [FromQuery] string? search)
        {
            var query = _db.Hotels
                .Include(h => h.Destination)
                .Include(h => h.Rooms)
                .AsQueryable();

            if (destinationId.HasValue)
                query = query.Where(h => h.DestinationId == destinationId.Value);

            if (!string.IsNullOrWhiteSpace(search))
                query = query.Where(h => h.Name.Contains(search) || h.Address.Contains(search));

            var list = await query
                .OrderBy(h => h.Name)
                .Select(h => new
                {
                    h.Id,
                    h.Name,
                    DestinationName = h.Destination != null ? h.Destination.Name : "Sri Lanka",
                    h.Address,
                    h.StarRating,
                    h.Status,
                    RoomCount = h.Rooms.Sum(r => r.TotalRooms),
                    PriceNight = h.Rooms.Any() ? h.Rooms.Min(r => r.PricePerNight) : 100m,
                    Currency = h.Rooms.Any() ? h.Rooms.First().Currency : "USD"
                })
                .ToListAsync();

            return Ok(list);
        }

        /// <summary>
        /// Get hotel details including room types.
        /// </summary>
        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(int id)
        {
            var hotel = await _db.Hotels
                .Include(h => h.Destination)
                .Include(h => h.Rooms)
                .FirstOrDefaultAsync(h => h.Id == id);

            if (hotel == null)
                return NotFound(new { message = "Hotel not found." });

            return Ok(hotel);
        }

        /// <summary>
        /// Create a new hotel property.
        /// </summary>
        [HttpPost]
        public async Task<IActionResult> Create([FromBody] CreateHotelDto dto)
        {
            var hotel = new Hotel
            {
                DestinationId = dto.DestinationId > 0 ? dto.DestinationId : 1,
                Name = dto.Name,
                Address = dto.Address ?? "",
                StarRating = dto.StarRating > 0 ? dto.StarRating : 4,
                Status = dto.Status ?? "Active"
            };

            _db.Hotels.Add(hotel);
            await _db.SaveChangesAsync();

            // Create default room tier
            var room = new Room
            {
                HotelId = hotel.Id,
                RoomType = "Standard Deluxe",
                PricePerNight = dto.PriceNight > 0 ? dto.PriceNight : 120m,
                TotalRooms = dto.TotalRooms > 0 ? dto.TotalRooms : 10,
                Capacity = 2,
                Currency = "USD"
            };

            _db.Rooms.Add(room);
            await _db.SaveChangesAsync();

            return CreatedAtAction(nameof(GetById), new { id = hotel.Id }, hotel);
        }

        /// <summary>
        /// Update an existing hotel.
        /// </summary>
        [HttpPut("{id}")]
        public async Task<IActionResult> Update(int id, [FromBody] CreateHotelDto dto)
        {
            var hotel = await _db.Hotels.Include(h => h.Rooms).FirstOrDefaultAsync(h => h.Id == id);
            if (hotel == null)
                return NotFound(new { message = "Hotel not found." });

            hotel.Name = dto.Name;
            hotel.Address = dto.Address ?? hotel.Address;
            hotel.StarRating = dto.StarRating;
            hotel.Status = dto.Status ?? hotel.Status;

            if (dto.PriceNight > 0 && hotel.Rooms.Any())
            {
                var room = hotel.Rooms.First();
                room.PricePerNight = dto.PriceNight;
                if (dto.TotalRooms > 0) room.TotalRooms = dto.TotalRooms;
            }

            await _db.SaveChangesAsync();
            return Ok(hotel);
        }

        /// <summary>
        /// Delete a hotel property.
        /// </summary>
        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            var hotel = await _db.Hotels.FindAsync(id);
            if (hotel == null)
                return NotFound(new { message = "Hotel not found." });

            _db.Hotels.Remove(hotel);
            await _db.SaveChangesAsync();

            return Ok(new { message = "Hotel deleted successfully." });
        }
    }

    public class CreateHotelDto
    {
        public int DestinationId { get; set; } = 1;
        public string Name { get; set; } = string.Empty;
        public string? Address { get; set; }
        public int StarRating { get; set; } = 4;
        public string? Status { get; set; } = "Active";
        public decimal PriceNight { get; set; } = 120m;
        public int TotalRooms { get; set; } = 15;
    }
}
