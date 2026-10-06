using System.ComponentModel.DataAnnotations;

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
        [Required(ErrorMessage = "Transport type is required (e.g., Bus, Train, Flight).")]
        [MaxLength(50, ErrorMessage = "Type cannot exceed 50 characters.")]
        public string Type { get; set; } = string.Empty;

        [Required(ErrorMessage = "Provider name is required.")]
        [MaxLength(150, ErrorMessage = "Provider cannot exceed 150 characters.")]
        public string Provider { get; set; } = string.Empty;

        [Required(ErrorMessage = "Origin route (RouteFrom) is required.")]
        [MaxLength(200, ErrorMessage = "RouteFrom cannot exceed 200 characters.")]
        public string RouteFrom { get; set; } = string.Empty;

        [Required(ErrorMessage = "Destination route (RouteTo) is required.")]
        [MaxLength(200, ErrorMessage = "RouteTo cannot exceed 200 characters.")]
        public string RouteTo { get; set; } = string.Empty;

        public double? RouteFromLatitude { get; set; }
        public double? RouteFromLongitude { get; set; }
        public double? RouteToLatitude { get; set; }
        public double? RouteToLongitude { get; set; }

        [Required(ErrorMessage = "Departure time is required.")]
        public DateTime DepartureTime { get; set; }

        [Required(ErrorMessage = "Arrival time is required.")]
        public DateTime ArrivalTime { get; set; }

        [Range(1, 2000, ErrorMessage = "Capacity must be at least 1.")]
        public int Capacity { get; set; }

        [Range(0, 1000000, ErrorMessage = "Price must be greater than or equal to 0.")]
        public decimal Price { get; set; }

        [MaxLength(10, ErrorMessage = "Currency code cannot exceed 10 characters.")]
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
