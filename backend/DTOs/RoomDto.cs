using System.ComponentModel.DataAnnotations;

namespace backend.DTOs
{
    // ── Response DTO ──
    public class RoomDto
    {
        public int Id { get; set; }
        public int HotelId { get; set; }
        public string RoomType { get; set; } = string.Empty;
        public int Capacity { get; set; }
        public int TotalRooms { get; set; }
        public decimal PricePerNight { get; set; }
        public string Currency { get; set; } = string.Empty;
    }

    // ── Input DTO — HotelId comes from the URL, not the body ──
    public class CreateRoomDto
    {
        [Required(ErrorMessage = "Room type is required.")]
        [MaxLength(50, ErrorMessage = "Room type cannot exceed 50 characters.")]
        public string RoomType { get; set; } = string.Empty;

        [Range(1, 20, ErrorMessage = "Capacity must be between 1 and 20 guests.")]
        public int Capacity { get; set; }

        [Range(1, 1000, ErrorMessage = "Total rooms must be at least 1.")]
        public int TotalRooms { get; set; }

        [Range(0, 1000000, ErrorMessage = "Price per night must be greater than or equal to 0.")]
        public decimal PricePerNight { get; set; }

        [MaxLength(10, ErrorMessage = "Currency code cannot exceed 10 characters.")]
        public string Currency { get; set; } = "USD";
    }

    // ── Availability response — returned by the availability endpoint ──
    public class RoomAvailabilityDto
    {
        public int RoomId { get; set; }
        public string RoomType { get; set; } = string.Empty;
        public int TotalRooms { get; set; }
        public int BookedRooms { get; set; }
        public int AvailableRooms { get; set; }
        public decimal PricePerNight { get; set; }
        public string Currency { get; set; } = string.Empty;
    }
}
