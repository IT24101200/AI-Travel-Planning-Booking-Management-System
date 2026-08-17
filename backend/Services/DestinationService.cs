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

        public async Task<List<DestinationDto>> GetAllAsync()
        {
            return await _context.Destinations
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
