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
            string? customerId, string? status, DateTime? from, DateTime? to, int page, int pageSize)
        {
            var query = _db.Notifications
                .Include(n => n.Customer)
                .AsQueryable();

            if (!string.IsNullOrWhiteSpace(customerId))
            {
                query = query.Where(n => n.CustomerId == customerId);
            }
            else
            {
                // In staff outbox: show only notifications belonging to Customers
                query = query.Where(n => n.Customer.Role == "Customer" || string.IsNullOrEmpty(n.Customer.Role));
            }

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

            var notifications = await query
                .OrderByDescending(n => n.SentAt)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync();

            // Fetch user emails for all matching customer IDs
            var customerIds = notifications.Select(n => n.CustomerId).Distinct().ToList();
            var userEmails = await _db.Users
                .Where(u => customerIds.Contains(u.Id))
                .ToDictionaryAsync(u => u.Id, u => u.Email ?? "");

            return notifications
                .Select(n => MapToDto(n, userEmails.GetValueOrDefault(n.CustomerId, "")))
                .ToList();
        }

        public async Task<int> GetCountAsync(string? customerId, string? status, DateTime? from, DateTime? to)
        {
            var query = _db.Notifications.AsQueryable();

            if (!string.IsNullOrWhiteSpace(customerId))
            {
                query = query.Where(n => n.CustomerId == customerId);
            }
            else
            {
                query = query.Where(n => n.Customer.Role == "Customer" || string.IsNullOrEmpty(n.Customer.Role));
            }

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
            var n = await _db.Notifications
                .Include(n => n.Customer)
                .FirstOrDefaultAsync(n => n.Id == notificationId);
            if (n == null) return null;

            var user = await _db.Users.FirstOrDefaultAsync(u => u.Id == n.CustomerId);
            return MapToDto(n, user?.Email ?? "");
        }

        public async Task<NotificationDto?> MarkAsReadAsync(Guid notificationId, string customerId)
        {
            var notification = await _db.Notifications
                .Include(n => n.Customer)
                .FirstOrDefaultAsync(n => n.Id == notificationId && n.CustomerId == customerId);

            if (notification == null) return null;

            notification.Status = NotificationStatus.Read;
            notification.ReadAt = DateTime.UtcNow;
            await _db.SaveChangesAsync();

            var user = await _db.Users.FirstOrDefaultAsync(u => u.Id == notification.CustomerId);
            return MapToDto(notification, user?.Email ?? "");
        }

        public async Task<NotificationDto?> MarkAsUnreadAsync(Guid notificationId, string customerId)
        {
            var notification = await _db.Notifications
                .Include(n => n.Customer)
                .FirstOrDefaultAsync(n => n.Id == notificationId && n.CustomerId == customerId);

            if (notification == null) return null;

            notification.Status = NotificationStatus.Sent;
            notification.ReadAt = null;
            await _db.SaveChangesAsync();

            var user = await _db.Users.FirstOrDefaultAsync(u => u.Id == notification.CustomerId);
            return MapToDto(notification, user?.Email ?? "");
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

        public async Task<NotificationDto?> ResendFailedAsync(Guid notificationId, string? customerId = null)
        {
            var query = _db.Notifications
                .Include(n => n.Customer)
                .AsQueryable();
            if (!string.IsNullOrEmpty(customerId))
            {
                query = query.Where(n => n.CustomerId == customerId);
            }

            var notification = await query.FirstOrDefaultAsync(n => n.Id == notificationId);
            if (notification == null) return null;

            // Reset to Sent for re-delivery
            notification.Status = NotificationStatus.Sent;
            notification.SentAt = DateTime.UtcNow;
            await _db.SaveChangesAsync();

            var user = await _db.Users.FirstOrDefaultAsync(u => u.Id == notification.CustomerId);
            return MapToDto(notification, user?.Email ?? "");
        }

        public async Task<NotificationDto> SendNotificationAsync(SendNotificationDto dto)
        {
            // Validate customer exists
            var customer = await _db.Customers.FirstOrDefaultAsync(c => c.Id == dto.CustomerId);
            if (customer == null)
                throw new KeyNotFoundException($"Customer with ID '{dto.CustomerId}' not found.");

            // Parse Channel enum from string
            if (!Enum.TryParse<NotificationChannel>(dto.Channel, true, out var channel))
                throw new ArgumentException($"Invalid channel '{dto.Channel}'. Valid values: Email, SMS, Push, InApp.");

            // Parse MessageType enum from string
            if (!Enum.TryParse<MessageType>(dto.MessageType, true, out var messageType))
                throw new ArgumentException($"Invalid messageType '{dto.MessageType}'. Valid values: TripUpdate, BookingConfirmation, PaymentReceipt, SystemAlert, Promotion, Reminder.");

            var notification = new Notification
            {
                CustomerId  = dto.CustomerId,
                Channel     = channel,
                MessageType = messageType,
                Content     = dto.Content,
                Status      = NotificationStatus.Sent,
                SentAt      = DateTime.UtcNow
            };

            _db.Notifications.Add(notification);
            await _db.SaveChangesAsync();

            notification.Customer = customer;
            var user = await _db.Users.FirstOrDefaultAsync(u => u.Id == dto.CustomerId);

            return MapToDto(notification, user?.Email ?? "");
        }

        private static NotificationDto MapToDto(Notification n, string userEmail = "")
        {
            var customerName = n.Customer?.FullName ?? "Customer";
            var customerPhone = n.Customer?.Phone;

            string recipient;
            if (n.Channel == NotificationChannel.SMS)
            {
                recipient = !string.IsNullOrWhiteSpace(customerPhone)
                    ? customerPhone
                    : (!string.IsNullOrWhiteSpace(userEmail) ? userEmail : customerName);
            }
            else
            {
                recipient = !string.IsNullOrWhiteSpace(userEmail)
                    ? userEmail
                    : (!string.IsNullOrWhiteSpace(customerPhone) ? customerPhone : customerName);
            }

            return new NotificationDto
            {
                Id = n.Id,
                CustomerId = n.CustomerId,
                CustomerName = customerName,
                CustomerEmail = userEmail,
                CustomerPhone = customerPhone,
                Recipient = recipient,
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
