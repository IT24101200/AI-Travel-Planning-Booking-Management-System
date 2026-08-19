using backend.DTOs;

namespace backend.Services
{
    public interface ITripRequestService
    {
        Task<TripRequestDto> CreateAsync(string customerId, TripRequestCreateDto dto);
        Task<List<TripRequestDto>> GetByCustomerIdAsync(string customerId, int page, int pageSize);
        Task<int> GetCountByCustomerIdAsync(string customerId);
        Task<TripRequestDto?> GetByIdAsync(int tripRequestId);
        Task<TripRequestDto?> GetStatusAsync(int tripRequestId, string customerId);
        Task<TripRequestDto?> CancelAsync(int tripRequestId, string customerId);
        Task<List<AgentLogDto>> GetAgentLogsAsync(int tripRequestId, string customerId);
    }
}
