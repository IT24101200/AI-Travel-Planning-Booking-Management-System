using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace backend.Models
{
    /// <summary>
    /// Student D — Payment record linked to a booking (e.g. Stripe Sandbox).
    /// </summary>
    public class Payment
    {
        [Key]
        public int Id { get; set; }

        [ForeignKey(nameof(Booking))]
        public int BookingId { get; set; }
        public Booking Booking { get; set; } = null!;

        [Column(TypeName = "decimal(18,2)")]
        public decimal Amount { get; set; }

        [Required]
        [MaxLength(10)]
        public string Currency { get; set; } = "USD";

        [Required]
        [MaxLength(30)]
        public string Status { get; set; } = "Pending"; // Pending, Paid, Failed, Refunded

        [MaxLength(120)]
        public string? StripeReference { get; set; }

        public DateTime PaymentDate { get; set; } = DateTime.UtcNow;
    }
}
