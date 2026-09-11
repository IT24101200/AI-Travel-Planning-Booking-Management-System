using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace backend.Models
{
    /// <summary>
    /// Student D — Human-in-the-loop audit record of a travel agent's decision.
    /// </summary>
    public class BookingApproval
    {
        [Key]
        public int Id { get; set; }

        [ForeignKey(nameof(Booking))]
        public int BookingId { get; set; }
        public Booking Booking { get; set; } = null!;

        [ForeignKey(nameof(TravelAgent))]
        public string TravelAgentId { get; set; } = string.Empty;
        public TravelAgent TravelAgent { get; set; } = null!;

        [Required]
        [MaxLength(30)]
        public string Decision { get; set; } = "Approved"; // Approved, Rejected, RevisionRequested

        [MaxLength(1000)]
        public string? Comment { get; set; }

        public DateTime DecidedAt { get; set; } = DateTime.UtcNow;
    }
}
