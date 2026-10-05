using Microsoft.EntityFrameworkCore;
using backend.Data;
using backend.DTOs;
using backend.Models;

namespace backend.Services;

public class DestinationService
{
    private readonly AppDbContext _context;

    public DestinationService(AppDbContext context) => _context = context;

    public async Task<List<DestinationDto>> GetAllAsync(
        string? search = null,
        string? sortBy = null,
        bool descending = false,
        int page = 1,
        int pageSize = 50)
    {
        var query = _context.Destinations.AsNoTracking();

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

        page = Math.Max(page, 1);
        pageSize = pageSize < 1 ? 10 : Math.Min(pageSize, 1000);

        var destinations = await query
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(d => ToDto(d))
            .ToListAsync();

        await PopulateDependencyCountsAsync(destinations);
        return destinations;
    }

    public async Task<DestinationDto?> GetByIdAsync(int id)
    {
        var destination = await _context.Destinations.AsNoTracking().FirstOrDefaultAsync(d => d.Id == id);
        if (destination is null) return null;

        var dto = ToDto(destination);
        await PopulateDependencyCountsAsync(new[] { dto });
        return dto;
    }

    public async Task<DestinationDto> CreateAsync(CreateDestinationDto dto)
    {
        Validate(dto);
        var normalizedName = NormalizeName(dto.Name);
        if (await _context.Destinations.AnyAsync(d => d.NormalizedName == normalizedName))
            throw new DestinationConflictException("A destination with this name already exists.");

        var destination = new Destination
        {
            Name = dto.Name.Trim(),
            NormalizedName = normalizedName,
            Country = dto.Country.Trim(),
            Description = CleanOptional(dto.Description),
            ImageUrl = CleanOptional(dto.ImageUrl),
            Latitude = dto.Latitude,
            Longitude = dto.Longitude
        };

        try
        {
            _context.Destinations.Add(destination);
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateException ex) when (IsNormalizedNameUniqueViolation(ex))
        {
            throw new DestinationConflictException("A destination with this name already exists.");
        }

        return ToDto(destination);
    }

    public async Task<bool> UpdateAsync(int id, CreateDestinationDto dto)
    {
        Validate(dto);
        var destination = await _context.Destinations.FindAsync(id);
        if (destination is null) return false;

        var normalizedName = NormalizeName(dto.Name);
        if (await _context.Destinations.AnyAsync(d => d.Id != id && d.NormalizedName == normalizedName))
            throw new DestinationConflictException("A destination with this name already exists.");

        destination.Name = dto.Name.Trim();
        destination.NormalizedName = normalizedName;
        destination.Country = dto.Country.Trim();
        destination.Description = CleanOptional(dto.Description);
        destination.ImageUrl = CleanOptional(dto.ImageUrl);
        destination.Latitude = dto.Latitude;
        destination.Longitude = dto.Longitude;

        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateException ex) when (IsNormalizedNameUniqueViolation(ex))
        {
            throw new DestinationConflictException("A destination with this name already exists.");
        }

        return true;
    }

    public async Task<bool> DeleteAsync(int id)
    {
        var destination = await _context.Destinations.FindAsync(id);
        if (destination is null) return false;

        var counts = await GetDependencyCountsAsync(id);
        if (counts.Tours > 0 || counts.Hotels > 0)
        {
            throw new DestinationConflictException(
                "Destination cannot be deleted because it is currently referenced.",
                new { tours = counts.Tours, hotels = counts.Hotels });
        }

        _context.Destinations.Remove(destination);
        await _context.SaveChangesAsync();
        return true;
    }

    private async Task PopulateDependencyCountsAsync(IEnumerable<DestinationDto> destinations)
    {
        var list = destinations.ToList();
        var ids = list.Select(d => d.Id).ToArray();
        if (ids.Length == 0) return;

        var tourCounts = await _context.Tours.AsNoTracking()
            .Where(t => ids.Contains(t.DestinationId))
            .GroupBy(t => t.DestinationId)
            .Select(g => new { Id = g.Key, Count = g.Count() })
            .ToDictionaryAsync(x => x.Id, x => x.Count);
        var hotelCounts = await _context.Hotels.AsNoTracking()
            .Where(h => ids.Contains(h.DestinationId))
            .GroupBy(h => h.DestinationId)
            .Select(g => new { Id = g.Key, Count = g.Count() })
            .ToDictionaryAsync(x => x.Id, x => x.Count);

        foreach (var destination in list)
        {
            destination.TourCount = tourCounts.GetValueOrDefault(destination.Id);
            destination.HotelCount = hotelCounts.GetValueOrDefault(destination.Id);
        }
    }

    private async Task<DestinationDependencyCounts> GetDependencyCountsAsync(int id) =>
        new(
            await _context.Tours.CountAsync(t => t.DestinationId == id),
            await _context.Hotels.CountAsync(h => h.DestinationId == id));

    private static string NormalizeName(string name) => name.Trim().ToUpperInvariant();

    private static string? CleanOptional(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    private static void Validate(CreateDestinationDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.Name) || string.IsNullOrWhiteSpace(dto.Country))
            throw new ArgumentException("Destination name and country are required.");
        if (!double.IsFinite(dto.Latitude) || !double.IsFinite(dto.Longitude) ||
            dto.Latitude is < -90 or > 90 || dto.Longitude is < -180 or > 180)
            throw new ArgumentException("Latitude must be between -90 and 90 and longitude must be between -180 and 180.");
    }

    private static bool IsNormalizedNameUniqueViolation(DbUpdateException ex) =>
        ex.InnerException?.Message.Contains("NormalizedName", StringComparison.OrdinalIgnoreCase) == true;

    private static DestinationDto ToDto(Destination d) => new()
    {
        Id = d.Id,
        Name = d.Name,
        Country = d.Country,
        Description = d.Description,
        ImageUrl = d.ImageUrl,
        Latitude = d.Latitude,
        Longitude = d.Longitude
    };
}
