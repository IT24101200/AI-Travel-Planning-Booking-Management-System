using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using backend.Models.Enums;

namespace backend.Models
{
    /// <summary>
    /// Permanent audit record of a human travel agent decision.
    /// Rows are immutable — never updated or deleted.
    /// </summary>
    public class BookingApproval
    {
        [Key]
        public int Id { get; set; }

        [Required]
        public int BookingId { get; set; }

        [Required]
        public string TravelAgentId { get; set; } = string.Empty;

        [Required]
        public ApprovalDecision Decision { get; set; }

        [MaxLength(1000)]
        public string Comment { get; set; } = string.Empty;

        public DateTime DecidedAt { get; set; } = DateTime.UtcNow;

        // ── Navigation Properties ──
        [ForeignKey(nameof(BookingId))]
        public Booking Booking { get; set; } = null!;

        [ForeignKey(nameof(TravelAgentId))]
        public TravelAgent TravelAgent { get; set; } = null!;
    }
}
