using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace backend.Models
{
    /// <summary>
    /// A room type within a hotel.
    /// Spec: Id, HotelId (FK), RoomType, Capacity, TotalRooms, PricePerNight, Currency.
    /// 
    /// Example: "Deluxe Double" — capacity 2 guests, 15 total rooms, $120/night.
    /// TotalRooms is the total inventory. The AvailabilityService subtracts
    /// existing bookings to get the available count.
    /// </summary>
    public class Room
    {
        [Key]
        public int Id { get; set; }

        // ── Which hotel this room belongs to ──
        [Required]
        public int HotelId { get; set; }

        /// <summary>
        /// e.g. "Single", "Double", "Deluxe", "Suite"
        /// </summary>
        [Required]
        [MaxLength(50)]
        public string RoomType { get; set; } = string.Empty;

        /// <summary>
        /// Max number of guests this room can hold.
        /// </summary>
        [Range(1, 20)]
        public int Capacity { get; set; }

        /// <summary>
        /// Total number of rooms of this type in the hotel (inventory).
        /// </summary>
        [Range(0, 1000)]
        public int TotalRooms { get; set; }

        /// <summary>
        /// Price per night for this room type.
        /// </summary>
        [Column(TypeName = "decimal(18,2)")]
        public decimal PricePerNight { get; set; }

        [Required]
        [MaxLength(10)]
        public string Currency { get; set; } = "USD";

        // ── Navigation ──
        [ForeignKey(nameof(HotelId))]
        public Hotel Hotel { get; set; } = null!;
    }
}
