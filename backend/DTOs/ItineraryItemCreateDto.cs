namespace backend.DTOs
{
    /// <summary>
    /// Request shape for adding a tour to an Itinerary.
    /// </summary>
    public class ItineraryItemCreateDto
    {
        public int TourId { get; set; }
        public int DayNumber { get; set; }
        public int SequenceOrder { get; set; }
        public TimeSpan StartTime { get; set; }
        public TimeSpan EndTime { get; set; }
    }
}
