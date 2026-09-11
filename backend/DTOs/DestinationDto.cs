using System.ComponentModel.DataAnnotations;

namespace backend.DTOs
{
    public class DestinationDto
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Country { get; set; } = string.Empty;
        public string? Description { get; set; }
        public string? ImageUrl { get; set; }
        public double Latitude { get; set; }
        public double Longitude { get; set; }
    }

    public class CreateDestinationDto
    {
        [Required(ErrorMessage = "Destination name is required.")]
        [MaxLength(200, ErrorMessage = "Destination name cannot exceed 200 characters.")]
        public string Name { get; set; } = string.Empty;

        [Required(ErrorMessage = "Country is required.")]
        [MaxLength(100, ErrorMessage = "Country cannot exceed 100 characters.")]
        public string Country { get; set; } = string.Empty;

        [MaxLength(2000, ErrorMessage = "Description cannot exceed 2000 characters.")]
        public string? Description { get; set; }

        [MaxLength(500, ErrorMessage = "Image URL cannot exceed 500 characters.")]
        public string? ImageUrl { get; set; }

        public double Latitude { get; set; }
        public double Longitude { get; set; }
    }
}
