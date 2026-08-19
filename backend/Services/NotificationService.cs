using backend.Data;
using backend.DTOs;
using backend.Models;
using backend.Models.Enums;
using Microsoft.EntityFrameworkCore;

namespace backend.Services
{
    public class NotificationService : INotificationService
    {
        private readonly AppDbContext _db;

        public NotificationService(AppDbContext db)
        {
            _db = db;
        }

        public async Task<List<NotificationDto>> GetByCustomerIdAsync(
            string customerId, string? status, DateTime? from, DateTime? to, int page, int pageSize)
        {
            var query = _db.Notifications
                .Where(n => n.CustomerId == customerId)
                .AsQueryable();

            // Filter by status
            if (!string.IsNullOrWhiteSpace(status) && Enum.TryParse<NotificationStatus>(status, true, out var parsed))
            {
                query = query.Where(n => n.Status == parsed);
            }

            // Filter by date range
            if (from.HasValue)
            {
                query = query.Where(n => n.SentAt >= from.Value);
            }
            if (to.HasValue)
            {
                query = query.Where(n => n.SentAt <= to.Value);
            }

            return await query
                .OrderByDescending(n => n.SentAt)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(n => MapToDto(n))
                .ToListAsync();
        }

        public async Task<int> GetCountAsync(string customerId, string? status, DateTime? from, DateTime? to)
        {
            var query = _db.Notifications
                .Where(n => n.CustomerId == customerId)
                .AsQueryable();

            if (!string.IsNullOrWhiteSpace(status) && Enum.TryParse<NotificationStatus>(status, true, out var parsed))
            {
                query = query.Where(n => n.Status == parsed);
            }

            if (from.HasValue)
                query = query.Where(n => n.SentAt >= from.Value);
            if (to.HasValue)
                query = query.Where(n => n.SentAt <= to.Value);

            return await query.CountAsync();
        }

        public async Task<NotificationDto?> GetByIdAsync(Guid notificationId)
        {
            var n = await _db.Notifications.FindAsync(notificationId);
            return n == null ? null : MapToDto(n);
        }

        public async Task<NotificationDto?> MarkAsReadAsync(Guid notificationId, string customerId)
        {
            var notification = await _db.Notifications
                .FirstOrDefaultAsync(n => n.Id == notificationId && n.CustomerId == customerId);

            if (notification == null) return null;

            notification.Status = NotificationStatus.Read;
            notification.ReadAt = DateTime.UtcNow;
            await _db.SaveChangesAsync();

            return MapToDto(notification);
        }

        public async Task<NotificationDto?> MarkAsUnreadAsync(Guid notificationId, string customerId)
        {
            var notification = await _db.Notifications
                .FirstOrDefaultAsync(n => n.Id == notificationId && n.CustomerId == customerId);

            if (notification == null) return null;

            notification.Status = NotificationStatus.Sent;
            notification.ReadAt = null;
            await _db.SaveChangesAsync();

            return MapToDto(notification);
        }

        public async Task<int> MarkAllAsReadAsync(string customerId)
        {
            var unread = await _db.Notifications
                .Where(n => n.CustomerId == customerId && n.Status != NotificationStatus.Read)
                .ToListAsync();

            foreach (var n in unread)
            {
                n.Status = NotificationStatus.Read;
                n.ReadAt = DateTime.UtcNow;
            }

            await _db.SaveChangesAsync();
            return unread.Count;
        }

        public async Task<NotificationDto?> ResendFailedAsync(Guid notificationId, string customerId)
        {
            var notification = await _db.Notifications
                .FirstOrDefaultAsync(n => n.Id == notificationId && n.CustomerId == customerId);

            if (notification == null) return null;

            if (notification.Status != NotificationStatus.Failed)
            {
                throw new InvalidOperationException("Only failed notifications can be resent.");
            }

            // Reset to Pending for re-delivery
            notification.Status = NotificationStatus.Pending;
            notification.SentAt = DateTime.UtcNow;
            await _db.SaveChangesAsync();

            return MapToDto(notification);
        }

        private static NotificationDto MapToDto(Notification n)
        {
            return new NotificationDto
            {
                Id = n.Id,
                CustomerId = n.CustomerId,
                Channel = n.Channel.ToString(),
                MessageType = n.MessageType.ToString(),
                Content = n.Content,
                Status = n.Status.ToString(),
                ReadAt = n.ReadAt,
                SentAt = n.SentAt
            };
        }
    }
}
