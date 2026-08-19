using backend.DTOs;

namespace backend.Services
{
    public interface ITripRequestService
    {
        Task<TripRequestDto> CreateAsync(string customerId, TripRequestCreateDto dto);
        Task<List<TripRequestDto>> GetByCustomerIdAsync(string customerId, int page, int pageSize);
        Task<int> GetCountByCustomerIdAsync(string customerId);
        Task<TripRequestDto?> GetByIdAsync(Guid tripRequestId);
        Task<TripRequestDto?> GetStatusAsync(Guid tripRequestId, string customerId);
        Task<TripRequestDto?> CancelAsync(Guid tripRequestId, string customerId);
        Task<List<AgentLogDto>> GetAgentLogsAsync(Guid tripRequestId, string customerId);
    }
}
