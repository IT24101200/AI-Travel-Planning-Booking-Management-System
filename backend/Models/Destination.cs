using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace backend.Models
{
    /// <summary>
    /// Travel destination. Stub model — full implementation owned by another student.
    /// </summary>
    public class Destination
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public Guid Id { get; set; }

        [Required]
        [MaxLength(200)]
        public string Name { get; set; } = string.Empty;

        // Navigation
        public ICollection<TripRequest> TripRequests { get; set; } = new List<TripRequest>();
    }
}
