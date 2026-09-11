using System.ComponentModel.DataAnnotations;

namespace backend.Models
{
    /// <summary>
    /// Travel Agent profile linked directly to an ASP.NET Identity user.
    /// The Id is the IdentityUser.Id.
    /// </summary>
    public class TravelAgent
    {
        [Key]
        public string Id { get; set; } = string.Empty;

        [Required]
        [MaxLength(150)]
        public string FullName { get; set; } = string.Empty;

        [MaxLength(100)]
        public string Department { get; set; } = "Operations";

        public DateTime HireDate { get; set; } = DateTime.UtcNow;

        // Navigation property for approvals done by this agent
        public ICollection<BookingApproval> BookingApprovals { get; set; } = new List<BookingApproval>();
    }
}
