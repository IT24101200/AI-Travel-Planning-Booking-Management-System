using Microsoft.EntityFrameworkCore;
using backend.Data;
using backend.DTOs;
using backend.Models.Enums;

namespace backend.Services
{
    /// <summary>
    /// Room availability counts peak confirmed occupancy for overlapping stays.
    /// Pending proposals do not reserve rooms. Checkout is exclusive, so rooms
    /// become available again for subsequent dates without changing TotalRooms.
    /// Transport availability counts seats in active bookings.
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
        /// If peak confirmed occupancy is 3 for the requested dates,
        /// returns AvailableRooms = 7. Pending proposals do not reduce it.
        /// </summary>
        public async Task<RoomAvailabilityDto?> CheckRoomAvailabilityAsync(
            int roomId, DateTime checkIn, DateTime checkOut)
        {
            var room = await _context.Rooms.FindAsync(roomId);
            if (room is null) return null;

            // ── Real Availability Calculation ──
            // Only human-confirmed stays consume room inventory.
            // where check-in and check-out dates overlap:
            //   existing.CheckInDate < requested.checkOut AND existing.CheckOutDate > requested.checkIn
            if (checkOut <= checkIn)
                throw new ArgumentException("Check-out must be after check-in.");
            var bookedRooms = await RoomInventory.BookedPeakAsync(_context, roomId, checkIn, checkOut);

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
