using backend.Data;
using Microsoft.EntityFrameworkCore;

namespace backend.Services
{
    /// <summary>
    /// Student C — Real availability checker for rooms and transport.
    /// Queries BookingItems to count overlapping reservations, then subtracts
    /// from the total inventory to get remaining availability.
    /// Uses a serializable transaction so two concurrent bookings for the
    /// last room/seat don't both succeed (concurrency safety).
    /// </summary>
    public class AvailabilityService
    {
        private readonly AppDbContext _db;

        public AvailabilityService(AppDbContext db)
        {
            _db = db;
        }

        /// <summary>
        /// Check how many rooms of a given RoomId are still free for the date range.
        /// Only counts BookingItems whose parent Booking is not Cancelled or Rejected.
        /// </summary>
        public async Task<int> GetAvailableRoomCount(int roomId, DateTime checkIn, DateTime checkOut)
        {
            var room = await _db.Rooms.FindAsync(roomId);
            if (room == null) return 0;

            // Count rooms already booked that overlap [checkIn, checkOut)
            var bookedCount = await _db.BookingItems
                .Where(bi => bi.RoomId == roomId
                    && bi.CheckInDate < checkOut   // overlap condition
                    && bi.CheckOutDate > checkIn   // overlap condition
                    && bi.Booking.Status != "Cancelled"
                    && bi.Booking.Status != "Rejected")
                .SumAsync(bi => (int?)bi.Quantity) ?? 0;

            return Math.Max(0, room.TotalRooms - bookedCount);
        }

        /// <summary>
        /// Check how many seats are still free on a transport option for a given date.
        /// </summary>
        public async Task<int> GetAvailableTransportSeats(int transportOptionId, DateTime travelDate)
        {
            var transport = await _db.TransportOptions.FindAsync(transportOptionId);
            if (transport == null) return 0;

            // Count seats already booked for the same transport on the same date
            var bookedSeats = await _db.BookingItems
                .Where(bi => bi.TransportOptionId == transportOptionId
                    && bi.CheckInDate.HasValue
                    && bi.CheckInDate.Value.Date == travelDate.Date
                    && bi.Booking.Status != "Cancelled"
                    && bi.Booking.Status != "Rejected")
                .SumAsync(bi => (int?)bi.Quantity) ?? 0;

            return Math.Max(0, transport.Capacity - bookedSeats);
        }

        /// <summary>
        /// Reserve a room inside a serializable transaction.
        /// Returns true if the reservation succeeded, false if no rooms left.
        /// This prevents two customers from booking the last room at the same time.
        /// </summary>
        public async Task<bool> TryReserveRoom(int roomId, DateTime checkIn, DateTime checkOut, int bookingId, decimal unitPrice, int quantity = 1)
        {
            // Use a serializable transaction for concurrency safety
            using var transaction = await _db.Database.BeginTransactionAsync(
                System.Data.IsolationLevel.Serializable);

            try
            {
                var available = await GetAvailableRoomCount(roomId, checkIn, checkOut);
                if (available < quantity)
                {
                    await transaction.RollbackAsync();
                    return false; // not enough rooms
                }

                // Create the booking item to hold the reservation
                var item = new Models.BookingItem
                {
                    BookingId = bookingId,
                    ItemType = "Room",
                    RoomId = roomId,
                    CheckInDate = checkIn,
                    CheckOutDate = checkOut,
                    Quantity = quantity,
                    UnitPrice = unitPrice,
                    Subtotal = unitPrice * (checkOut - checkIn).Days * quantity
                };

                _db.BookingItems.Add(item);
                await _db.SaveChangesAsync();
                await transaction.CommitAsync();
                return true;
            }
            catch
            {
                await transaction.RollbackAsync();
                throw;
            }
        }

        /// <summary>
        /// Reserve transport seats inside a serializable transaction.
        /// Returns true if the reservation succeeded, false if not enough seats.
        /// </summary>
        public async Task<bool> TryReserveTransport(int transportOptionId, DateTime travelDate, int bookingId, decimal unitPrice, int quantity = 1)
        {
            using var transaction = await _db.Database.BeginTransactionAsync(
                System.Data.IsolationLevel.Serializable);

            try
            {
                var available = await GetAvailableTransportSeats(transportOptionId, travelDate);
                if (available < quantity)
                {
                    await transaction.RollbackAsync();
                    return false; // not enough seats
                }

                var item = new Models.BookingItem
                {
                    BookingId = bookingId,
                    ItemType = "Transport",
                    TransportOptionId = transportOptionId,
                    CheckInDate = travelDate,
                    CheckOutDate = travelDate, // same day for transport
                    Quantity = quantity,
                    UnitPrice = unitPrice,
                    Subtotal = unitPrice * quantity
                };

                _db.BookingItems.Add(item);
                await _db.SaveChangesAsync();
                await transaction.CommitAsync();
                return true;
            }
            catch
            {
                await transaction.RollbackAsync();
                throw;
            }
        }
    }
}
