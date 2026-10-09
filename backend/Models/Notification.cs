using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using backend.Models.Enums;

namespace backend.Models
{
    /// <summary>
    /// Notification sent to a customer via a specified channel.
    /// </summary>
    public class Notification
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public Guid Id { get; set; }

        [Required]
        public string CustomerId { get; set; } = string.Empty;

        [Required]
        public NotificationChannel Channel { get; set; }

        [Required]
        public MessageType MessageType { get; set; }

        [Required]
        [MaxLength(2000)]
        public string Content { get; set; } = string.Empty;

        [Column(TypeName = "text")]
        public string? TripDetailsJson { get; set; }

        /// <summary>
        /// The domain entity that a customer can safely navigate to, when one exists.
        /// </summary>
        [MaxLength(50)]
        public string? ReferenceType { get; set; }

        /// <summary>
        /// The string form of the referenced domain entity's key.
        /// </summary>
        [MaxLength(100)]
        public string? ReferenceId { get; set; }

        /// <summary>
        /// Stable business-event identity used to make automatic notifications idempotent.
        /// Manual and legacy notifications intentionally leave this null.
        /// </summary>
        [MaxLength(200)]
        public string? EventKey { get; set; }

        [Required]
        public NotificationStatus Status { get; set; } = NotificationStatus.Pending;

        public DateTime? ReadAt { get; set; }

        public DateTime SentAt { get; set; } = DateTime.UtcNow;

        // ── Navigation ──
        [ForeignKey(nameof(CustomerId))]
        public Customer Customer { get; set; } = null!;
    }
}
