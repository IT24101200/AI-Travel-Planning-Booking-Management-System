using backend.DTOs;

namespace backend.Services
{
    public interface IPreferenceService
    {
        Task<PreferenceDto?> GetByCustomerIdAsync(string customerId);
        Task<PreferenceDto> CreateOrUpdateAsync(string customerId, PreferenceUpdateDto dto);
    }
}
