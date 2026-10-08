using backend.Data;
using backend.DTOs;
using backend.Models;
using backend.Models.Enums;
using backend.Services;
using Microsoft.EntityFrameworkCore;

namespace backend.Tests;

public class TransportLifecycleTests
{
    private static async Task<AppDbContext> CreateContextAsync()
    {
        var connection = new Microsoft.Data.Sqlite.SqliteConnection("Data Source=:memory:");
        await connection.OpenAsync();
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlite(connection)
            .Options;
        var context = new AppDbContext(options);
        await context.Database.EnsureCreatedAsync();
        context.Customers.Add(new Customer { Id = "customer-1", FullName = "Customer" });
        context.Destinations.Add(new Destination { Id = 1, Name = "Kandy", Country = "Sri Lanka" });
        context.TripRequests.Add(new TripRequest
        {
            Id = 1,
            CustomerId = "customer-1",
            DestinationId = 1,
            StartDate = new DateTime(2026, 10, 10),
            EndDate = new DateTime(2026, 10, 12),
            TravellerCount = 2,
            BudgetCeiling = 10000,
            Currency = "LKR",
            Status = TripRequestStatus.Planning,
            RawRequestText = "Kandy trip"
        });
        context.Itineraries.Add(new Itinerary
        {
            Id = 1,
            CustomerId = "customer-1",
            TripRequestId = 1,
            StartDate = new DateTime(2026, 10, 10),
            EndDate = new DateTime(2026, 10, 12),
            Status = ItineraryStatus.Proposed,
            Currency = "LKR"
        });
        context.TransportOptions.Add(new TransportOption
        {
            Id = 1,
            Type = TransportType.Bus,
            Provider = "Kandy Bus",
            RouteFrom = "Colombo Pickup",
            RouteTo = "Kandy",
            DepartureTime = new DateTime(2026, 10, 10, 8, 0, 0),
            ArrivalTime = new DateTime(2026, 10, 10, 11, 0, 0),
            Capacity = 3,
            Price = 1000,
            Currency = "LKR",
            Status = TransportStatus.Active
        });
        await context.SaveChangesAsync();
        return context;
    }

    private static BookingCreateDto CreateTransportBooking(int quantity = 2) => new()
    {
        CustomerId = "customer-1",
        ItineraryId = 1,
        Currency = "LKR",
        Items = new List<BookingItemCreateDto>
        {
            new()
            {
                ItemType = BookingItemType.Transport,
                TransportOptionId = 1,
                Quantity = quantity,
                UnitPrice = 1
            }
        }
    };

    private static CreateTransportOptionDto UpdateDto(int capacity, string status = "Active") => new()
    {
        Type = "Bus",
        Provider = "Kandy Bus",
        RouteFrom = "Colombo Pickup",
        RouteTo = "Kandy",
        DepartureTime = new DateTime(2026, 10, 10, 8, 0, 0),
        ArrivalTime = new DateTime(2026, 10, 10, 11, 0, 0),
        Capacity = capacity,
        Price = 1000,
        Currency = "LKR",
        Status = status
    };

    [Fact]
    public async Task InactiveTransportCannotBeConfirmed()
    {
        await using var context = await CreateContextAsync();
        var bookingService = new BookingService(context);
        var booking = await bookingService.CreateBookingAsync(CreateTransportBooking());
        var transport = await context.TransportOptions.SingleAsync();
        transport.Status = TransportStatus.Inactive;
        await context.SaveChangesAsync();

        var ex = await Assert.ThrowsAsync<TransportBusinessException>(() =>
            bookingService.UpdateBookingStatusAsync(booking.Id, BookingStatus.Confirmed));

        Assert.Equal("TRANSPORT_INACTIVE", ex.Code);
        Assert.Equal(BookingStatus.AwaitingApproval, (await context.Bookings.FindAsync(booking.Id))!.Status);
    }

    [Fact]
    public async Task CapacityCannotBeReducedBelowReservedSeatsButEqualCapacityIsAllowed()
    {
        await using var context = await CreateContextAsync();
        var bookingService = new BookingService(context);
        await bookingService.CreateBookingAsync(CreateTransportBooking());
        var service = new TransportService(context);

        var ex = await Assert.ThrowsAsync<TransportBusinessException>(() =>
            service.UpdateAsync(1, UpdateDto(capacity: 1)));
        Assert.Equal("TRANSPORT_CAPACITY_CONFLICT", ex.Code);

        Assert.True(await service.UpdateAsync(1, UpdateDto(capacity: 2)));
        Assert.Equal(2, (await context.TransportOptions.FindAsync(1))!.Capacity);

        var pending = await context.Bookings.SingleAsync();
        var confirmed = await bookingService.UpdateBookingStatusAsync(pending.Id, BookingStatus.Confirmed);
        Assert.Equal(BookingStatus.Confirmed, confirmed.Status);
    }

    [Fact]
    public async Task ActiveTransportWithEnoughCapacityCanBeConfirmedAndSnapshotsRemainHistorical()
    {
        await using var context = await CreateContextAsync();
        var bookingService = new BookingService(context);
        var booking = await bookingService.CreateBookingAsync(CreateTransportBooking(quantity: 1));
        var transport = await context.TransportOptions.SingleAsync();
        transport.Provider = "Changed Provider";
        transport.RouteFrom = "Changed Origin";
        transport.RouteTo = "Changed Destination";
        await context.SaveChangesAsync();

        var mappedBeforeConfirmation = await bookingService.GetBookingByIdAsync(booking.Id);
        var item = Assert.Single(mappedBeforeConfirmation!.BookingItems);
        Assert.Equal("Kandy Bus", item.TransportProvider);
        Assert.Equal("Colombo Pickup", item.RouteFrom);
        Assert.Equal("Kandy", item.RouteTo);

        var confirmed = await bookingService.UpdateBookingStatusAsync(booking.Id, BookingStatus.Confirmed);
        Assert.Equal(BookingStatus.Confirmed, confirmed.Status);
    }

    [Fact]
    public async Task LegacyTransportItemWithoutSnapshotsFallsBackToCurrentNavigation()
    {
        await using var context = await CreateContextAsync();
        var bookingService = new BookingService(context);
        var booking = await bookingService.CreateBookingAsync(CreateTransportBooking(quantity: 1));
        var item = await context.BookingItems.SingleAsync();
        item.TransportTypeSnapshot = null;
        item.TransportProviderSnapshot = null;
        item.TransportRouteFromSnapshot = null;
        item.TransportRouteToSnapshot = null;
        item.TransportDepartureTimeSnapshot = null;
        item.TransportArrivalTimeSnapshot = null;
        var transport = await context.TransportOptions.SingleAsync();
        transport.Provider = "Legacy Current Provider";
        await context.SaveChangesAsync();

        var mapped = await bookingService.GetBookingByIdAsync(booking.Id);

        Assert.Equal("Legacy Current Provider", Assert.Single(mapped!.BookingItems).TransportProvider);
    }
}
