namespace backend.DTOs
{
    /// <summary>
    /// Response DTO for customer profile data.
    /// </summary>
    public class CustomerDto
    {
        public string Id { get; set; } = string.Empty;
        public string FullName { get; set; } = string.Empty;
        public string? Phone { get; set; }
        public string Email { get; set; } = string.Empty;
        public string Role { get; set; } = "Customer";
        public string? Department { get; set; }
        public int TripCount { get; set; }
        public DateTime JoinedAt { get; set; }
        public DateTime LastActiveAt { get; set; }
        public bool HasPreference { get; set; }

        // Travel Preference Details
        public decimal? BudgetMin { get; set; }
        public decimal? BudgetMax { get; set; }
        public string? Currency { get; set; }
        public string? PreferredActivities { get; set; }
        public string? DietaryNotes { get; set; }
        public string? AccessibilityNotes { get; set; }
        public PreferenceDto? Preference { get; set; }
    }
}
