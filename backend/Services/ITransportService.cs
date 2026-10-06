using backend.DTOs;

namespace backend.Services
{
    /// <summary>
    /// Contract for transport option operations.
    /// </summary>
    public interface ITransportService
    {
        Task<List<TransportOptionDto>> SearchAsync(string? type, string? routeFrom, string? routeTo, decimal? minPrice, decimal? maxPrice, string? status, string? sortBy, bool descending, int page, int pageSize);
        Task<int> GetTotalCountAsync(string? type, string? routeFrom, string? routeTo, decimal? minPrice, decimal? maxPrice, string? status);
        Task<TransportOptionDto?> GetByIdAsync(int id);
        Task<TransportOptionDto> CreateAsync(CreateTransportOptionDto dto);
        Task<bool> UpdateAsync(int id, CreateTransportOptionDto dto);
        Task<bool> SoftDeleteAsync(int id);
    }
}
