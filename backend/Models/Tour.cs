using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace backend.Models
{
    public class Tour
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int Id { get; set; }

        [ForeignKey(nameof(Destination))]
        public int DestinationId { get; set; }

        public Destination Destination { get; set; } = null!;

        [Required]
        [MaxLength(150)]
        public string Name { get; set; } = string.Empty;

        [Required]
        [MaxLength(50)]
        public string Category { get; set; } = string.Empty;

        [MaxLength(1000)]
        public string? Description { get; set; }

        [MaxLength(500)]
        public string? ImageUrl { get; set; }

        public decimal Price { get; set; }

        [Required]
        [MaxLength(10)]
        public string Currency { get; set; } = string.Empty;

        public double DurationHours { get; set; }

        public TimeSpan DefaultStartTime { get; set; }

        public double? Latitude { get; set; }

        public double? Longitude { get; set; }

        [Required]
        [MaxLength(20)]
        public string Status { get; set; } = "Active";

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    }
}
