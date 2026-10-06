using backend.Data;
using backend.DTOs;
using backend.Models;
using backend.Models.Enums;
using backend.Services;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Moq;

namespace backend.Tests;

public class RoomInventoryLifecycleTests
{
    private static readonly DateTime Start = new(2026, 10, 13, 0, 0, 0, DateTimeKind.Utc);

    private static async Task<AppDbContext> DatabaseAsync(int stock = 1)
    {
        var db = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlite("Data Source=:memory:").Options);
        await db.Database.OpenConnectionAsync();
        await db.Database.EnsureCreatedAsync();
        db.Customers.Add(new Customer { Id = "customer", FullName = "Customer" });
        db.Users.Add(new IdentityUser { Id = "staff", UserName = "staff" });
        db.TripRequests.Add(new TripRequest { Id = 1, CustomerId = "customer", RawRequestText = "Trip" });
        db.Itineraries.Add(new Itinerary { Id = 1, CustomerId = "customer", TripRequestId = 1, StartDate = Start, EndDate = Start.AddDays(6) });
        db.Destinations.Add(new Destination { Id = 1, Name = "Kandy", Country = "Sri Lanka" });
        db.Hotels.Add(new Hotel { Id = 1, DestinationId = 1, Name = "Hotel", Status = HotelStatus.Active });
        db.Rooms.Add(new Room { Id = 1, HotelId = 1, RoomType = "Double", Capacity = 2, TotalRooms = stock, PricePerNight = 10000 });
        await db.SaveChangesAsync();
        return db;
    }

    private static async Task<int> ProposalAsync(AppDbContext db, DateTime checkIn, DateTime checkOut, int quantity = 1)
    {
        var booking = new Booking {
            BookingReference = Guid.NewGuid().ToString(), CustomerId = "customer", ItineraryId = 1,
            Status = BookingStatus.AwaitingApproval,
            BookingItems = [new BookingItem { ItemType = BookingItemType.Room, RoomId = 1,
                CheckInDate = checkIn, CheckOutDate = checkOut, Quantity = quantity }]
        };
        db.Bookings.Add(booking);
        await db.SaveChangesAsync();
        return booking.Id;
    }

    [Fact]
    public async Task StaffApprovalConsumesStock_CheckoutAndCancellationReleaseIt()
    {
        await using var db = await DatabaseAsync();
        var id = await ProposalAsync(db, Start, Start.AddDays(3));
        var availability = new AvailabilityService(db);
        Assert.Equal(1, (await availability.CheckRoomAvailabilityAsync(1, Start, Start.AddDays(1)))!.AvailableRooms);
        var user = new Mock<UserManager<IdentityUser>>(new Mock<IUserStore<IdentityUser>>().Object,
            null!, null!, null!, null!, null!, null!, null!, null!);
        var approval = new ApprovalService(db, user.Object);
        await approval.CreateApprovalAsync("staff", new ApprovalCreateDto { BookingId = id, Decision = ApprovalDecision.Approved });
        Assert.Equal(0, (await availability.CheckRoomAvailabilityAsync(1, Start, Start.AddDays(1)))!.AvailableRooms);
        Assert.Equal(1, (await availability.CheckRoomAvailabilityAsync(1, Start.AddDays(3), Start.AddDays(4)))!.AvailableRooms);
        Assert.Equal(1, (await db.Rooms.FindAsync(1))!.TotalRooms);
        await new BookingService(db).UpdateBookingStatusAsync(id, BookingStatus.Cancelled);
        Assert.Equal(1, (await availability.CheckRoomAvailabilityAsync(1, Start, Start.AddDays(1)))!.AvailableRooms);
    }

    [Fact]
    public async Task SecondConflictingProposalCannotBeConfirmed()
    {
        await using var db = await DatabaseAsync();
        var first = await ProposalAsync(db, Start, Start.AddDays(3));
        var second = await ProposalAsync(db, Start.AddDays(1), Start.AddDays(4));
        var service = new BookingService(db);
        await service.UpdateBookingStatusAsync(first, BookingStatus.Confirmed);
        await Assert.ThrowsAsync<InvalidOperationException>(() => service.UpdateBookingStatusAsync(second, BookingStatus.Confirmed));
        Assert.Equal(BookingStatus.AwaitingApproval, (await db.Bookings.FindAsync(second))!.Status);
        Assert.Equal(1, (await db.Rooms.FindAsync(1))!.TotalRooms);
    }

    [Fact]
    public async Task SequentialStaysUsePeakOccupancy_AndReleaseAtCheckoutBoundary()
    {
        await using var db = await DatabaseAsync(3);
        var first = await ProposalAsync(db, Start, Start.AddDays(2), 2);
        var second = await ProposalAsync(db, Start.AddDays(2), Start.AddDays(4), 2);
        var service = new BookingService(db);
        await service.UpdateBookingStatusAsync(first, BookingStatus.Confirmed);
        await service.UpdateBookingStatusAsync(second, BookingStatus.Confirmed);
        var result = await new AvailabilityService(db).CheckRoomAvailabilityAsync(1, Start, Start.AddDays(4));
        Assert.Equal(2, result!.BookedRooms);
        Assert.Equal(1, result.AvailableRooms);
        Assert.Equal(3, result.TotalRooms);
    }
}
