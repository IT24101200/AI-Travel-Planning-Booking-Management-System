using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace backend.Models
{
    /// <summary>
    /// Student C — Scheduled transit service (train, chauffeur car, express bus, flight).
    /// </summary>
    public class TransportOption
    {
        [Key]
        public int Id { get; set; }

        [Required]
        [MaxLength(30)]
        public string Type { get; set; } = "Train"; // Train, Car, Bus, Flight

        [Required]
        [MaxLength(120)]
        public string Provider { get; set; } = string.Empty;

        [Required]
        [MaxLength(100)]
        public string RouteFrom { get; set; } = string.Empty;

        [Required]
        [MaxLength(100)]
        public string RouteTo { get; set; } = string.Empty;

        public TimeSpan DepartureTime { get; set; }

        public TimeSpan ArrivalTime { get; set; }

        public int Capacity { get; set; } = 40;

        [Column(TypeName = "decimal(18,2)")]
        public decimal Price { get; set; }

        [Required]
        [MaxLength(10)]
        public string Currency { get; set; } = "USD";

        [Required]
        [MaxLength(20)]
        public string Status { get; set; } = "Active";
    }
}
