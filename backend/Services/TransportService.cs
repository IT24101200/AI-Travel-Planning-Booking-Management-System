using Microsoft.EntityFrameworkCore;
using backend.Data;
using backend.DTOs;
using backend.Models;
using backend.Models.Enums;
using System.Data;

namespace backend.Services
{
    /// <summary>
    /// Handles CRUD for transport options (flights, buses, trains, cars).
    /// Same structure as TourService — search/filter/paginate + soft delete.
    /// </summary>
    public class TransportService : ITransportService
    {
        private readonly AppDbContext _context;
        private readonly ICurrencyConversionService _currency;

        public TransportService(AppDbContext context, ICurrencyConversionService? currency = null)
        {
            _context = context;
            _currency = currency ?? new CurrencyConversionService();
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
            int pageSize,
            string? currency = null)
        {
            var query = _context.TransportOptions.AsQueryable();

            // ── Filter by transport type ──
            if (!string.IsNullOrWhiteSpace(type))
                query = query.Where(t => t.Type == ParseTypeFilter(type));

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
            if (!string.IsNullOrWhiteSpace(status) && !status.Equals("All", StringComparison.OrdinalIgnoreCase))
            {
                query = query.Where(t => t.Status == ParseStatusFilter(status));
            }
            else if (string.IsNullOrWhiteSpace(status))
            {
                query = query.Where(t => t.Status == TransportStatus.Active);
            }

            // ── Sort ──
            IOrderedQueryable<TransportOption> orderedQuery = sortBy?.ToLower() switch
            {
                "price" => descending ? query.OrderByDescending(t => t.Price) : query.OrderBy(t => t.Price),
                "departure" => descending ? query.OrderByDescending(t => t.DepartureTime) : query.OrderBy(t => t.DepartureTime),
                "provider" => descending ? query.OrderByDescending(t => t.Provider) : query.OrderBy(t => t.Provider),
                _ => descending ? query.OrderByDescending(t => t.DepartureTime) : query.OrderBy(t => t.DepartureTime)
            };
            query = descending
                ? orderedQuery.ThenByDescending(t => t.Id)
                : orderedQuery.ThenBy(t => t.Id);

            // ── Paginate ──
            var results = await query
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync();

            var targetCurrency = string.IsNullOrWhiteSpace(currency) ? null : _currency.Normalize(currency);
            return results.Select(t => ToDto(t, targetCurrency)).ToList();
        }

        public async Task<int> GetTotalCountAsync(
            string? type, string? routeFrom, string? routeTo,
            decimal? minPrice, decimal? maxPrice, string? status)
        {
            var query = _context.TransportOptions.AsQueryable();

            if (!string.IsNullOrWhiteSpace(type))
                query = query.Where(t => t.Type == ParseTypeFilter(type));

            if (!string.IsNullOrWhiteSpace(routeFrom))
                query = query.Where(t => t.RouteFrom.ToLower().Contains(routeFrom.ToLower()));

            if (!string.IsNullOrWhiteSpace(routeTo))
                query = query.Where(t => t.RouteTo.ToLower().Contains(routeTo.ToLower()));

            if (minPrice.HasValue)
                query = query.Where(t => t.Price >= minPrice.Value);

            if (maxPrice.HasValue)
                query = query.Where(t => t.Price <= maxPrice.Value);

            if (!string.IsNullOrWhiteSpace(status) && !status.Equals("All", StringComparison.OrdinalIgnoreCase))
            {
                query = query.Where(t => t.Status == ParseStatusFilter(status));
            }
            else if (string.IsNullOrWhiteSpace(status))
            {
                query = query.Where(t => t.Status == TransportStatus.Active);
            }

            return await query.CountAsync();
        }

        public async Task<TransportOptionDto?> GetByIdAsync(
            int id,
            string? currency = null,
            bool includeInactive = false)
        {
            var query = _context.TransportOptions.Where(option => option.Id == id);
            if (!includeInactive)
                query = query.Where(option => option.Status == TransportStatus.Active);

            var transport = await query.SingleOrDefaultAsync();
            var targetCurrency = string.IsNullOrWhiteSpace(currency) ? null : _currency.Normalize(currency);
            return transport is null ? null : ToDto(transport, targetCurrency);
        }

