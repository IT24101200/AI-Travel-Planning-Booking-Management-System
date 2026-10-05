using System.ComponentModel.DataAnnotations;

namespace backend.DTOs
{
    /// <summary>
    /// Request DTO for updating a customer profile.
    /// </summary>
    public class CustomerUpdateDto
    {
        [Required]
        [MaxLength(150)]
        public string FullName { get; set; } = string.Empty;

        [Required(ErrorMessage = "Phone number is required.")]
        [StringLength(10, MinimumLength = 10, ErrorMessage = "Phone number must be exactly 10 characters.")]
        [RegularExpression(@"^\d{10}$", ErrorMessage = "Phone number must contain exactly 10 digits.")]
        public string Phone { get; set; } = string.Empty;

        /// <summary>Optional role update ("Customer", "TravelAgent", or "Admin").</summary>
        public string? Role { get; set; }

        /// <summary>Optional department update for staff.</summary>
        public string? Department { get; set; }
    }
}
