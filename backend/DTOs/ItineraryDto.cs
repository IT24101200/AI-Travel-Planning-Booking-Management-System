using backend.Models.Enums;

namespace backend.DTOs
{
    /// <summary>
    /// Response shape for an Itinerary, including its items.
    /// </summary>
    public class ItineraryDto
    {
        public int Id { get; set; }
        public string CustomerId { get; set; } = string.Empty;
        public int TripRequestId { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public ItineraryStatus Status { get; set; }
        public decimal TotalEstimatedCost { get; set; }
        public string Currency { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; }
        public List<ItineraryItemDto> Items { get; set; } = new();
    }

    /// <summary>
    /// Response shape for a single scheduled tour within an Itinerary.
    /// </summary>
    public class ItineraryItemDto
    {
        public int Id { get; set; }
        public int TourId { get; set; }
        public string TourName { get; set; } = string.Empty;
        public int DayNumber { get; set; }
        public int SequenceOrder { get; set; }
        public TimeSpan StartTime { get; set; }
        public TimeSpan EndTime { get; set; }
        public decimal PriceAtSelection { get; set; }
    }
}
