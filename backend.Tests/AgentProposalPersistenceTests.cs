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
            RouteFrom = "Pickup Point",
            RouteTo = "Test Destination",
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
        string customerId = "cust-1",
        bool includeSecondDestination = false)
    {
        object[] schedule = includeSecondDestination
            ? new object[]
            {
                new
                {
                    day_number = 1,
                    items = new object[]
                    {
                        new { tour_id = tourId, start_time = "09:00:00", end_time = "11:00:00" }
                    }
                },
                new
                {
                    day_number = 2,
                    items = new object[]
                    {
                        new { tour_id = 101, start_time = "09:00:00", end_time = "11:00:00" }
                    }
                }
            }
            : new object[]
            {
                new
                {
                    day_number = 1,
                    items = new object[]
                    {
                        new { tour_id = tourId, start_time = "09:00:00", end_time = "11:00:00" }
                    }
                }
            };

        return JsonSerializer.SerializeToElement(new
        {
            trip_request_id = 1,
            customer_id = customerId,
            itinerary = new { schedule },
            booking_details = new
            {
                total_package_cost = total,
                currency = "USD",
                selected_room = new { room_id = roomId },
                selected_transport = new { transport_id = transportId }
            },
            validation = new { is_valid = true }
        });
    }

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
            var transportItem = booking.BookingItems.Single(item => item.ItemType == BookingItemType.Transport);
            Assert.Equal("Car", transportItem.TransportTypeSnapshot);
            Assert.Equal("Test Transport", transportItem.TransportProviderSnapshot);
            Assert.Equal("Pickup Point", transportItem.TransportRouteFromSnapshot);
            Assert.Equal("Test Destination", transportItem.TransportRouteToSnapshot);
            Assert.Equal(new DateTime(2026, 10, 10, 8, 0, 0), transportItem.TransportDepartureTimeSnapshot);
            Assert.Equal(TripRequestStatus.AwaitingApproval, (await context.TripRequests.SingleAsync()).Status);
            var notification = await context.Notifications.SingleAsync();
            Assert.Equal(MessageType.TripPlanningReady, notification.MessageType);
            Assert.Equal("TripRequest", notification.ReferenceType);
            Assert.Equal("1", notification.ReferenceId);
            Assert.StartsWith("trip:1:planning-ready:", notification.EventKey);
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
            Assert.Equal(1, await context.Notifications.CountAsync());
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

    [Fact]
    public async Task WrongTransportRoute_IsRejectedWithStableCode()
    {
        var (context, connection) = await CreateContextAsync();
        await using (context)
        await using (connection)
        {
            context.TransportOptions.Add(new TransportOption
            {
                Id = 31,
                Type = TransportType.Bus,
                Provider = "Wrong Route",
                RouteFrom = "Unrelated City",
                RouteTo = "Other City",
                DepartureTime = new DateTime(2026, 10, 10, 8, 0, 0),
                ArrivalTime = new DateTime(2026, 10, 10, 10, 0, 0),
                Capacity = 5,
                Price = 20m,
                Currency = "USD",
                Status = TransportStatus.Active
            });
            await context.SaveChangesAsync();

            var ex = await Assert.ThrowsAsync<ProposalPersistenceException>(() =>
                new AgentProposalPersistenceService(context).PersistAsync(1, Proposal(transportId: 31), 0));

            Assert.Equal("TRANSPORT_ROUTE_INCOMPATIBLE", ex.Code);
            Assert.Empty(await context.Bookings.ToListAsync());
        }
    }

    [Fact]
    public async Task TransportOutsideTripDates_IsRejectedWithStableCode()
    {
        var (context, connection) = await CreateContextAsync();
        await using (context)
        await using (connection)
        {
            context.TransportOptions.Add(new TransportOption
            {
                Id = 32,
                Type = TransportType.Bus,
                Provider = "Late Transport",
                RouteFrom = "Pickup Point",
                RouteTo = "Test Destination",
                DepartureTime = new DateTime(2026, 10, 13, 8, 0, 0),
                ArrivalTime = new DateTime(2026, 10, 13, 10, 0, 0),
                Capacity = 5,
                Price = 20m,
                Currency = "USD",
                Status = TransportStatus.Active
            });
            await context.SaveChangesAsync();

            var ex = await Assert.ThrowsAsync<ProposalPersistenceException>(() =>
                new AgentProposalPersistenceService(context).PersistAsync(1, Proposal(transportId: 32), 0));

            Assert.Equal("TRANSPORT_DATE_INCOMPATIBLE", ex.Code);
            Assert.Empty(await context.Bookings.ToListAsync());
        }
    }

    [Fact]
    public async Task AdjacentMultiDestinationTransportLeg_IsAccepted()
    {
        var (context, connection) = await CreateContextAsync();
        await using (context)
        await using (connection)
        {
            context.Destinations.Add(new Destination
            {
                Id = 2,
                Name = "Second Destination",
                Country = "Sri Lanka"
            });
            context.Tours.Add(new Tour
            {
                Id = 101,
                DestinationId = 2,
                Name = "Second Tour",
                Category = "Test",
                Price = 100m,
                Currency = "USD",
                Status = "Active",
                DefaultStartTime = new TimeSpan(9, 0, 0),
                DurationHours = 2
            });
            var trip = await context.TripRequests.SingleAsync();
            trip.DestinationSelectionsJson = JsonSerializer.Serialize(new[]
            {
                new { Id = 1, Name = "client supplied name", Order = 0 },
                new { Id = 2, Name = "Second Destination", Order = 1 }
            });
            var transport = await context.TransportOptions.SingleAsync();
            transport.RouteFrom = "Test Destination";
            transport.RouteTo = "Second Destination";
            await context.SaveChangesAsync();

            var result = await new AgentProposalPersistenceService(context)
                .PersistAsync(1, Proposal(total: 550m, includeSecondDestination: true), 0);

            Assert.False(result.AlreadyPersisted);
            Assert.Single(await context.Bookings.ToListAsync());
        }
    }

    [Fact]
    public async Task UnrelatedMultiDestinationTransportLeg_IsRejected()
    {
        var (context, connection) = await CreateContextAsync();
        await using (context)
        await using (connection)
        {
            context.Destinations.Add(new Destination
            {
                Id = 2,
                Name = "Second Destination",
                Country = "Sri Lanka"
            });
            context.TransportOptions.Add(new TransportOption
            {
                Id = 33,
                Type = TransportType.Bus,
                Provider = "Unrelated Transport",
                RouteFrom = "X",
                RouteTo = "Y",
                DepartureTime = new DateTime(2026, 10, 10, 8, 0, 0),
                ArrivalTime = new DateTime(2026, 10, 10, 10, 0, 0),
                Capacity = 5,
                Price = 20m,
                Currency = "USD",
                Status = TransportStatus.Active
            });
            context.Tours.Add(new Tour
            {
                Id = 101,
                DestinationId = 2,
                Name = "Second Tour",
                Category = "Test",
                Price = 100m,
                Currency = "USD",
                Status = "Active",
                DefaultStartTime = new TimeSpan(9, 0, 0),
                DurationHours = 2
            });
            var trip = await context.TripRequests.SingleAsync();
            trip.DestinationSelectionsJson = JsonSerializer.Serialize(new[]
            {
                new { Id = 1, Name = "ignored", Order = 0 },
                new { Id = 2, Name = "ignored", Order = 1 }
            });
            await context.SaveChangesAsync();

            var ex = await Assert.ThrowsAsync<ProposalPersistenceException>(() =>
                new AgentProposalPersistenceService(context)
                    .PersistAsync(1, Proposal(transportId: 33, total: 550m, includeSecondDestination: true), 0));

            Assert.Equal("TRANSPORT_ROUTE_INCOMPATIBLE", ex.Code);
        }
    }

    [Fact]
    public async Task UnresolvableDestinationMappingFailsClosed()
    {
        var (context, connection) = await CreateContextAsync();
        await using (context)
        await using (connection)
        {
            var trip = await context.TripRequests.SingleAsync();
            trip.DestinationId = null;
            trip.DestinationSelectionsJson = "not-json";
            await context.SaveChangesAsync();

            var ex = await Assert.ThrowsAsync<ProposalPersistenceException>(() =>
                new AgentProposalPersistenceService(context).PersistAsync(1, Proposal(), 0));

            Assert.Equal("TRANSPORT_SEGMENT_UNRESOLVED", ex.Code);
        }
    }

    [Fact]
    public async Task TransportArrivalOutsideTripDates_IsRejected()
    {
        var (context, connection) = await CreateContextAsync();
        await using (context)
        await using (connection)
        {
            context.TransportOptions.Add(new TransportOption
            {
                Id = 34,
                Type = TransportType.Bus,
                Provider = "Overnight Transport",
                RouteFrom = "Pickup Point",
                RouteTo = "Test Destination",
                DepartureTime = new DateTime(2026, 10, 12, 23, 0, 0),
                ArrivalTime = new DateTime(2026, 10, 13, 1, 0, 0),
                Capacity = 5,
                Price = 20m,
                Currency = "USD",
                Status = TransportStatus.Active
            });
            await context.SaveChangesAsync();

            var ex = await Assert.ThrowsAsync<ProposalPersistenceException>(() =>
                new AgentProposalPersistenceService(context).PersistAsync(1, Proposal(transportId: 34), 0));

            Assert.Equal("TRANSPORT_DATE_INCOMPATIBLE", ex.Code);
        }
    }
}
