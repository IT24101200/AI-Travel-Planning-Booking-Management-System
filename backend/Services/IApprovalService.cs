using backend.DTOs;

namespace backend.Services
{
    public interface IApprovalService
    {
        Task<ApprovalDto> CreateApprovalAsync(string travelAgentUserId, ApprovalCreateDto dto);
        Task<IEnumerable<ApprovalDto>> GetApprovalsByBookingIdAsync(int bookingId);
        Task<IEnumerable<ApprovalDto>> GetAllApprovalsAsync();
    }
}
