using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace backend.Models
{
    /// <summary>
    /// Student B — Multi-day itinerary assembled for a trip request.
    /// </summary>
    public class Itinerary
    {
        [Key]
        public int Id { get; set; }

        [ForeignKey(nameof(Customer))]
        public string CustomerId { get; set; } = string.Empty;
        public Customer Customer { get; set; } = null!;

        [ForeignKey(nameof(TripRequest))]
        public int TripRequestId { get; set; }
        public TripRequest TripRequest { get; set; } = null!;

        public DateTime StartDate { get; set; }

        public DateTime EndDate { get; set; }

        [Required]
        [MaxLength(30)]
        public string Status { get; set; } = "Proposed"; // Draft, Proposed, Accepted, Discarded

        [Column(TypeName = "decimal(18,2)")]
        public decimal TotalEstimatedCost { get; set; }

        [Required]
        [MaxLength(10)]
        public string Currency { get; set; } = "USD";

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        // Navigation
        public ICollection<ItineraryItem> Items { get; set; } = new List<ItineraryItem>();
        public Booking? Booking { get; set; }
    }
}
