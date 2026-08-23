namespace backend.Models.Enums
{
    /// <summary>
    /// Active  = hotel is available for bookings.
    /// Inactive = soft-deleted, hidden from searches but kept in DB.
    /// </summary>
    public enum HotelStatus
    {
        Active,
        Inactive
    }
}
