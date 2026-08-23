using System.ComponentModel.DataAnnotations;

namespace backend.Models
{
    /// <summary>
    /// Customer profile linked directly to an ASP.NET Identity user.
    /// The Id IS the IdentityUser.Id (string).
    /// </summary>
    public class Customer
    {
        /// <summary>
        /// Primary key — same value as the ASP.NET Identity UserId.
        /// </summary>
        [Key]
        public string Id { get; set; } = string.Empty;

        [Required]
        [MaxLength(150)]
        public string FullName { get; set; } = string.Empty;

        [MaxLength(20)]
        public string? Phone { get; set; }

        public DateTime JoinedAt { get; set; } = DateTime.UtcNow;

        public DateTime LastActiveAt { get; set; } = DateTime.UtcNow;

        [Required]
        [MaxLength(50)]
        public string Role { get; set; } = "Customer";

        // ── Navigation Properties ──
        public Preference? Preference { get; set; }
        public ICollection<Notification> Notifications { get; set; } = new List<Notification>();
        public ICollection<TripRequest> TripRequests { get; set; } = new List<TripRequest>();
    }
}
