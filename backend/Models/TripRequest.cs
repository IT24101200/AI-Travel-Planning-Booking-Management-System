using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using backend.Models.Enums;

namespace backend.Models
{
    /// <summary>
    /// A customer's request to plan a trip. Flows through the agentic AI pipeline.
    /// </summary>
    public class TripRequest
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public Guid Id { get; set; }

        [Required]
        public string CustomerId { get; set; } = string.Empty;

        /// <summary>
        /// Optional FK to Destination. Null if not yet resolved.
        /// </summary>
        public Guid? DestinationId { get; set; }

        [Required]
        [MaxLength(2000)]
        public string RawRequestText { get; set; } = string.Empty;

        [Required]
        public DateTime StartDate { get; set; }

        [Required]
        public DateTime EndDate { get; set; }

        [Range(1, 100)]
        public int TravellerCount { get; set; } = 1;

        [Column(TypeName = "decimal(18,2)")]
        public decimal BudgetCeiling { get; set; }

        [MaxLength(10)]
        public string Currency { get; set; } = "USD";

        [Required]
        public TripRequestStatus Status { get; set; } = TripRequestStatus.Pending;

        public int RetryCount { get; set; } = 0;

        /// <summary>
        /// JSON payload produced by the Coordinator Agent. Null until planning completes.
        /// </summary>
        [Column(TypeName = "jsonb")]
        public string? PlanJson { get; set; }

        /// <summary>
        /// Reason for failure if Status == Failed.
        /// </summary>
        [MaxLength(1000)]
        public string? FailureReason { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        // ── Navigation ──
        [ForeignKey(nameof(CustomerId))]
        public Customer Customer { get; set; } = null!;

        [ForeignKey(nameof(DestinationId))]
        public Destination? Destination { get; set; }

        public ICollection<AgentLog> AgentLogs { get; set; } = new List<AgentLog>();
    }
}
