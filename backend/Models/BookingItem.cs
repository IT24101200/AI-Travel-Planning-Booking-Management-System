using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace backend.Models
{
    /// <summary>
    /// Student D — Line item in a booking (tour, room, or transport segment).
    /// </summary>
    public class BookingItem
    {
        [Key]
        public int Id { get; set; }

        [ForeignKey(nameof(Booking))]
        public int BookingId { get; set; }
        public Booking Booking { get; set; } = null!;

        [Required]
        [MaxLength(20)]
        public string ItemType { get; set; } = "Tour"; // Tour, Room, Transport

        [ForeignKey(nameof(Tour))]
        public int? TourId { get; set; }
        public Tour? Tour { get; set; }

        [ForeignKey(nameof(Room))]
        public int? RoomId { get; set; }
        public Room? Room { get; set; }

        [ForeignKey(nameof(TransportOption))]
        public int? TransportOptionId { get; set; }
        public TransportOption? TransportOption { get; set; }

        public DateTime? CheckInDate { get; set; }

        public DateTime? CheckOutDate { get; set; }

        public int Quantity { get; set; } = 1;

        [Column(TypeName = "decimal(18,2)")]
        public decimal UnitPrice { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal Subtotal { get; set; }
    }
}
