using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace backend.Models
{
    /// <summary>
    /// Student B — Individual scheduled activity within an itinerary day.
    /// </summary>
    public class ItineraryItem
    {
        [Key]
        public int Id { get; set; }

        [ForeignKey(nameof(Itinerary))]
        public int ItineraryId { get; set; }
        public Itinerary Itinerary { get; set; } = null!;

        [ForeignKey(nameof(Tour))]
        public int TourId { get; set; }
        public Tour Tour { get; set; } = null!;

        public int DayNumber { get; set; }

        public int SequenceOrder { get; set; }

        public TimeSpan StartTime { get; set; }

        public TimeSpan EndTime { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal PriceAtSelection { get; set; }
    }
}
