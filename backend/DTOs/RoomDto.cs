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
        public string RoomType { get; set; } = string.Empty;
        public int Capacity { get; set; }
        public int TotalRooms { get; set; }
        public decimal PricePerNight { get; set; }
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
