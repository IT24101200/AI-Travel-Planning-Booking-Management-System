using System.Text.Json;

namespace backend.DTOs
{
    /// <summary>
    /// Payload sent by the Python agent service to update a TripRequest after planning.
    /// </summary>
    public class TripRequestAgentUpdateDto
    {
        public string? Status { get; set; }
        public JsonElement? PlanJson { get; set; }
        public int? RetryCount { get; set; }
        public string? FailureReason { get; set; }
    }
}
