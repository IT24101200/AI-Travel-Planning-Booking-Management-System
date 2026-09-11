using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace backend.Models
{
    /// <summary>
    /// Student D — Commercial booking record gating payment and customer fulfillment.
    /// </summary>
    public class Booking
    {
        [Key]
        public int Id { get; set; }

        [Required]
        [MaxLength(50)]
        public string BookingReference { get; set; } = string.Empty;

        [ForeignKey(nameof(Customer))]
        public string CustomerId { get; set; } = string.Empty;
        public Customer Customer { get; set; } = null!;

        [ForeignKey(nameof(Itinerary))]
        public int ItineraryId { get; set; }
        public Itinerary Itinerary { get; set; } = null!;

        [Required]
        [MaxLength(30)]
        public string Status { get; set; } = "AwaitingApproval"; // Draft, AwaitingApproval, Confirmed, Rejected, Cancelled, Completed

        [Column(TypeName = "decimal(18,2)")]
        public decimal TotalCost { get; set; }

        [Required]
        [MaxLength(10)]
        public string Currency { get; set; } = "USD";

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

        // Navigation
        public ICollection<BookingItem> Items { get; set; } = new List<BookingItem>();
        public ICollection<BookingApproval> Approvals { get; set; } = new List<BookingApproval>();
        public Payment? Payment { get; set; }
    }
}
