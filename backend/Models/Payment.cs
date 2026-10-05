using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using backend.Models.Enums;

namespace backend.Models
{
    public class Payment
    {
        [Key]
        public int Id { get; set; }

        [Required]
        public int BookingId { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal Amount { get; set; }

        [MaxLength(10)]
        public string Currency { get; set; } = "LKR";

        [Column(TypeName = "decimal(18,6)")]
        public decimal ExchangeRateToLkr { get; set; } = 1m;

        [Required]
        public PaymentStatus Status { get; set; } = PaymentStatus.Pending;

        [MaxLength(100)]
        public string? StripeReference { get; set; }

        [MaxLength(120)]
        public string? IdempotencyKey { get; set; }

        [MaxLength(500)]
        public string? FailureReason { get; set; }

        public DateTime PaymentDate { get; set; } = DateTime.UtcNow;

        // ── Navigation Properties ──
        [ForeignKey(nameof(BookingId))]
        public Booking Booking { get; set; } = null!;
    }
}
