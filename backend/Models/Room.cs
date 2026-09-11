using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace backend.Models
{
    /// <summary>
    /// Student C — Specific room category and inventory within a hotel.
    /// </summary>
    public class Room
    {
        [Key]
        public int Id { get; set; }

        [ForeignKey(nameof(Hotel))]
        public int HotelId { get; set; }
        public Hotel Hotel { get; set; } = null!;

        [Required]
        [MaxLength(80)]
        public string RoomType { get; set; } = "Deluxe Room";

        public int Capacity { get; set; } = 2;

        public int TotalRooms { get; set; } = 10;

        [Column(TypeName = "decimal(18,2)")]
        public decimal PricePerNight { get; set; }

        [Required]
        [MaxLength(10)]
        public string Currency { get; set; } = "USD";
    }
}