        public async Task<TransportCoverageDto> GetCoverageAsync(
            string routeFrom,
            string routeTo,
            DateTime startDate,
            DateTime endDate,
            int travellers,
            CancellationToken cancellationToken = default)
        {
            var normalizedFrom = TransportCompatibility.Normalize(routeFrom);
            var normalizedTo = TransportCompatibility.Normalize(routeTo);
            if (string.IsNullOrWhiteSpace(normalizedFrom) || string.IsNullOrWhiteSpace(normalizedTo))
                throw new ArgumentException("Both route endpoints are required.");
            if (string.Equals(normalizedFrom, normalizedTo, StringComparison.OrdinalIgnoreCase))
                throw new ArgumentException("Route origin and destination must be different.");
            if (endDate.Date < startDate.Date)
                throw new ArgumentException("Coverage end date cannot be before the start date.");
            if (travellers < 1 || travellers > 100)
                throw new ArgumentException("Travellers must be between 1 and 100.");

            var active = await _context.TransportOptions
                .AsNoTracking()
                .Where(option => option.Status == TransportStatus.Active)
                .ToListAsync(cancellationToken);

            var routeMatches = active
                .Where(option => RouteEquals(option.RouteFrom, normalizedFrom)
                    && RouteEquals(option.RouteTo, normalizedTo))
                .ToList();

            var dateMatches = routeMatches
                .Where(option => option.ArrivalTime > option.DepartureTime
                    && option.DepartureTime.Date >= startDate.Date
                    && option.ArrivalTime.Date <= endDate.Date)
                .ToList();

            var capacityMatches = dateMatches
                .Where(option => option.Capacity >= travellers)
                .ToList();

            var availableMatches = 0;
            foreach (var option in capacityMatches)
            {
                var reservedSeats = await TransportInventory.CountReservedSeatsAsync(
                    _context,
                    option.Id,
                    cancellationToken: cancellationToken);
                if (option.Capacity - reservedSeats >= travellers)
                    availableMatches++;
            }

            var reasonCode = availableMatches > 0
                ? "COVERAGE_AVAILABLE"
                : routeMatches.Count == 0
                    ? "NO_ROUTE"
                    : dateMatches.Count == 0
                        ? "NO_DATE_MATCH"
                        : capacityMatches.Count == 0
                            ? "NO_CAPACITY"
                            : "NO_AVAILABILITY";

            var message = reasonCode switch
            {
                "COVERAGE_AVAILABLE" => "Matching active transport is available for this route and date range.",
                "NO_ROUTE" => "No active transport exists for this route.",
                "NO_DATE_MATCH" => "Transport exists for this route, but not in the selected date range.",
                "NO_CAPACITY" => "Matching transport exists, but none supports this traveller count.",
                _ => "Matching departures exist but currently have insufficient available seats."
            };

            return new TransportCoverageDto
            {
                RouteFrom = routeFrom.Trim(),
                RouteTo = routeTo.Trim(),
                StartDate = startDate,
                EndDate = endDate,
                Travellers = travellers,
                TotalActive = active.Count,
                RouteMatches = routeMatches.Count,
                DateMatches = dateMatches.Count,
                CapacityMatches = capacityMatches.Count,
                AvailableMatches = availableMatches,
                Status = availableMatches > 0 ? "Available" : "Unavailable",
                ReasonCode = reasonCode,
                Message = message
            };
        }

        public async Task<TransportOptionDto> CreateAsync(CreateTransportOptionDto dto)
        {
            dto.Currency = _currency.Normalize(dto.Currency, "Transport currency");
            // Parse the type string from the DTO into our enum
            var transportType = ParseType(dto.Type);
            ValidateSchedule(dto);

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
                ImageUrl           = dto.ImageUrl,
                Status             = ParseStatus(dto.Status)
            };

            _context.TransportOptions.Add(transport);
            await _context.SaveChangesAsync();

