using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using backend.Models.Enums;

namespace backend.Models
{
    /// <summary>
    /// A hotel at a specific destination.
    /// Spec: Id, DestinationId (FK), Name, Address, Latitude, Longitude, StarRating, Status.
    /// Price lives on Room only — one source of truth (spec note).
    /// </summary>
    public class Hotel
    {
        [Key]
        public int Id { get; set; }

        // ── Which destination this hotel belongs to ──
        [Required]
        public int DestinationId { get; set; }

        [Required]
        [MaxLength(200)]
        public string Name { get; set; } = string.Empty;

        [MaxLength(500)]
        public string? Address { get; set; }

        // ── Location for the Trip Map ──
        public double Latitude { get; set; }
        public double Longitude { get; set; }

        // ── 1 to 5 star rating ──
        [Range(1, 5)]
        public int StarRating { get; set; }

        // ── Soft delete: Active or Inactive ──
        [Required]
        public HotelStatus Status { get; set; } = HotelStatus.Active;

        // ── Navigation Properties ──

        /// <summary>
        /// The destination this hotel is located at.
        /// </summary>
        [ForeignKey(nameof(DestinationId))]
        public Destination Destination { get; set; } = null!;

        /// <summary>
        /// All room types available at this hotel.
        /// </summary>
        public ICollection<Room> Rooms { get; set; } = new List<Room>();
    }
}
