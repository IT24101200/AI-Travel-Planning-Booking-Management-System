using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using backend.Models.Enums;

namespace backend.Models
{
    public class BookingItem
    {
        [Key]
        public int Id { get; set; }

        [Required]
        public int BookingId { get; set; }

        [Required]
        public BookingItemType ItemType { get; set; }

        public int? TourId { get; set; }
        public int? RoomId { get; set; }
        public int? TransportOptionId { get; set; }

        public DateTime? CheckInDate { get; set; }
        public DateTime? CheckOutDate { get; set; }

        [Range(1, 1000)]
        public int Quantity { get; set; } = 1;

        [Column(TypeName = "decimal(18,2)")]
        public decimal UnitPrice { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal Subtotal { get; set; }

        // ── Navigation Properties ──
        [ForeignKey(nameof(BookingId))]
        public Booking Booking { get; set; } = null!;

        [ForeignKey(nameof(TourId))]
        public Tour? Tour { get; set; }

        [ForeignKey(nameof(RoomId))]
        public Room? Room { get; set; }

        [ForeignKey(nameof(TransportOptionId))]
        public TransportOption? TransportOption { get; set; }
    }
}