            return ToDto(transport);
        }

        public async Task<bool> UpdateAsync(int id, CreateTransportOptionDto dto)
        {
            dto.Currency = _currency.Normalize(dto.Currency, "Transport currency");
            await using var transaction = await _context.Database.BeginTransactionAsync(IsolationLevel.Serializable);
            var transport = await TransportInventory.LoadForUpdateAsync(_context, id);
            if (transport is null)
            {
                await transaction.CommitAsync();
                return false;
            }

            transport.Type               = ParseType(dto.Type);
            ValidateSchedule(dto);
            if (dto.Capacity < transport.Capacity)
            {
                var reservedSeats = await TransportInventory.CountReservedSeatsAsync(_context, id);
                if (dto.Capacity < reservedSeats)
                {
                    throw new TransportBusinessException(
                        "TRANSPORT_CAPACITY_CONFLICT",
                        "Transport capacity cannot be reduced below seats already reserved.");
                }
            }
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
            transport.Status             = ParseStatus(dto.Status);
            transport.ImageUrl = dto.ImageUrl;

            await _context.SaveChangesAsync();
            await transaction.CommitAsync();
            return true;
        }

        public async Task<TransportDeleteResult> DeleteAsync(int id)
        {
            var transport = await _context.TransportOptions.FindAsync(id);
            if (transport is null) return new TransportDeleteResult(false, false, 0);

            var bookingReferences = await _context.BookingItems
                .CountAsync(item => item.TransportOptionId == id);
            if (bookingReferences > 0)
                return new TransportDeleteResult(true, false, bookingReferences);

            _context.TransportOptions.Remove(transport);
            await _context.SaveChangesAsync();
            return new TransportDeleteResult(true, true, 0);
        }

        private static TransportStatus ParseStatus(string? value)
        {
            if (string.IsNullOrWhiteSpace(value)) return TransportStatus.Active;
            if (TryParseDefined(value, out TransportStatus parsed)) return parsed;
            throw new ArgumentException("Transport status must be Active or Inactive.");
        }

        private static TransportType ParseType(string? value)
        {
            if (TryParseDefined(value, out TransportType parsed)) return parsed;
            throw new ArgumentException("Transport type must be Car, Van, Train, Bus, or Flight.");
        }

        private static TransportType ParseTypeFilter(string value)
        {
            if (TryParseDefined(value, out TransportType parsed)) return parsed;
            throw new ArgumentException("Transport type filter is invalid.");
        }

        private static TransportStatus ParseStatusFilter(string value)
        {
            if (TryParseDefined(value, out TransportStatus parsed)) return parsed;
            throw new ArgumentException("Transport status filter is invalid.");
        }

        private static bool TryParseDefined<TEnum>(string? value, out TEnum parsed)
            where TEnum : struct, Enum
        {
            return Enum.TryParse(value, ignoreCase: true, out parsed) && Enum.IsDefined(parsed);
        }

        private static void ValidateSchedule(CreateTransportOptionDto dto)
        {
            if (dto.ArrivalTime <= dto.DepartureTime)
                throw new ArgumentException("Arrival time must be later than departure time.");
            if (dto.Capacity < 1 || dto.Capacity > 1000)
                throw new ArgumentException("Capacity must be between 1 and 1000.");
            if (dto.Price < 0)
                throw new ArgumentException("Price must be zero or greater.");
        }

        private static bool RouteEquals(string value, string normalizedExpected)
        {
            return string.Equals(
                TransportCompatibility.Normalize(value),
                normalizedExpected,
                StringComparison.OrdinalIgnoreCase);
        }

        // ── Mapping helper ──
        private TransportOptionDto ToDto(TransportOption t, string? targetCurrency = null) => new TransportOptionDto
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
            Price              = targetCurrency == null ? t.Price : _currency.Convert(t.Price, t.Currency, targetCurrency),
            Currency           = targetCurrency ?? t.Currency,
            ImageUrl           = t.ImageUrl,
            Status             = t.Status.ToString()
        };
    }
}
