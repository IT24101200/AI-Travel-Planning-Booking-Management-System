using Microsoft.EntityFrameworkCore;
using backend.Data;
using backend.DTOs;
using backend.Models;
using backend.Models.Enums;

namespace backend.Services
{
    /// <summary>
    /// Handles CRUD for transport options (flights, buses, trains, cars).
    /// Same structure as TourService — search/filter/paginate + soft delete.
    /// </summary>
    public class TransportService : ITransportService
    {
        private readonly AppDbContext _context;

        public TransportService(AppDbContext context)
        {
            _context = context;
        }

        /// <summary>
        /// Search transport options with filters.
        /// Filters: type (Flight/Bus/etc), route, price range, status.
        /// </summary>
        public async Task<List<TransportOptionDto>> SearchAsync(
            string? type,
            string? routeFrom,
            string? routeTo,
            decimal? minPrice,
            decimal? maxPrice,
            string? status,
            string? sortBy,
            bool descending,
            int page,
            int pageSize)
        {
            var query = _context.TransportOptions.AsQueryable();

            // ── Filter by transport type ──
            if (!string.IsNullOrWhiteSpace(type))
            {
                // Try to parse the type string into our enum
                if (Enum.TryParse<TransportType>(type, ignoreCase: true, out var parsedType))
                {
                    query = query.Where(t => t.Type == parsedType);
                }
            }

            // ── Filter by route ──
            if (!string.IsNullOrWhiteSpace(routeFrom))
            {
                var term = routeFrom.ToLower();
                query = query.Where(t => t.RouteFrom.ToLower().Contains(term));
            }

            if (!string.IsNullOrWhiteSpace(routeTo))
            {
                var term = routeTo.ToLower();
                query = query.Where(t => t.RouteTo.ToLower().Contains(term));
            }

            // ── Filter by price range ──
            if (minPrice.HasValue)
                query = query.Where(t => t.Price >= minPrice.Value);

            if (maxPrice.HasValue)
                query = query.Where(t => t.Price <= maxPrice.Value);

            // ── Filter by status (default: Active) ──
            var statusFilter = string.IsNullOrWhiteSpace(status)
                ? TransportStatus.Active
                : Enum.Parse<TransportStatus>(status, ignoreCase: true);
            query = query.Where(t => t.Status == statusFilter);

            // ── Sort ──
            query = sortBy?.ToLower() switch
            {
                "price" => descending ? query.OrderByDescending(t => t.Price) : query.OrderBy(t => t.Price),
                "departure" => descending ? query.OrderByDescending(t => t.DepartureTime) : query.OrderBy(t => t.DepartureTime),
                "provider" => descending ? query.OrderByDescending(t => t.Provider) : query.OrderBy(t => t.Provider),
                _ => query.OrderBy(t => t.DepartureTime)  // default: soonest first
            };

            // ── Paginate ──
            var results = await query
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync();

            return results.Select(t => ToDto(t)).ToList();
        }

        public async Task<int> GetTotalCountAsync(
            string? type, string? routeFrom, string? routeTo,
            decimal? minPrice, decimal? maxPrice, string? status)
        {
            var query = _context.TransportOptions.AsQueryable();

            if (!string.IsNullOrWhiteSpace(type) &&
                Enum.TryParse<TransportType>(type, ignoreCase: true, out var parsedType))
            {
                query = query.Where(t => t.Type == parsedType);
            }

            if (!string.IsNullOrWhiteSpace(routeFrom))
                query = query.Where(t => t.RouteFrom.ToLower().Contains(routeFrom.ToLower()));

            if (!string.IsNullOrWhiteSpace(routeTo))
                query = query.Where(t => t.RouteTo.ToLower().Contains(routeTo.ToLower()));

            if (minPrice.HasValue)
                query = query.Where(t => t.Price >= minPrice.Value);

            if (maxPrice.HasValue)
                query = query.Where(t => t.Price <= maxPrice.Value);

            var statusFilter = string.IsNullOrWhiteSpace(status)
                ? TransportStatus.Active
                : Enum.Parse<TransportStatus>(status, ignoreCase: true);
            query = query.Where(t => t.Status == statusFilter);

            return await query.CountAsync();
        }

        public async Task<TransportOptionDto?> GetByIdAsync(int id)
        {
            var transport = await _context.TransportOptions.FindAsync(id);
            return transport is null ? null : ToDto(transport);
        }

        public async Task<TransportOptionDto> CreateAsync(CreateTransportOptionDto dto)
        {
            // Parse the type string from the DTO into our enum
            var transportType = Enum.Parse<TransportType>(dto.Type, ignoreCase: true);

            var transport = new TransportOption
            {
                Type               = transportType,
                Provider           = dto.Provider,
                RouteFrom          = dto.RouteFrom,
                RouteTo            = dto.RouteTo,
                RouteFromLatitude  = dto.RouteFromLatitude,
                RouteFromLongitude = dto.RouteFromLongitude,
                RouteToLatitude    = dto.RouteToLatitude,
                RouteToLongitude   = dto.RouteToLongitude,
                DepartureTime      = dto.DepartureTime,
                ArrivalTime        = dto.ArrivalTime,
                Capacity           = dto.Capacity,
                Price              = dto.Price,
                Currency           = dto.Currency,
                Status             = TransportStatus.Active
            };

            _context.TransportOptions.Add(transport);
            await _context.SaveChangesAsync();

            return ToDto(transport);
        }

        public async Task<bool> UpdateAsync(int id, CreateTransportOptionDto dto)
        {
            var transport = await _context.TransportOptions.FindAsync(id);
            if (transport is null) return false;

            transport.Type               = Enum.Parse<TransportType>(dto.Type, ignoreCase: true);
            transport.Provider           = dto.Provider;
            transport.RouteFrom          = dto.RouteFrom;
            transport.RouteTo            = dto.RouteTo;
            transport.RouteFromLatitude  = dto.RouteFromLatitude;
            transport.RouteFromLongitude = dto.RouteFromLongitude;
            transport.RouteToLatitude    = dto.RouteToLatitude;
            transport.RouteToLongitude   = dto.RouteToLongitude;
            transport.DepartureTime      = dto.DepartureTime;
            transport.ArrivalTime        = dto.ArrivalTime;
            transport.Capacity           = dto.Capacity;
            transport.Price              = dto.Price;
            transport.Currency           = dto.Currency;

            await _context.SaveChangesAsync();
            return true;
        }

        public async Task<bool> SoftDeleteAsync(int id)
        {
            var transport = await _context.TransportOptions.FindAsync(id);
            if (transport is null) return false;

            transport.Status = TransportStatus.Inactive;
            await _context.SaveChangesAsync();
            return true;
        }

        // ── Mapping helper ──
        private static TransportOptionDto ToDto(TransportOption t) => new TransportOptionDto
        {
            Id                 = t.Id,
            Type               = t.Type.ToString(),     // enum → string for the API response
            Provider           = t.Provider,
            RouteFrom          = t.RouteFrom,
            RouteTo            = t.RouteTo,
            RouteFromLatitude  = t.RouteFromLatitude,
            RouteFromLongitude = t.RouteFromLongitude,
            RouteToLatitude    = t.RouteToLatitude,
            RouteToLongitude   = t.RouteToLongitude,
            DepartureTime      = t.DepartureTime,
            ArrivalTime        = t.ArrivalTime,
            Capacity           = t.Capacity,
            Price              = t.Price,
            Currency           = t.Currency,
            Status             = t.Status.ToString()
        };
    }
}
