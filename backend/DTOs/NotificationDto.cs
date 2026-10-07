using System.ComponentModel.DataAnnotations;

namespace backend.DTOs
{
    /// <summary>
    /// Response DTO for notification data.
    /// </summary>
    public class NotificationDto
    {
        public Guid Id { get; set; }
        public string CustomerId { get; set; } = string.Empty;
        public string CustomerName { get; set; } = string.Empty;
        public string CustomerEmail { get; set; } = string.Empty;
        public string? CustomerPhone { get; set; }
        public string Recipient { get; set; } = string.Empty;
        public string Channel { get; set; } = string.Empty;
        public string MessageType { get; set; } = string.Empty;
        public string Content { get; set; } = string.Empty;
        public string? ReferenceType { get; set; }
        public string? ReferenceId { get; set; }
        public string? EventKey { get; set; }
        public string Status { get; set; } = string.Empty;
        public DateTime? ReadAt { get; set; }
        public DateTime SentAt { get; set; }
    }

    /// <summary>
    /// Request body for sending a new notification to a customer.
    /// Channel: Email, SMS, Push, InApp
    /// MessageType: existing manual values plus automatic business-event values.
    /// </summary>
    public class SendNotificationDto
    {
        [Required]
        public string CustomerId { get; set; } = string.Empty;

        [Required]
        public string Channel { get; set; } = "InApp";

        [Required]
        public string MessageType { get; set; } = "SystemAlert";

        [Required]
        [MaxLength(2000)]
        public string Content { get; set; } = string.Empty;
    }
}

