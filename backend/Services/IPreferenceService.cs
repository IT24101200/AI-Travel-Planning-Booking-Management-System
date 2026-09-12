using backend.DTOs;

namespace backend.Services
{
    public interface IPreferenceService
    {
        Task<PreferenceDto?> GetByCustomerIdAsync(string customerId);
        Task<PreferenceDto> CreateOrUpdateAsync(string customerId, PreferenceUpdateDto dto);
        Task<List<PreferenceDto>> SearchAsync(string? customerId, decimal? minBudget, decimal? maxBudget, string? sortBy, bool descending, int page, int pageSize);
    }
}
