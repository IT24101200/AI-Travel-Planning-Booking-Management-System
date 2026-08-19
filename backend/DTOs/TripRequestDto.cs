namespace backend.DTOs
{
    /// <summary>
    /// Response DTO for trip request data.
    /// </summary>
    public class TripRequestDto
    {
        public int Id { get; set; }
        public string CustomerId { get; set; } = string.Empty;
        public int? DestinationId { get; set; }
        public string? DestinationName { get; set; }
        public string RawRequestText { get; set; } = string.Empty;
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public int TravellerCount { get; set; }
        public decimal BudgetCeiling { get; set; }
        public string Currency { get; set; } = string.Empty;
        public string Status { get; set; } = string.Empty;
        public int RetryCount { get; set; }
        public string? PlanJson { get; set; }
        public string? FailureReason { get; set; }
        public DateTime CreatedAt { get; set; }
    }
}
