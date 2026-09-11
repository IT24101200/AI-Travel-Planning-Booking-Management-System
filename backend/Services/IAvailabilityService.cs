using backend.DTOs;

namespace backend.Services
{
    /// <summary>
    /// Checks real inventory availability for rooms and transport.
    /// 
    /// Phase 1 (now): Returns total inventory as available (BookingItem doesn't exist yet).
    /// Phase 2 (after Student D): Subtract overlapping confirmed bookings from totals.
    /// 
    /// The Booking Agent (Agent 3) will call these through the API to check
    /// real availability before proposing a package.
    /// </summary>
    public interface IAvailabilityService
    {
        /// <summary>
        /// Check how many rooms of a given type are available for specific dates.
        /// </summary>
        Task<RoomAvailabilityDto?> CheckRoomAvailabilityAsync(int roomId, DateTime checkIn, DateTime checkOut);

        /// <summary>
        /// Check how many seats are available on a specific transport option.
        /// </summary>
        Task<TransportAvailabilityDto?> CheckTransportAvailabilityAsync(int transportOptionId);
    }
}
