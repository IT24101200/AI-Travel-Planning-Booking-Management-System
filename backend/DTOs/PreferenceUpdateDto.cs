using System.ComponentModel.DataAnnotations;

namespace backend.DTOs
{
    /// <summary>
    /// Request DTO for creating or updating preferences.
    /// </summary>
    public class PreferenceUpdateDto
    {
        [Range(0, double.MaxValue, ErrorMessage = "BudgetMin must be non-negative.")]
        public decimal BudgetMin { get; set; }

        [Range(0, double.MaxValue, ErrorMessage = "BudgetMax must be non-negative.")]
        public decimal BudgetMax { get; set; }

        [Required]
        [MaxLength(10)]
        public string Currency { get; set; } = "USD";

        [MaxLength(500)]
        public string? PreferredActivities { get; set; }

        [MaxLength(500)]
        public string? DietaryNotes { get; set; }

        [MaxLength(500)]
        public string? AccessibilityNotes { get; set; }
    }
}
