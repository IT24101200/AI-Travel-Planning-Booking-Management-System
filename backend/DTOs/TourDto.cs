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
        public string Status { get; set; } = "Active";
    }
}
