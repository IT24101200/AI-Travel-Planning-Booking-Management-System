using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.AspNetCore.Identity;

namespace backend.Models
{
    /// <summary>
    /// TravelAgent entity linked to IdentityUser (AspNetUsers).
    /// </summary>
    public class TravelAgent
    {
        [Key]
        public string Id { get; set; } = string.Empty;

        [Required]
        [MaxLength(150)]
        public string FullName { get; set; } = string.Empty;

        [MaxLength(100)]
        public string Department { get; set; } = string.Empty;

        public DateTime HireDate { get; set; } = DateTime.UtcNow;

        // ── Navigation Properties ──
        [ForeignKey(nameof(Id))]
        public IdentityUser? User { get; set; }

        public ICollection<BookingApproval> BookingApprovals { get; set; } = new List<BookingApproval>();
    }
}
