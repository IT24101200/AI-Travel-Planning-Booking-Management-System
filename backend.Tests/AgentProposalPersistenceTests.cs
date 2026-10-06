using System.Text.Json;
using backend.Data;
using backend.Models;
using backend.Models.Enums;
using backend.Services;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;

namespace backend.Tests;

public class AgentProposalPersistenceTests
{
    private static async Task<(AppDbContext Context, SqliteConnection Connection)> CreateContextAsync(
        TripRequestStatus status = TripRequestStatus.Planning,
        decimal budget = 1000m)
    {
        var connection = new SqliteConnection("Data Source=:memory:");
        await connection.OpenAsync();
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlite(connection)
            .Options;
        var context = new AppDbContext(options);
        await context.Database.EnsureCreatedAsync();

        context.Customers.Add(new Customer { Id = "cust-1", FullName = "Test Customer" });
        context.Destinations.Add(new Destination { Id = 1, Name = "Test Destination", Country = "Sri Lanka" });
        context.TripRequests.Add(new TripRequest
        {
            Id = 1,
            CustomerId = "cust-1",
            DestinationId = 1,
            StartDate = new DateTime(2026, 10, 10),
            EndDate = new DateTime(2026, 10, 12),
            TravellerCount = 2,
            BudgetCeiling = budget,
            Currency = "USD",
            Status = status,
            RawRequestText = "Test trip"
        });
        context.Tours.Add(new Tour
        {
            Id = 100,
            DestinationId = 1,
            Name = "Test Tour",
            Category = "Test",
            Price = 100m,
            Currency = "USD",
            Status = "Active",
            DefaultStartTime = new TimeSpan(9, 0, 0),
            DurationHours = 2
        });
        context.Hotels.Add(new Hotel
        {
            Id = 10,
            DestinationId = 1,
            Name = "Test Hotel",
            Status = HotelStatus.Active,
            StarRating = 4
        });
        context.Rooms.Add(new Room
        {
            Id = 20,
            HotelId = 10,
            RoomType = "Double",
            Capacity = 2,
            TotalRooms = 3,
            PricePerNight = 50m,
            Currency = "USD"
        });
        context.TransportOptions.Add(new TransportOption
        {
            Id = 30,
            Type = TransportType.Car,
            Provider = "Test Transport",
            RouteFrom = "A",
            RouteTo = "B",
            DepartureTime = new DateTime(2026, 10, 10, 8, 0, 0),
            ArrivalTime = new DateTime(2026, 10, 10, 10, 0, 0),
            Capacity = 5,
            Price = 25m,
            Currency = "USD",
            Status = TransportStatus.Active
        });
        await context.SaveChangesAsync();
        return (context, connection);
    }

    private static JsonElement Proposal(
        int tourId = 100,
        int roomId = 20,
        int transportId = 30,
        decimal total = 350m,
        string customerId = "cust-1") => JsonSerializer.SerializeToElement(new
        {
            trip_request_id = 1,
            customer_id = customerId,
            itinerary = new
            {
                schedule = new[]
                {
                    new
                    {
                        day_number = 1,
                        items = new[]
                        {
                            new { tour_id = tourId, start_time = "09:00:00", end_time = "11:00:00" }
                        }
                    }
                }
            },
            booking_details = new
            {
                total_package_cost = total,
                currency = "USD",
                selected_room = new { room_id = roomId },
                selected_transport = new { transport_id = transportId }
            },
            validation = new { is_valid = true }
        });

    [Fact]
    public async Task ValidProposal_UsesRealIdsAndStopsAtAwaitingApproval()
    {
        var (context, connection) = await CreateContextAsync();
        await using (context)
        await using (connection)
        {
            var result = await new AgentProposalPersistenceService(context)
                .PersistAsync(1, Proposal(), 0);

            var itinerary = await context.Itineraries.SingleAsync();
            var booking = await context.Bookings.Include(b => b.BookingItems).SingleAsync();

            Assert.Equal(1, itinerary.TripRequestId);
            Assert.Equal("cust-1", itinerary.CustomerId);
            Assert.True(itinerary.Id > 0);
            Assert.Equal(itinerary.Id, booking.ItineraryId);
            Assert.Equal(result.ItineraryId, booking.ItineraryId);
            Assert.Equal(BookingStatus.AwaitingApproval, booking.Status);
            Assert.NotEmpty(booking.BookingReference);
            Assert.Equal(3, booking.BookingItems.Count);
            Assert.All(booking.BookingItems, item => Assert.Equal(booking.Id, item.BookingId));
            Assert.Equal(TripRequestStatus.AwaitingApproval, (await context.TripRequests.SingleAsync()).Status);
        }
    }

