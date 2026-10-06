using Microsoft.EntityFrameworkCore;
using backend.Data;
using backend.DTOs;
using backend.Models;
using backend.Models.Enums;

namespace backend.Services
{
    /// <summary>
    /// Handles all hotel and room CRUD operations.
    /// Pattern: same as TourService/DestinationService — inject AppDbContext, use ToDto() helper.
    /// </summary>
    public class HotelService : IHotelService
    {
        private readonly AppDbContext _context;
        private readonly ICurrencyConversionService _currency;

        public HotelService(AppDbContext context, ICurrencyConversionService? currency = null)
        {
            _context = context;
            _currency = currency ?? new CurrencyConversionService();
        }

        // ══════════════════════════════════════════════════════════════════
        //  HOTEL CRUD
        // ══════════════════════════════════════════════════════════════════

        /// <summary>
        /// Search hotels with filters, sorting, and pagination.
        /// Works like TourService.SearchAsync — filters are optional.
        /// </summary>
        public async Task<List<HotelDto>> GetAllAsync(
            string? search,
            int? destinationId,
            int? minStarRating,
            string? status,
            string? sortBy,
            bool descending,
            int page,
            int pageSize,
            string? currency = null)
        {
            // Start with all hotels
            var query = _context.Hotels
                .Include(h => h.Rooms)   // load rooms so we can include them in response
                .AsQueryable();

            // ── Apply filters ──
            if (!string.IsNullOrWhiteSpace(search))
            {
                var term = search.ToLower();
                query = query.Where(h =>
                    h.Name.ToLower().Contains(term) ||
                    (h.Address != null && h.Address.ToLower().Contains(term)));
            }

            if (destinationId.HasValue)
                query = query.Where(h => h.DestinationId == destinationId.Value);

            if (minStarRating.HasValue)
                query = query.Where(h => h.StarRating >= minStarRating.Value);

            // Default to Active if no status filter provided (same as TourService)
            if (!string.IsNullOrWhiteSpace(status) && !status.Equals("All", StringComparison.OrdinalIgnoreCase))
            {
                if (Enum.TryParse<HotelStatus>(status, true, out var statusFilter))
                    query = query.Where(h => h.Status == statusFilter);
            }
            else if (string.IsNullOrWhiteSpace(status))
            {
                query = query.Where(h => h.Status == HotelStatus.Active);
            }

            // ── Sort ──
            query = sortBy?.ToLower() switch
            {
                "name" => descending ? query.OrderByDescending(h => h.Name) : query.OrderBy(h => h.Name),
                "starrating" => descending ? query.OrderByDescending(h => h.StarRating) : query.OrderBy(h => h.StarRating),
                _ => query.OrderBy(h => h.Name)  // default: alphabetical
            };

            // ── Paginate ──
            var hotels = await query
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync();

            var targetCurrency = string.IsNullOrWhiteSpace(currency) ? null : _currency.Normalize(currency);
            return hotels.Select(h => ToDto(h, targetCurrency)).ToList();
        }

        /// <summary>
        /// Count matching hotels (for pagination metadata).
        /// </summary>
        public async Task<int> GetTotalCountAsync(
            string? search, int? destinationId, int? minStarRating, string? status)
        {
            var query = _context.Hotels.AsQueryable();

            if (!string.IsNullOrWhiteSpace(search))
            {
                var term = search.ToLower();
                query = query.Where(h =>
                    h.Name.ToLower().Contains(term) ||
                    (h.Address != null && h.Address.ToLower().Contains(term)));
            }

            if (destinationId.HasValue)
                query = query.Where(h => h.DestinationId == destinationId.Value);

            if (minStarRating.HasValue)
                query = query.Where(h => h.StarRating >= minStarRating.Value);

            if (!string.IsNullOrWhiteSpace(status) && !status.Equals("All", StringComparison.OrdinalIgnoreCase))
            {
                if (Enum.TryParse<HotelStatus>(status, true, out var statusFilter))
                    query = query.Where(h => h.Status == statusFilter);
            }
            else if (string.IsNullOrWhiteSpace(status))
            {
                query = query.Where(h => h.Status == HotelStatus.Active);
            }

            return await query.CountAsync();
        }

