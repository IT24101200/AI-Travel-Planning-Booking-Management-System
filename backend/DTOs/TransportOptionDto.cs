namespace backend.DTOs
{
    // ── Response DTO ──
    public class TransportOptionDto
    {
        public int Id { get; set; }
        public string Type { get; set; } = string.Empty;
        public string Provider { get; set; } = string.Empty;
        public string RouteFrom { get; set; } = string.Empty;
        public string RouteTo { get; set; } = string.Empty;

        // Map coordinates (null if not set)
        public double? RouteFromLatitude { get; set; }
        public double? RouteFromLongitude { get; set; }
        public double? RouteToLatitude { get; set; }
        public double? RouteToLongitude { get; set; }

        public DateTime DepartureTime { get; set; }
        public DateTime ArrivalTime { get; set; }
        public int Capacity { get; set; }
        public decimal Price { get; set; }
        public string Currency { get; set; } = string.Empty;
        public string Status { get; set; } = string.Empty;
    }

    // ── Input DTO ──
    public class CreateTransportOptionDto
    {
        public string Type { get; set; } = string.Empty;
        public string Provider { get; set; } = string.Empty;
        public string RouteFrom { get; set; } = string.Empty;
        public string RouteTo { get; set; } = string.Empty;
        public double? RouteFromLatitude { get; set; }
        public double? RouteFromLongitude { get; set; }
        public double? RouteToLatitude { get; set; }
        public double? RouteToLongitude { get; set; }
        public DateTime DepartureTime { get; set; }
        public DateTime ArrivalTime { get; set; }
        public int Capacity { get; set; }
        public decimal Price { get; set; }
        public string Currency { get; set; } = "USD";
    }

    // ── Availability response ──
    public class TransportAvailabilityDto
    {
        public int TransportOptionId { get; set; }
        public string Type { get; set; } = string.Empty;
        public string RouteFrom { get; set; } = string.Empty;
        public string RouteTo { get; set; } = string.Empty;
        public int TotalCapacity { get; set; }
        public int BookedSeats { get; set; }
        public int AvailableSeats { get; set; }
        public decimal Price { get; set; }
        public string Currency { get; set; } = string.Empty;
    }
}
