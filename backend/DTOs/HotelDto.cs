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

        public double Latitude { get; set; }
        public double Longitude { get; set; }

        [Range(1, 5, ErrorMessage = "Star rating must be between 1 and 5.")]
        public int StarRating { get; set; }
    }
}
