namespace backend.DTOs
{
    /// <summary>
    /// Response DTO for agent execution log entries.
    /// </summary>
    public class AgentLogDto
    {
        public Guid Id { get; set; }
        public Guid TripRequestId { get; set; }
        public string AgentName { get; set; } = string.Empty;
        public string StepName { get; set; } = string.Empty;
        public string? Input { get; set; }
        public string? Output { get; set; }
        public string Status { get; set; } = string.Empty;
        public DateTime Timestamp { get; set; }
    }
}
