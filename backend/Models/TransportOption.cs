using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using backend.Models.Enums;

namespace backend.Models
{
    /// <summary>
    /// A single transport option — e.g. one specific flight on a specific date.
    /// Spec says: "one row per dated departure — a stated, deliberate simplification."
    /// 
    /// Example: Flight by SriLankan Airlines, Colombo → Kandy, 10 Sep 2026 08:00–09:30,
    ///          40 seats, LKR 5000.
    /// </summary>
    public class TransportOption
    {
        [Key]
        public int Id { get; set; }

        // ── What kind of transport ──
        [Required]
        public TransportType Type { get; set; }

        /// <summary>
        /// The company operating this transport (e.g. "SriLankan Airlines", "SLTB").
        /// </summary>
        [Required]
        [MaxLength(150)]
        public string Provider { get; set; } = string.Empty;

        // ── Route: where it goes from/to ──
        [Required]
        [MaxLength(200)]
        public string RouteFrom { get; set; } = string.Empty;

        [Required]
        [MaxLength(200)]
        public string RouteTo { get; set; } = string.Empty;

        // ── Coordinates for the Trip Map (nullable — not every entry needs them) ──
        public double? RouteFromLatitude { get; set; }
        public double? RouteFromLongitude { get; set; }
        public double? RouteToLatitude { get; set; }
        public double? RouteToLongitude { get; set; }

        // ── Schedule: exact date and time of departure/arrival ──
        [Required]
        public DateTime DepartureTime { get; set; }

        [Required]
        public DateTime ArrivalTime { get; set; }

        /// <summary>
        /// Total number of seats/capacity available on this departure.
        /// </summary>
        [Range(1, 1000)]
        public int Capacity { get; set; }

        /// <summary>
        /// Price per seat/ticket.
        /// </summary>
        [Column(TypeName = "decimal(18,2)")]
        public decimal Price { get; set; }

        [Required]
        [MaxLength(10)]
        public string Currency { get; set; } = "USD";

        // ── Soft delete ──
        [Required]
        public TransportStatus Status { get; set; } = TransportStatus.Active;
    }
}