    [Fact]
    public async Task DuplicateCallback_ReturnsExistingRecordsWithoutDuplicates()
    {
        var (context, connection) = await CreateContextAsync();
        await using (context)
        await using (connection)
        {
            var service = new AgentProposalPersistenceService(context);
            var first = await service.PersistAsync(1, Proposal(), 0);
            var second = await service.PersistAsync(1, Proposal(), 0);

            Assert.True(second.AlreadyPersisted);
            Assert.Equal(first.ItineraryId, second.ItineraryId);
            Assert.Equal(first.BookingId, second.BookingId);
            Assert.Equal(1, await context.Itineraries.CountAsync());
            Assert.Equal(1, await context.Bookings.CountAsync());
        }
    }

    [Fact]
    public async Task InvalidTour_RollsBackItineraryAndBooking()
    {
        var (context, connection) = await CreateContextAsync();
        await using (context)
        await using (connection)
        {
            await Assert.ThrowsAsync<ProposalPersistenceException>(() =>
                new AgentProposalPersistenceService(context).PersistAsync(1, Proposal(tourId: 999), 0));

            Assert.Empty(await context.Itineraries.ToListAsync());
            Assert.Empty(await context.Bookings.ToListAsync());
            Assert.Equal(TripRequestStatus.Planning, (await context.TripRequests.SingleAsync()).Status);
        }
    }

    [Fact]
    public async Task CancelledTrip_RejectsLateAgentCallbackWithoutCreatingCommercialRecords()
    {
        var (context, connection) = await CreateContextAsync(TripRequestStatus.Cancelled);
        await using (context)
        await using (connection)
        {
            var ex = await Assert.ThrowsAsync<ProposalPersistenceException>(() =>
                new AgentProposalPersistenceService(context).PersistAsync(1, Proposal(), 0));

            Assert.Equal("INVALID_TRIP_STATE", ex.Code);
            Assert.Empty(await context.Itineraries.ToListAsync());
            Assert.Empty(await context.Bookings.ToListAsync());
            Assert.Equal(TripRequestStatus.Cancelled, (await context.TripRequests.SingleAsync()).Status);
        }
    }

    [Fact]
    public async Task OverBudgetProposal_DoesNotPersistCommercialRecords()
    {
        var (context, connection) = await CreateContextAsync(budget: 100m);
        await using (context)
        await using (connection)
        {
            await Assert.ThrowsAsync<ProposalPersistenceException>(() =>
                new AgentProposalPersistenceService(context).PersistAsync(1, Proposal(), 0));

            Assert.Empty(await context.Itineraries.ToListAsync());
            Assert.Empty(await context.Bookings.ToListAsync());
        }
    }

    [Fact]
    public async Task InvalidRoom_DoesNotPersistCommercialRecords()
    {
        var (context, connection) = await CreateContextAsync();
        await using (context)
        await using (connection)
        {
            await Assert.ThrowsAsync<ProposalPersistenceException>(() =>
                new AgentProposalPersistenceService(context).PersistAsync(1, Proposal(roomId: 999), 0));

            Assert.Empty(await context.Itineraries.ToListAsync());
            Assert.Empty(await context.Bookings.ToListAsync());
        }
    }

    [Fact]
    public async Task MismatchedCustomer_DoesNotPersistCommercialRecords()
    {
        var (context, connection) = await CreateContextAsync();
        await using (context)
        await using (connection)
        {
            await Assert.ThrowsAsync<ProposalPersistenceException>(() =>
                new AgentProposalPersistenceService(context).PersistAsync(1, Proposal(customerId: "customer-2"), 0));

            Assert.Empty(await context.Itineraries.ToListAsync());
            Assert.Empty(await context.Bookings.ToListAsync());
        }
    }

    [Fact]
    public async Task AiTotalMismatch_DoesNotPersistCommercialRecords()
    {
        var (context, connection) = await CreateContextAsync();
        await using (context)
        await using (connection)
        {
            await Assert.ThrowsAsync<ProposalPersistenceException>(() =>
                new AgentProposalPersistenceService(context).PersistAsync(1, Proposal(total: 999), 0));

            Assert.Empty(await context.Itineraries.ToListAsync());
            Assert.Empty(await context.Bookings.ToListAsync());
        }
    }
}
