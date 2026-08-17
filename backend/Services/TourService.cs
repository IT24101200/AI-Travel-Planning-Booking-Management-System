using Microsoft.EntityFrameworkCore;
using backend.Data;
using backend.DTOs;
using backend.Models;

namespace backend.Services
{
    public class TourService
    {
        private readonly AppDbContext _context;

        public TourService(AppDbContext context)
        {
            _context = context;
        }

        public async Task<List<TourDto>> SearchAsync(
            int? destinationId,
            string? category,
            decimal? minPrice,
            decimal? maxPrice,
            string? status,
            int page,
            int pageSize)
        {
            var query = _context.Tours.AsQueryable();

            // Apply filters only when a value is provided
            if (destinationId.HasValue)
                query = query.Where(t => t.DestinationId == destinationId.Value);

            if (!string.IsNullOrWhiteSpace(category))
                query = query.Where(t => t.Category == category);

            if (minPrice.HasValue)
                query = query.Where(t => t.Price >= minPrice.Value);

            if (maxPrice.HasValue)
                query = query.Where(t => t.Price <= maxPrice.Value);

            // Default to "Active" when no status filter is supplied
            var statusFilter = string.IsNullOrWhiteSpace(status) ? "Active" : status;
            query = query.Where(t => t.Status == statusFilter);

            var tours = await query
                .OrderBy(t => t.Name)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync();

            return tours.Select(t => ToDto(t)).ToList();
        }

        public async Task<TourDto?> GetByIdAsync(int id)
        {
            var tour = await _context.Tours.FindAsync(id);
            return tour is null ? null : ToDto(tour);
        }

        public async Task<TourDto> CreateAsync(CreateTourDto dto)
        {
            var now = DateTime.UtcNow;

            var tour = new Tour
            {
                DestinationId    = dto.DestinationId,
                Name             = dto.Name,
                Category         = dto.Category,
                Description      = dto.Description,
                Price            = dto.Price,
                Currency         = dto.Currency,
                DurationHours    = dto.DurationHours,
                DefaultStartTime = dto.DefaultStartTime,
                Latitude         = dto.Latitude,
                Longitude        = dto.Longitude,
                Status           = dto.Status,
                CreatedAt        = now,
                UpdatedAt        = now
            };

            _context.Tours.Add(tour);
            await _context.SaveChangesAsync();

            return ToDto(tour);
        }

        public async Task<bool> UpdateAsync(int id, CreateTourDto dto)
        {
            var tour = await _context.Tours.FindAsync(id);
            if (tour is null) return false;

            tour.DestinationId    = dto.DestinationId;
            tour.Name             = dto.Name;
            tour.Category         = dto.Category;
            tour.Description      = dto.Description;
            tour.Price            = dto.Price;
            tour.Currency         = dto.Currency;
            tour.DurationHours    = dto.DurationHours;
            tour.DefaultStartTime = dto.DefaultStartTime;
            tour.Latitude         = dto.Latitude;
            tour.Longitude        = dto.Longitude;
            tour.Status           = dto.Status;
            tour.UpdatedAt        = DateTime.UtcNow;

            await _context.SaveChangesAsync();
            return true;
        }

        public async Task<bool> SoftDeleteAsync(int id)
        {
            var tour = await _context.Tours.FindAsync(id);
            if (tour is null) return false;

            tour.Status    = "Inactive";
            tour.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();
            return true;
        }

        // ── Mapping helper ────────────────────────────────────────────────────
        private static TourDto ToDto(Tour t) => new TourDto
        {
            Id               = t.Id,
            DestinationId    = t.DestinationId,
            Name             = t.Name,
            Category         = t.Category,
            Description      = t.Description,
            Price            = t.Price,
            Currency         = t.Currency,
            DurationHours    = t.DurationHours,
            DefaultStartTime = t.DefaultStartTime,
            Latitude         = t.Latitude,
            Longitude        = t.Longitude,
            Status           = t.Status,
            CreatedAt        = t.CreatedAt,
            UpdatedAt        = t.UpdatedAt
        };
    }
}
