using System.ComponentModel.DataAnnotations;

namespace backend.DTOs
{
    /// <summary>
    /// Request DTO for creating a new trip request.
    /// </summary>
    public class TripRequestCreateDto
    {
        public Guid? DestinationId { get; set; }

        [Required(ErrorMessage = "Request text is required.")]
        [MaxLength(2000)]
        public string RawRequestText { get; set; } = string.Empty;

        [Required(ErrorMessage = "Start date is required.")]
        public DateTime StartDate { get; set; }

        [Required(ErrorMessage = "End date is required.")]
        public DateTime EndDate { get; set; }

        [Range(1, 100, ErrorMessage = "Traveller count must be between 1 and 100.")]
        public int TravellerCount { get; set; } = 1;

        [Range(0.01, double.MaxValue, ErrorMessage = "Budget ceiling must be greater than zero.")]
        public decimal BudgetCeiling { get; set; }

        [Required]
        [MaxLength(10)]
        public string Currency { get; set; } = "USD";
    }
}
