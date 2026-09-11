using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using backend.Models.Enums;

namespace backend.Models
{
    /// <summary>
    /// Sole commercial source of truth for bookings.
    /// </summary>
    public class Booking
    {
        [Key]
        public int Id { get; set; }

        [Required]
        [MaxLength(50)]
        public string BookingReference { get; set; } = string.Empty;

        [Required]
        public string CustomerId { get; set; } = string.Empty;

        [Required]
        public int ItineraryId { get; set; }

        [Required]
        public BookingStatus Status { get; set; } = BookingStatus.Draft;

        [Column(TypeName = "decimal(18,2)")]
        public decimal TotalCost { get; set; }

        [MaxLength(10)]
        public string Currency { get; set; } = "USD";

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

        // ── Navigation Properties ──
        [ForeignKey(nameof(CustomerId))]
        public Customer Customer { get; set; } = null!;

        [ForeignKey(nameof(ItineraryId))]
        public Itinerary Itinerary { get; set; } = null!;

        public ICollection<BookingItem> BookingItems { get; set; } = new List<BookingItem>();
        public ICollection<BookingApproval> BookingApprovals { get; set; } = new List<BookingApproval>();
        public ICollection<Payment> Payments { get; set; } = new List<Payment>();
    }
}
