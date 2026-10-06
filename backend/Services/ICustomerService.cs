using backend.DTOs;

namespace backend.Services
{
    public interface ICustomerService
    {
        Task<CustomerDto?> GetByIdAsync(string customerId);
        Task<List<CustomerDto>> GetAllAsync(string? search, string? sortBy, bool descending, int page, int pageSize);
        Task<int> GetTotalCountAsync(string? search);
        Task<CustomerDto?> UpdateAsync(string customerId, CustomerUpdateDto dto);
        Task<bool> ExistsAsync(string customerId);
        Task UpdateLastActiveAsync(string customerId);
    }
}
