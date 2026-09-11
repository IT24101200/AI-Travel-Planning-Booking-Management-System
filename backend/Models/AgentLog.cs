using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace backend.Models
{
    /// <summary>
    /// Audit log entry written by an agentic AI agent during trip planning.
    /// </summary>
    public class AgentLog
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public Guid Id { get; set; }

        [Required]
        public int TripRequestId { get; set; }

        [Required]
        [MaxLength(100)]
        public string AgentName { get; set; } = string.Empty;

        [Required]
        [MaxLength(100)]
        public string StepName { get; set; } = string.Empty;

        [MaxLength(50)]
        public string? StepType { get; set; }

        [MaxLength(100)]
        public string? ToolName { get; set; }

        public long? DurationMs { get; set; }

        [MaxLength(4000)]
        public string? Input { get; set; }

        [MaxLength(4000)]
        public string? Output { get; set; }

        [Required]
        [MaxLength(50)]
        public string Status { get; set; } = "Started";

        public DateTime Timestamp { get; set; } = DateTime.UtcNow;

        // ── Navigation ──
        [ForeignKey(nameof(TripRequestId))]
        public TripRequest TripRequest { get; set; } = null!;
    }
}
