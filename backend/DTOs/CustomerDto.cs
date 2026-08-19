namespace backend.DTOs
{
    /// <summary>
    /// Response DTO for customer profile data.
    /// </summary>
    public class CustomerDto
    {
        public string Id { get; set; } = string.Empty;
        public string FullName { get; set; } = string.Empty;
        public string? Phone { get; set; }
        public string Email { get; set; } = string.Empty;
        public DateTime JoinedAt { get; set; }
        public DateTime LastActiveAt { get; set; }
        public bool HasPreference { get; set; }
    }
}
