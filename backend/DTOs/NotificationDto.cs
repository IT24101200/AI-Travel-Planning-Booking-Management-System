namespace backend.DTOs
{
    /// <summary>
    /// Response DTO for notification data.
    /// </summary>
    public class NotificationDto
    {
        public Guid Id { get; set; }
        public string CustomerId { get; set; } = string.Empty;
        public string Channel { get; set; } = string.Empty;
        public string MessageType { get; set; } = string.Empty;
        public string Content { get; set; } = string.Empty;
        public string Status { get; set; } = string.Empty;
        public DateTime? ReadAt { get; set; }
        public DateTime SentAt { get; set; }
    }
}