        /// <summary>
        /// Get a single hotel by ID, including its rooms.
        /// </summary>
        public async Task<HotelDto?> GetByIdAsync(int id, string? currency = null)
        {
            var hotel = await _context.Hotels
                .Include(h => h.Rooms)
                .FirstOrDefaultAsync(h => h.Id == id);

            var targetCurrency = string.IsNullOrWhiteSpace(currency) ? null : _currency.Normalize(currency);
            return hotel is null ? null : ToDto(hotel, targetCurrency);
        }

        /// <summary>
        /// Create a new hotel. Status defaults to Active.
        /// </summary>
        public async Task<HotelDto> CreateAsync(CreateHotelDto dto)
        {
            var hotel = new Hotel
            {
                DestinationId = dto.DestinationId,
                Name          = dto.Name,
                Address       = dto.Address,
                ContactEmail  = NormalizeOptional(dto.ContactEmail),
                ContactPhone  = NormalizeOptional(dto.ContactPhone),
                ImageUrl      = dto.ImageUrl,
                Latitude      = dto.Latitude,
                Longitude     = dto.Longitude,
                StarRating    = dto.StarRating,
                Status        = ParseStatus(dto.Status)
            };

            _context.Hotels.Add(hotel);
            await _context.SaveChangesAsync();

            return ToDto(hotel);
        }

        /// <summary>
        /// Update an existing hotel's details.
        /// </summary>
        public async Task<bool> UpdateAsync(int id, CreateHotelDto dto)
        {
            var hotel = await _context.Hotels.FindAsync(id);
            if (hotel is null) return false;

            hotel.DestinationId = dto.DestinationId;
            hotel.Name          = dto.Name;
            hotel.Address       = dto.Address;
            hotel.ContactEmail  = NormalizeOptional(dto.ContactEmail);
            hotel.ContactPhone  = NormalizeOptional(dto.ContactPhone);
            hotel.ImageUrl      = dto.ImageUrl;
            hotel.Latitude      = dto.Latitude;
            hotel.Longitude     = dto.Longitude;
            hotel.StarRating    = dto.StarRating;
            hotel.Status        = ParseStatus(dto.Status);

            await _context.SaveChangesAsync();
            return true;
        }

        /// <summary>
        /// Soft delete — sets Status to Inactive instead of removing from DB.
        /// Same pattern as TourService.SoftDeleteAsync.
        /// </summary>
        public async Task<bool> SoftDeleteAsync(int id)
        {
            var hotel = await _context.Hotels.FindAsync(id);
            if (hotel is null) return false;

            hotel.Status = HotelStatus.Inactive;
            await _context.SaveChangesAsync();
            return true;
        }

        private static string? NormalizeOptional(string? value) =>
            string.IsNullOrWhiteSpace(value) ? null : value.Trim();

        private static HotelStatus ParseStatus(string? value) =>
            string.IsNullOrWhiteSpace(value)
                ? HotelStatus.Active
                : Enum.Parse<HotelStatus>(value, ignoreCase: true);

        // ══════════════════════════════════════════════════════════════════
        //  ROOM CRUD (nested under a hotel)
        // ══════════════════════════════════════════════════════════════════

        public async Task<List<RoomDto>> SearchRoomsAsync(string? roomType, int? minCapacity, decimal? maxPrice, string? sortBy, bool descending, int page, int pageSize, string? currency = null)
        {
            var query = _context.Rooms.AsQueryable();

            if (!string.IsNullOrWhiteSpace(roomType))
            {
                var term = roomType.ToLower();
                query = query.Where(r => r.RoomType.ToLower().Contains(term));
            }

            if (minCapacity.HasValue)
                query = query.Where(r => r.Capacity >= minCapacity.Value);

            if (maxPrice.HasValue)
                query = query.Where(r => r.PricePerNight <= maxPrice.Value);

            query = sortBy?.ToLower() switch
            {
                "price" => descending ? query.OrderByDescending(r => r.PricePerNight) : query.OrderBy(r => r.PricePerNight),
                "capacity" => descending ? query.OrderByDescending(r => r.Capacity) : query.OrderBy(r => r.Capacity),
                _ => descending ? query.OrderByDescending(r => r.HotelId).ThenByDescending(r => r.Id) : query.OrderBy(r => r.HotelId).ThenBy(r => r.Id)
            };

            var rooms = await query
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync();

            var targetCurrency = string.IsNullOrWhiteSpace(currency) ? null : _currency.Normalize(currency);
            return rooms.Select(r => ToRoomDto(r, targetCurrency)).ToList();
        }

