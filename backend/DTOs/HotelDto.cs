using System.ComponentModel.DataAnnotations;

namespace backend.DTOs
{
    // ── Response DTO — what the API sends back ──
    public class HotelDto
    {
        public int Id { get; set; }
        public int DestinationId { get; set; }
        public string Name { get; set; } = string.Empty;
        public string? Address { get; set; }
        public string? ContactEmail { get; set; }
        public string? ContactPhone { get; set; }
        public string? ImageUrl { get; set; }
        public double Latitude { get; set; }
        public double Longitude { get; set; }
        public int StarRating { get; set; }
        public string Status { get; set; } = string.Empty;

        /// <summary>
        /// Rooms are included when fetching a single hotel by ID.
        /// </summary>
        public List<RoomDto> Rooms { get; set; } = new();
    }

    // ── Input DTO — what the client sends to create a hotel ──
    public class CreateHotelDto
    {
        [Required(ErrorMessage = "Destination ID is required.")]
        public int DestinationId { get; set; }

        [Required(ErrorMessage = "Hotel name is required.")]
        [MaxLength(200, ErrorMessage = "Hotel name cannot exceed 200 characters.")]
        public string Name { get; set; } = string.Empty;

        [MaxLength(500, ErrorMessage = "Address cannot exceed 500 characters.")]
        public string? Address { get; set; }

        [MaxLength(254, ErrorMessage = "Contact email cannot exceed 254 characters.")]
        [EmailAddress(ErrorMessage = "Contact email must be a valid email address.")]
        public string? ContactEmail { get; set; }

        [MaxLength(30, ErrorMessage = "Contact phone cannot exceed 30 characters.")]
        [RegularExpression(@"^\+?[0-9][0-9\s().-]{6,24}$", ErrorMessage = "Contact phone must be a valid phone number.")]
        public string? ContactPhone { get; set; }

        [MaxLength(500, ErrorMessage = "Image URL cannot exceed 500 characters.")]
        public string? ImageUrl { get; set; }

        public double Latitude { get; set; }
        public double Longitude { get; set; }

        [Range(0, 5, ErrorMessage = "Star rating must be between 0 (unclassified) and 5.")]
        public int StarRating { get; set; }

        public string Status { get; set; } = "Active";
    }
}
