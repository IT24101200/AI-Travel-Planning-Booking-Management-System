namespace backend.Models.Enums
{
    /// <summary>
    /// Active rooms are bookable and publicly searchable. Inactive rooms are
    /// retained for historical booking display and staff administration.
    /// </summary>
    public enum RoomStatus
    {
        Active,
        Inactive
    }
}