        public async Task<List<RoomDto>> GetRoomsByHotelAsync(int hotelId, string? currency = null)
        {
            var rooms = await _context.Rooms
                .Where(r => r.HotelId == hotelId)
                .ToListAsync();

            var targetCurrency = string.IsNullOrWhiteSpace(currency) ? null : _currency.Normalize(currency);
            return rooms.Select(r => ToRoomDto(r, targetCurrency)).ToList();
        }

        public async Task<RoomDto?> GetRoomByIdAsync(int hotelId, int roomId, string? currency = null)
        {
            var room = await _context.Rooms
                .FirstOrDefaultAsync(r => r.Id == roomId && r.HotelId == hotelId);

            var targetCurrency = string.IsNullOrWhiteSpace(currency) ? null : _currency.Normalize(currency);
            return room is null ? null : ToRoomDto(room, targetCurrency);
        }

        public async Task<RoomDto?> AddRoomAsync(int hotelId, CreateRoomDto dto)
        {
            dto.Currency = _currency.Normalize(dto.Currency, "Room currency");
            // Make sure the hotel exists first
            var hotelExists = await _context.Hotels.AnyAsync(h => h.Id == hotelId);
            if (!hotelExists) return null;

            var room = new Room
            {
                HotelId       = hotelId,
                RoomType      = dto.RoomType,
                Capacity      = dto.Capacity,
                TotalRooms    = dto.TotalRooms,
                PricePerNight = dto.PricePerNight,
                Currency      = dto.Currency
            };

            _context.Rooms.Add(room);
            await _context.SaveChangesAsync();

            return ToRoomDto(room);
        }

        public async Task<bool> UpdateRoomAsync(int hotelId, int roomId, CreateRoomDto dto)
        {
            dto.Currency = _currency.Normalize(dto.Currency, "Room currency");
            var room = await _context.Rooms
                .FirstOrDefaultAsync(r => r.Id == roomId && r.HotelId == hotelId);
            if (room is null) return false;

            room.RoomType      = dto.RoomType;
            room.Capacity      = dto.Capacity;
            room.TotalRooms    = dto.TotalRooms;
            room.PricePerNight = dto.PricePerNight;
            room.Currency      = dto.Currency;

            await _context.SaveChangesAsync();
            return true;
        }

        public async Task<bool> DeleteRoomAsync(int hotelId, int roomId)
        {
            var room = await _context.Rooms
                .FirstOrDefaultAsync(r => r.Id == roomId && r.HotelId == hotelId);
            if (room is null) return false;

            _context.Rooms.Remove(room);   // hard delete — rooms don't have soft delete
            await _context.SaveChangesAsync();
            return true;
        }

        // ══════════════════════════════════════════════════════════════════
        //  MAPPING HELPERS
        // ══════════════════════════════════════════════════════════════════

        /// <summary>
        /// Convert Hotel entity → HotelDto (includes rooms).
        /// </summary>
        private HotelDto ToDto(Hotel h, string? targetCurrency = null) => new HotelDto
        {
            Id            = h.Id,
            DestinationId = h.DestinationId,
            Name          = h.Name,
            Address       = h.Address,
            ContactEmail  = h.ContactEmail,
            ContactPhone  = h.ContactPhone,
            ImageUrl      = h.ImageUrl,
            Latitude      = h.Latitude,
            Longitude     = h.Longitude,
            StarRating    = h.StarRating,
            Status        = h.Status.ToString(),
            Rooms         = h.Rooms?.Select(r => ToRoomDto(r, targetCurrency)).ToList() ?? new List<RoomDto>()
        };

        /// <summary>
        /// Convert Room entity → RoomDto.
        /// </summary>
        private RoomDto ToRoomDto(Room r, string? targetCurrency = null) => new RoomDto
        {
            Id            = r.Id,
            HotelId       = r.HotelId,
            RoomType      = r.RoomType,
            Capacity      = r.Capacity,
            TotalRooms    = r.TotalRooms,
            PricePerNight = targetCurrency == null ? r.PricePerNight : _currency.Convert(r.PricePerNight, r.Currency, targetCurrency),
            Currency      = targetCurrency ?? r.Currency
        };
    }
}
