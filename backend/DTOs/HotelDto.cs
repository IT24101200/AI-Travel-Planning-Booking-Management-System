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
        public int DestinationId { get; set; }
        public string Name { get; set; } = string.Empty;
        public string? Address { get; set; }
        public double Latitude { get; set; }
        public double Longitude { get; set; }
        public int StarRating { get; set; }
    }
}
