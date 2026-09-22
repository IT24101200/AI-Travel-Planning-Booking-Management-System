using System.ComponentModel.DataAnnotations;

namespace backend.DTOs
{
    /// <summary>
    /// Payload sent by the Python agent service to log an execution step.
    /// </summary>
    public class AgentLogCreateDto
    {
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

        [MaxLength(50)]
        public string Status { get; set; } = "Started";

        public DateTime? Timestamp { get; set; }
    }
}
