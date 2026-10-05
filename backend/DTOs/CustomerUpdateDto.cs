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
        [MaxLength(20, ErrorMessage = "Phone number cannot exceed 20 characters.")]
        [RegularExpression(@"^[+]?[0-9\s\-()]{9,20}$", ErrorMessage = "Phone number must be valid (e.g. 0771234567 or +94 11 888 7778).")]
        public string Phone { get; set; } = string.Empty;

        /// <summary>Optional role update ("Customer", "TravelAgent", or "Admin").</summary>
        public string? Role { get; set; }

        /// <summary>Optional department update for staff.</summary>
        public string? Department { get; set; }
    }
}
