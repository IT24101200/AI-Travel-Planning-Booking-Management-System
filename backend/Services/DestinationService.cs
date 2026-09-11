using Microsoft.EntityFrameworkCore;
using backend.Data;
using backend.DTOs;
using backend.Models;

namespace backend.Services
{
    public class DestinationService
    {
        private readonly AppDbContext _context;

        public DestinationService(AppDbContext context)
        {
            _context = context;
        }

        public async Task<List<DestinationDto>> GetAllAsync(
            string? search = null,
            string? sortBy = null,
            bool descending = false,
            int page = 1,
            int pageSize = 50)
        {
            var query = _context.Destinations.AsQueryable();

            if (!string.IsNullOrWhiteSpace(search))
            {
                var term = search.Trim().ToLower();
                query = query.Where(d => d.Name.ToLower().Contains(term) || d.Country.ToLower().Contains(term));
            }

            query = sortBy?.ToLower() switch
            {
                "country" => descending ? query.OrderByDescending(d => d.Country) : query.OrderBy(d => d.Country),
                _ => descending ? query.OrderByDescending(d => d.Name) : query.OrderBy(d => d.Name)
            };

            if (page < 1) page = 1;
            if (pageSize < 1) pageSize = 10;

            return await query
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(d => ToDto(d))
                .ToListAsync();
        }

        public async Task<DestinationDto?> GetByIdAsync(int id)
        {
            var destination = await _context.Destinations.FindAsync(id);
            return destination is null ? null : ToDto(destination);
        }

        public async Task<DestinationDto> CreateAsync(CreateDestinationDto dto)
        {
            var destination = new Destination
            {
                Name        = dto.Name,
                Country     = dto.Country,
                Description = dto.Description,
                ImageUrl    = dto.ImageUrl,
                Latitude    = dto.Latitude,
                Longitude   = dto.Longitude
            };

            _context.Destinations.Add(destination);
            await _context.SaveChangesAsync();

            return ToDto(destination);
        }

        public async Task<bool> UpdateAsync(int id, CreateDestinationDto dto)
        {
            var destination = await _context.Destinations.FindAsync(id);
            if (destination is null) return false;

            destination.Name        = dto.Name;
            destination.Country     = dto.Country;
            destination.Description = dto.Description;
            destination.ImageUrl    = dto.ImageUrl;
            destination.Latitude    = dto.Latitude;
            destination.Longitude   = dto.Longitude;

            await _context.SaveChangesAsync();
            return true;
        }

        public async Task<bool> DeleteAsync(int id)
        {
            var destination = await _context.Destinations.FindAsync(id);
            if (destination is null) return false;

            _context.Destinations.Remove(destination);
            await _context.SaveChangesAsync();
            return true;
        }

        // ── Mapping helper ────────────────────────────────────────────────────
        private static DestinationDto ToDto(Destination d) => new DestinationDto
        {
            Id          = d.Id,
            Name        = d.Name,
            Country     = d.Country,
            Description = d.Description,
            ImageUrl    = d.ImageUrl,
            Latitude    = d.Latitude,
            Longitude   = d.Longitude
        };
    }
}
