using backend.DTOs;

namespace backend.Services
{
    public interface INotificationService
    {
        Task<List<NotificationDto>> GetByCustomerIdAsync(string customerId, string? status, DateTime? from, DateTime? to, int page, int pageSize);
        Task<int> GetCountAsync(string customerId, string? status, DateTime? from, DateTime? to);
        Task<NotificationDto?> GetByIdAsync(Guid notificationId);
        Task<NotificationDto?> MarkAsReadAsync(Guid notificationId, string customerId);
        Task<NotificationDto?> MarkAsUnreadAsync(Guid notificationId, string customerId);
        Task<int> MarkAllAsReadAsync(string customerId);
        Task<NotificationDto?> ResendFailedAsync(Guid notificationId, string customerId);
    }
}
