using Microsoft.EntityFrameworkCore;
using backend.Data;
using backend.DTOs;
using backend.Models.Enums;

namespace backend.Services
{
    /// <summary>
    /// Checks real inventory availability for rooms and transport.
    /// 
    /// HOW IT WORKS:
    /// - Room availability = TotalRooms − (rooms already booked for overlapping dates)
    /// - Transport availability = Capacity − (seats already booked)
    /// 
    /// PHASE 1 (current):
    ///   BookingItem doesn't exist yet (Student D hasn't built it).
    ///   So we return TotalRooms/Capacity as-is (BookedRooms = 0).
    ///   
    /// PHASE 2 (after Student D creates BookingItem):
    ///   We'll add the overlapping-booking query. The interface stays the same,
    ///   only the internal logic changes. This is why interfaces are useful!
    /// 
    /// WHY THIS MATTERS FOR THE VIVA:
    ///   The spec says: "availability check that counts existing overlapping bookings
    ///   and subtracts from TotalRooms, wrapped in a database transaction to prevent
    ///   two customers booking the last room simultaneously."
    ///   Phase 2 will add the transaction + overlap logic.
    /// </summary>
    public class AvailabilityService : IAvailabilityService
    {
        private readonly AppDbContext _context;

        public AvailabilityService(AppDbContext context)
        {
            _context = context;
        }

        /// <summary>
        /// Check room availability for a date range.
        /// 
        /// Example: Room has TotalRooms = 10.
        ///   Phase 1: returns AvailableRooms = 10 (no bookings exist yet).
        ///   Phase 2: if 3 rooms are booked for overlapping dates, returns 7.
        /// </summary>
        public async Task<RoomAvailabilityDto?> CheckRoomAvailabilityAsync(
            int roomId, DateTime checkIn, DateTime checkOut)
        {
            var room = await _context.Rooms.FindAsync(roomId);
            if (room is null) return null;

            // ── Real Availability Calculation ──
            // Count rooms booked in active bookings (Draft, AwaitingApproval, Confirmed)
            // where check-in and check-out dates overlap:
            //   existing.CheckInDate < requested.checkOut AND existing.CheckOutDate > requested.checkIn
            var activeStatuses = new[] { BookingStatus.Draft, BookingStatus.AwaitingApproval, BookingStatus.Confirmed };

            var bookedRooms = await _context.BookingItems
                .Where(bi => bi.RoomId == roomId 
                          && bi.ItemType == BookingItemType.Room
                          && bi.CheckInDate.HasValue 
                          && bi.CheckOutDate.HasValue
                          && bi.CheckInDate.Value < checkOut 
                          && bi.CheckOutDate.Value > checkIn
                          && activeStatuses.Contains(bi.Booking.Status))
                .SumAsync(bi => bi.Quantity);

            return new RoomAvailabilityDto
            {
                RoomId         = room.Id,
                RoomType       = room.RoomType,
                TotalRooms     = room.TotalRooms,
                BookedRooms    = bookedRooms,
                AvailableRooms = Math.Max(0, room.TotalRooms - bookedRooms),
                PricePerNight  = room.PricePerNight,
                Currency       = room.Currency
            };
        }

        /// <summary>
        /// Check transport availability (how many seats are left).
        /// </summary>
        public async Task<TransportAvailabilityDto?> CheckTransportAvailabilityAsync(
            int transportOptionId)
        {
            var transport = await _context.TransportOptions.FindAsync(transportOptionId);
            if (transport is null) return null;

            // ── Real Transport Availability Calculation ──
            // Sum seats booked in active bookings (Draft, AwaitingApproval, Confirmed)
            var activeStatuses = new[] { BookingStatus.Draft, BookingStatus.AwaitingApproval, BookingStatus.Confirmed };

            var bookedSeats = await _context.BookingItems
                .Where(bi => bi.TransportOptionId == transportOptionId
                          && bi.ItemType == BookingItemType.Transport
                          && activeStatuses.Contains(bi.Booking.Status))
                .SumAsync(bi => bi.Quantity);

            return new TransportAvailabilityDto
            {
                TransportOptionId = transport.Id,
                Type              = transport.Type.ToString(),
                RouteFrom         = transport.RouteFrom,
                RouteTo           = transport.RouteTo,
                TotalCapacity     = transport.Capacity,
                BookedSeats       = bookedSeats,
                AvailableSeats    = Math.Max(0, transport.Capacity - bookedSeats),
                Price             = transport.Price,
                Currency          = transport.Currency
            };
        }
    }
}
