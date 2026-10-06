using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace backend.Models
{
    /// <summary>
    /// One tour scheduled on a specific day within an Itinerary.
    /// </summary>
    public class ItineraryItem
    {
        [Key]
        public int Id { get; set; }

        [Required]
        public int ItineraryId { get; set; }

        [Required]
        public int TourId { get; set; }

        [Required]
        public int DayNumber { get; set; }

        [Required]
        public int SequenceOrder { get; set; }

        [Required]
        public TimeSpan StartTime { get; set; }

        [Required]
        public TimeSpan EndTime { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal PriceAtSelection { get; set; }

        // ── Navigation ──
        [ForeignKey(nameof(ItineraryId))]
        public Itinerary Itinerary { get; set; } = null!;

        [ForeignKey(nameof(TourId))]
        public Tour Tour { get; set; } = null!;
    }
}
