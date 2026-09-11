using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace backend.Models
{
    /// <summary>
    /// Student C — Hotel property available for booking.
    /// </summary>
    public class Hotel
    {
        [Key]
        public int Id { get; set; }

        [ForeignKey(nameof(Destination))]
        public int DestinationId { get; set; }
        public Destination Destination { get; set; } = null!;

        [Required]
        [MaxLength(150)]
        public string Name { get; set; } = string.Empty;

        [MaxLength(250)]
        public string Address { get; set; } = string.Empty;

        public double? Latitude { get; set; }

        public double? Longitude { get; set; }

        [Range(1, 5)]
        public int StarRating { get; set; } = 4;

        [Required]
        [MaxLength(20)]
        public string Status { get; set; } = "Active";

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        // Navigation
        public ICollection<Room> Rooms { get; set; } = new List<Room>();
    }
}
