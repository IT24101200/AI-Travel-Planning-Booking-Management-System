using System.ComponentModel.DataAnnotations;

namespace backend.DTOs
{
    public class TourDto
    {
        public int Id { get; set; }
        public int DestinationId { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Category { get; set; } = string.Empty;
        public string? Description { get; set; }
        public decimal Price { get; set; }
        public string Currency { get; set; } = string.Empty;
        public double DurationHours { get; set; }
        public TimeSpan DefaultStartTime { get; set; }
        public double? Latitude { get; set; }
        public double? Longitude { get; set; }
        public string Status { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }
    }

    public class CreateTourDto
    {
        [Required(ErrorMessage = "Destination ID is required.")]
        public int DestinationId { get; set; }

        [Required(ErrorMessage = "Tour name is required.")]
        [MaxLength(200, ErrorMessage = "Tour name cannot exceed 200 characters.")]
        public string Name { get; set; } = string.Empty;

        [Required(ErrorMessage = "Category is required.")]
        [MaxLength(50, ErrorMessage = "Category cannot exceed 50 characters.")]
        public string Category { get; set; } = string.Empty;

        [MaxLength(2000, ErrorMessage = "Description cannot exceed 2000 characters.")]
        public string? Description { get; set; }

        [Range(0, 1000000, ErrorMessage = "Price must be greater than or equal to 0.")]
        public decimal Price { get; set; }

        [MaxLength(10, ErrorMessage = "Currency code cannot exceed 10 characters.")]
        public string Currency { get; set; } = "USD";

        [Range(0.1, 240, ErrorMessage = "Duration must be between 0.1 and 240 hours.")]
        public double DurationHours { get; set; }

        public TimeSpan DefaultStartTime { get; set; }

        public double? Latitude { get; set; }
        public double? Longitude { get; set; }

        [MaxLength(20)]
        public string Status { get; set; } = "Active";
    }
}
