namespace backend.Models.Enums
{
    /// <summary>
    /// Active  = transport option is available for bookings.
    /// Inactive = soft-deleted, hidden from searches but kept in DB.
    /// </summary>
    public enum TransportStatus
    {
        Active,
        Inactive
    }
}
