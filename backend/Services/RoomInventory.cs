using backend.Data;
using backend.Models;
using backend.Models.Enums;
using Microsoft.EntityFrameworkCore;

namespace backend.Services;

internal static class RoomInventory
{
    internal static int PeakOccupancy(IEnumerable<BookingItem> items)
    {
        var changes = items
            .Where(i => i.CheckInDate.HasValue && i.CheckOutDate.HasValue)
            .SelectMany(i => new[] {
                (Date: i.CheckInDate!.Value, Change: i.Quantity),
                (Date: i.CheckOutDate!.Value, Change: -i.Quantity)
            })
            .GroupBy(e => e.Date).OrderBy(g => g.Key);
        var occupied = 0;
        var peak = 0;
        foreach (var change in changes)
        {
            occupied += change.Sum(e => e.Change);
            peak = Math.Max(peak, occupied);
        }
        return peak;
    }

    internal static async Task<int> BookedPeakAsync(
        AppDbContext db, int roomId, DateTime checkIn, DateTime checkOut, int? excludingBookingId = null)
    {
        var bookings = await db.BookingItems.AsNoTracking()
            .Where(i => i.RoomId == roomId && i.ItemType == BookingItemType.Room
                && i.Booking.Status == BookingStatus.Confirmed
                && (!excludingBookingId.HasValue || i.BookingId != excludingBookingId.Value)
                && i.CheckInDate < checkOut && i.CheckOutDate > checkIn)
            .ToListAsync();
        ClipToWindow(bookings, checkIn, checkOut);
        return PeakOccupancy(bookings);
    }

    private static void ClipToWindow(IEnumerable<BookingItem> items, DateTime start, DateTime end)
    {
        foreach (var item in items)
        {
            if (item.CheckInDate < start) item.CheckInDate = start;
            if (item.CheckOutDate > end) item.CheckOutDate = end;
        }
    }

    // Caller owns a serializable transaction. Lock room rows in a stable order
    // before counting confirmed stays, so simultaneous approvals cannot oversell.
    internal static async Task ValidateConfirmationAsync(AppDbContext db, int bookingId)
    {
        var proposed = await db.BookingItems.AsNoTracking()
            .Where(i => i.BookingId == bookingId && i.ItemType == BookingItemType.Room)
            .ToListAsync();
        foreach (var group in proposed.GroupBy(i => i.RoomId).OrderBy(g => g.Key))
        {
            if (group.Key is not int roomId)
                throw new InvalidOperationException("A room booking is missing its room ID.");
            var room = db.Database.ProviderName?.Contains("Npgsql") == true
                ? await db.Rooms.FromSqlRaw("SELECT * FROM \"Rooms\" WHERE \"Id\" = {0} FOR UPDATE", roomId)
                    .AsNoTracking().SingleOrDefaultAsync()
                : await db.Rooms.AsNoTracking().SingleOrDefaultAsync(r => r.Id == roomId);
            if (room is null) throw new InvalidOperationException("The requested room no longer exists.");
            if (room.Status != RoomStatus.Active)
                throw new InvalidOperationException("The requested room is no longer active.");
            if (!await db.Hotels.AnyAsync(h => h.Id == room.HotelId && h.Status == HotelStatus.Active))
                throw new InvalidOperationException("The requested hotel is no longer active.");
            if (group.Any(i => !i.CheckInDate.HasValue || !i.CheckOutDate.HasValue
                || i.CheckOutDate <= i.CheckInDate || i.Quantity <= 0))
                throw new InvalidOperationException("Room bookings require valid check-in, check-out and quantity.");
            var start = group.Min(i => i.CheckInDate!.Value);
            var end = group.Max(i => i.CheckOutDate!.Value);
            var confirmed = await db.BookingItems.AsNoTracking()
                .Where(i => i.RoomId == roomId && i.ItemType == BookingItemType.Room
                    && i.BookingId != bookingId && i.Booking.Status == BookingStatus.Confirmed
                    && i.CheckInDate < end && i.CheckOutDate > start)
                .ToListAsync();
            ClipToWindow(confirmed, start, end);
            if (PeakOccupancy(confirmed.Concat(group)) > room.TotalRooms)
                throw new InvalidOperationException($"Room '{room.RoomType}' has insufficient availability for these dates. Update the proposal before approval.");
        }
    }
}
