using backend.DTOs;

namespace backend.Services
{
    /// <summary>
    /// Contract for hotel and room operations.
    /// 
    /// Why an interface? It lets us swap the real service for a fake one in tests,
    /// and it's the pattern Student A used (ICustomerService). Clean separation.
    /// </summary>
    public interface IHotelService
    {
        // ── Hotel CRUD ──
        Task<List<HotelDto>> GetAllAsync(string? search, int? destinationId, int? minStarRating, string? status, string? sortBy, bool descending, int page, int pageSize, string? currency = null);
        Task<int> GetTotalCountAsync(string? search, int? destinationId, int? minStarRating, string? status);
        Task<HotelDto?> GetByIdAsync(int id, string? currency = null);
        Task<HotelDto> CreateAsync(CreateHotelDto dto);
        Task<bool> UpdateAsync(int id, CreateHotelDto dto);
        Task<bool> SoftDeleteAsync(int id);

        // ── Room CRUD (nested under a hotel) ──
        Task<List<RoomDto>> GetRoomsByHotelAsync(int hotelId, string? currency = null);
        Task<RoomDto?> GetRoomByIdAsync(int hotelId, int roomId, string? currency = null);
        Task<RoomDto?> AddRoomAsync(int hotelId, CreateRoomDto dto);
        Task<bool> UpdateRoomAsync(int hotelId, int roomId, CreateRoomDto dto);
        Task<bool> DeleteRoomAsync(int hotelId, int roomId);

        // ── Room Search ──
        Task<List<RoomDto>> SearchRoomsAsync(string? roomType, int? minCapacity, decimal? maxPrice, string? sortBy, bool descending, int page, int pageSize, string? currency = null);
    }
}
