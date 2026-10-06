namespace backend.DTOs
{
    /// <summary>
    /// Response DTO for customer preferences.
    /// </summary>
    public class PreferenceDto
    {
        public Guid Id { get; set; }
        public string CustomerId { get; set; } = string.Empty;
        public decimal BudgetMin { get; set; }
        public decimal BudgetMax { get; set; }
        public string Currency { get; set; } = "USD";
        public string? PreferredActivities { get; set; }
        public string? DietaryNotes { get; set; }
        public string? AccessibilityNotes { get; set; }
        public DateTime UpdatedAt { get; set; }
    }
}
