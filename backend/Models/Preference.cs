using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace backend.Models
{
    /// <summary>
    /// Travel preferences for a customer. One-to-one with Customer.
    /// </summary>
    public class Preference
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public Guid Id { get; set; }

        /// <summary>
        /// Unique FK — each customer has exactly one preference record.
        /// </summary>
        [Required]
        public string CustomerId { get; set; } = string.Empty;

        [Column(TypeName = "decimal(18,2)")]
        public decimal BudgetMin { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal BudgetMax { get; set; }

        [MaxLength(10)]
        public string Currency { get; set; } = "USD";

        /// <summary>
        /// Comma-separated list of preferred activities (e.g. "hiking,snorkeling,sightseeing").
        /// </summary>
        [MaxLength(500)]
        public string? PreferredActivities { get; set; }

        [MaxLength(500)]
        public string? DietaryNotes { get; set; }

        [MaxLength(500)]
        public string? AccessibilityNotes { get; set; }

        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

        // ── Navigation ──
        [ForeignKey(nameof(CustomerId))]
        public Customer Customer { get; set; } = null!;
    }
}
