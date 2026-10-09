using backend.DTOs;
using backend.Models.Enums;

namespace backend.Services
{
    public interface INotificationService
    {
        Task<List<NotificationDto>> GetByCustomerIdAsync(string? customerId, string? status, DateTime? from, DateTime? to, int page, int pageSize);
        Task<int> GetCountAsync(string? customerId, string? status, DateTime? from, DateTime? to);
        Task<NotificationDto?> GetByIdAsync(Guid notificationId);
        Task<NotificationDto?> MarkAsReadAsync(Guid notificationId, string customerId);
        Task<NotificationDto?> MarkAsUnreadAsync(Guid notificationId, string customerId);
        Task<int> MarkAllAsReadAsync(string customerId);
        Task<NotificationDto?> ResendFailedAsync(Guid notificationId, string? customerId = null);
        Task<NotificationDto> SendNotificationAsync(SendNotificationDto dto);
        Task<NotificationDto> CreateEventNotificationAsync(
            string customerId,
            MessageType messageType,
            string content,
            string referenceType,
            string referenceId,
            string eventKey,
            CancellationToken cancellationToken = default,
            TripConfirmationDto? tripDetails = null);
    }
}
