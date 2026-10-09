using System.Text.Json;
using backend.Data;
using backend.Models;
using backend.Models.Enums;
using backend.Services;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Metadata;

namespace backend.Tests;

public class AgentProposalPersistenceTests
{
    [Theory]
    [InlineData(600, "20:00:00", true)]
    [InlineData(601, "20:00:00", false)]
    [InlineData(600, "20:01:00", false)]
    public async Task DailyDrivingLimitIsTenHoursWithTwentyHundredFinish(int minutes, string endTime, bool valid)
    {
        var (context, connection) = await CreateContextAsync();
        await using (context)
        await using (connection)
        {
            var node = System.Text.Json.Nodes.JsonNode.Parse(Proposal().GetRawText())!;
            node["itinerary"]!["route_destination_ids"] = System.Text.Json.Nodes.JsonNode.Parse("[1]");
            foreach (var day in node["itinerary"]!["schedule"]!.AsArray())
            {
                day!["travel_minutes"] = minutes;
                day["day_end_time"] = endTime;
            }
            var service = new AgentProposalPersistenceService(context);
            if (valid)
                await service.PersistAsync(1, JsonSerializer.SerializeToElement(node), 0);
            else
            {
                var error = await Assert.ThrowsAsync<ProposalPersistenceException>(() =>
                    service.PersistAsync(1, JsonSerializer.SerializeToElement(node), 0));
                Assert.Equal("TRAVEL_TIME_INFEASIBLE", error.Code);
                Assert.Empty(await context.Bookings.ToListAsync());
            }
        }
    }

    [Fact]
    public async Task StarterPreservingOptimizedDestinationOrderIsPersisted()
    {
        var (context, connection) = await CreateThreeDestinationContextAsync();
        await using (context)
        await using (connection)
        {
            var node = System.Text.Json.Nodes.JsonNode.Parse(ThreeDestinationProposal().GetRawText())!;
            var itinerary = node["itinerary"]!;
            itinerary["route_destination_ids"] = System.Text.Json.Nodes.JsonNode.Parse("[1,3,2]");
            itinerary["schedule"]![1]!["items"]![0]!["tour_id"] = 102;
            itinerary["schedule"]![2]!["items"]![0]!["tour_id"] = 101;
            var firstLeg = await context.TransportOptions.SingleAsync(option => option.Id == 30);
            firstLeg.RouteTo = "Third Destination";
            firstLeg.DepartureTime = new DateTime(2026, 10, 10, 12, 0, 0);
            firstLeg.ArrivalTime = new DateTime(2026, 10, 10, 15, 0, 0);
            var secondLeg = await context.TransportOptions.SingleAsync(option => option.Id == 31);
            secondLeg.RouteFrom = "Third Destination";
            secondLeg.RouteTo = "Second Destination";
            secondLeg.DepartureTime = new DateTime(2026, 10, 11, 12, 0, 0);
            secondLeg.ArrivalTime = new DateTime(2026, 10, 11, 15, 0, 0);
            foreach (var day in itinerary["schedule"]!.AsArray())
            {
                day!["travel_minutes"] = 120;
                day["day_end_time"] = "17:00:00";
            }
            await new AgentProposalPersistenceService(context).PersistAsync(1, JsonSerializer.SerializeToElement(node), 0);

            var transportItems = await context.BookingItems
                .Where(item => item.ItemType == BookingItemType.Transport)
                .OrderBy(item => item.TransportLegIndex)
                .ToListAsync();
            Assert.Equal(new[] { "Test Destination", "Third Destination" },
                transportItems.Select(item => item.TransportRouteFromSnapshot));
            Assert.Equal(new[] { "Third Destination", "Second Destination" },
                transportItems.Select(item => item.TransportRouteToSnapshot));
        }
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task RouteThatChangesTheSelectedStarterIsRejected(bool airportPickup)
    {
        var (context, connection) = await CreateThreeDestinationContextAsync();
        await using (context)
        await using (connection)
        {
            (await context.TripRequests.SingleAsync()).AirportPickup = airportPickup;
            var node = System.Text.Json.Nodes.JsonNode.Parse(ThreeDestinationProposal().GetRawText())!;
            node["itinerary"]!["route_destination_ids"] = System.Text.Json.Nodes.JsonNode.Parse("[2,1,3]");

            var error = await Assert.ThrowsAsync<ProposalPersistenceException>(() =>
                new AgentProposalPersistenceService(context).PersistAsync(1, JsonSerializer.SerializeToElement(node), 0));
            Assert.Equal("DESTINATION_ORDER_CONTRACT_MISMATCH", error.Code);
            Assert.Empty(await context.Bookings.ToListAsync());
        }
    }

    [Fact]
    public async Task RouteMayStartAtAnyRequestedDestinationWhenStarterWasNotSelected()
    {
        var (context, connection) = await CreateThreeDestinationContextAsync();
        await using (context)
        await using (connection)
        {
            var trip = await context.TripRequests.SingleAsync();
            trip.DestinationSelectionsJson = JsonSerializer.Serialize(new[]
            {
                new { Id = 1, Name = "ignored", Order = 0 },
                new { Id = 2, Name = "ignored", Order = 1 },
                new { Id = 3, Name = "ignored", Order = 2 }
            });

            var node = System.Text.Json.Nodes.JsonNode.Parse(ThreeDestinationProposal().GetRawText())!;
            var itinerary = node["itinerary"]!;
            itinerary["route_destination_ids"] = System.Text.Json.Nodes.JsonNode.Parse("[2,3,1]");
            itinerary["schedule"]![0]!["items"]![0]!["tour_id"] = 101;
            itinerary["schedule"]![1]!["items"]![0]!["tour_id"] = 102;
            itinerary["schedule"]![2]!["items"]![0]!["tour_id"] = 100;
            var firstLeg = await context.TransportOptions.SingleAsync(option => option.Id == 30);
            firstLeg.RouteFrom = "Second Destination";
            firstLeg.RouteTo = "Third Destination";
            firstLeg.DepartureTime = new DateTime(2026, 10, 10, 12, 0, 0);
            firstLeg.ArrivalTime = new DateTime(2026, 10, 10, 15, 0, 0);
            var secondLeg = await context.TransportOptions.SingleAsync(option => option.Id == 31);
            secondLeg.RouteFrom = "Third Destination";
            secondLeg.RouteTo = "Test Destination";
            secondLeg.DepartureTime = new DateTime(2026, 10, 11, 12, 0, 0);
            secondLeg.ArrivalTime = new DateTime(2026, 10, 11, 15, 0, 0);
            foreach (var day in itinerary["schedule"]!.AsArray())
            {
                day!["travel_minutes"] = 120;
                day["day_end_time"] = "17:00:00";
            }
            await context.SaveChangesAsync();

            await new AgentProposalPersistenceService(context)
                .PersistAsync(1, JsonSerializer.SerializeToElement(node), 0);

            Assert.Single(await context.Bookings.ToListAsync());
        }
    }

    [Fact]
    public async Task RequestedOrderPlanRejectsTransportDepartingBeforeSourceVisitsFinish()
    {
        var (context, connection) = await CreateThreeDestinationContextAsync();
        await using (context)
        await using (connection)
        {
            var node = System.Text.Json.Nodes.JsonNode.Parse(ThreeDestinationProposal().GetRawText())!;
            node["itinerary"]!["route_destination_ids"] = System.Text.Json.Nodes.JsonNode.Parse("[1,2,3]");
            foreach (var day in node["itinerary"]!["schedule"]!.AsArray())
            {
                day!["travel_minutes"] = 120;
                day["day_end_time"] = "17:00:00";
            }
            var error = await Assert.ThrowsAsync<ProposalPersistenceException>(() =>
                new AgentProposalPersistenceService(context).PersistAsync(1, JsonSerializer.SerializeToElement(node), 0));
            Assert.Equal("TRANSPORT_TIMETABLE_INFEASIBLE", error.Code);
            Assert.Empty(await context.Bookings.ToListAsync());
        }
    }

    [Fact]
    public async Task MultipleHotelStaysPersistTheirOwnDatesAndTrustedPrices()
    {
        var (context, connection) = await CreateContextAsync();
        await using (context)
        await using (connection)
        {
            context.Hotels.Add(new Hotel { Id = 11, DestinationId = 1, Name = "Second Hotel", Status = HotelStatus.Active });
            context.Rooms.Add(new Room { Id = 21, HotelId = 11, RoomType = "Double", Capacity = 2, TotalRooms = 3, PricePerNight = 75m, Currency = "USD" });
            await context.SaveChangesAsync();
            var node = System.Text.Json.Nodes.JsonNode.Parse(Proposal(total: 375m).GetRawText())!;
            node["booking_details"]!["room_selections"] = System.Text.Json.Nodes.JsonNode.Parse("""
                [{"room_id":20,"check_in":"2026-10-10","check_out":"2026-10-11"},
                 {"room_id":21,"check_in":"2026-10-11","check_out":"2026-10-12"}]
                """);
            await new AgentProposalPersistenceService(context).PersistAsync(1, JsonSerializer.SerializeToElement(node), 0);
            var stays = await context.BookingItems.Where(item => item.ItemType == BookingItemType.Room).OrderBy(item => item.CheckInDate).ToListAsync();
            Assert.Equal(2, stays.Count);
            Assert.Equal(new decimal[] { 50m, 75m }, stays.Select(item => item.Subtotal));
            Assert.Equal(stays[0].CheckOutDate, stays[1].CheckInDate);
            Assert.Equal(375m, (await context.Bookings.SingleAsync()).TotalCost);
            var booking = await context.Bookings.SingleAsync();
            var response = await new BookingService(context).GetBookingByIdAsync(booking.Id, "cust-1");
            var displayedStays = response!.BookingItems.Where(item => item.ItemType == BookingItemType.Room)
                .OrderBy(item => item.CheckInDate).ToList();
            Assert.Equal(2, displayedStays.Count);
            Assert.Equal(stays.Select(item => item.RoomId), displayedStays.Select(item => item.RoomId));
            Assert.Equal(stays.Select(item => item.CheckInDate), displayedStays.Select(item => item.CheckInDate));
            Assert.Equal(stays.Select(item => item.CheckOutDate), displayedStays.Select(item => item.CheckOutDate));
            Assert.Equal(stays.Select(item => item.Subtotal), displayedStays.Select(item => item.Subtotal));
            Assert.All(displayedStays, item => Assert.False(string.IsNullOrWhiteSpace(item.HotelName)));
        }
    }

    [Fact]
    public async Task HotelStayGapIsRejectedWithoutPartialBooking()
    {
        var (context, connection) = await CreateContextAsync();
        await using (context)
        await using (connection)
        {
            var node = System.Text.Json.Nodes.JsonNode.Parse(Proposal().GetRawText())!;
            node["booking_details"]!["room_selections"] = System.Text.Json.Nodes.JsonNode.Parse("""
                [{"room_id":20,"check_in":"2026-10-10","check_out":"2026-10-11"}]
                """);
            var error = await Assert.ThrowsAsync<ProposalPersistenceException>(() =>
                new AgentProposalPersistenceService(context).PersistAsync(1, JsonSerializer.SerializeToElement(node), 0));
            Assert.Equal("INVALID_ROOM_STAYS", error.Code);
            Assert.Empty(await context.Bookings.ToListAsync());
        }
    }

    [Fact]
    public async Task AirportPickupRequiresAnIndexedAirportTransfer()
    {
        var (context, connection) = await CreateContextAsync();
        await using (context)
        await using (connection)
        {
            var trip = await context.TripRequests.SingleAsync();
            trip.AirportPickup = true;
            var transport = await context.TransportOptions.SingleAsync();
            transport.RouteFrom = TransportCompatibility.AirportName("CMB");
            await context.SaveChangesAsync();
            var node = System.Text.Json.Nodes.JsonNode.Parse(Proposal().GetRawText())!;
            node["booking_details"]!["transport_selections"] = System.Text.Json.Nodes.JsonNode.Parse("""
                [{"leg_index":0,"transport_option_id":30}]
                """);
            await new AgentProposalPersistenceService(context).PersistAsync(1, JsonSerializer.SerializeToElement(node), 0);
            var transfer = await context.BookingItems.SingleAsync(item => item.ItemType == BookingItemType.Transport);
            Assert.Equal(0, transfer.TransportLegIndex);
            Assert.Equal(TransportCompatibility.AirportName("CMB"), transfer.TransportRouteFromSnapshot);
        }
    }

    private static async Task<(AppDbContext Context, SqliteConnection Connection)> CreateThreeDestinationContextAsync()
    {
        var (context, connection) = await CreateContextAsync();
        context.Destinations.AddRange(
            new Destination { Id = 2, Name = "Second Destination", Country = "Sri Lanka" },
            new Destination { Id = 3, Name = "Third Destination", Country = "Sri Lanka" });
        context.Tours.AddRange(
            new Tour
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
            },
            new Tour
            {
                Id = 102,
                DestinationId = 3,
                Name = "Third Tour",
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
            new { Id = 1, Name = "ignored", Order = 0, IsStarter = true },
            new { Id = 2, Name = "ignored", Order = 1, IsStarter = false },
            new { Id = 3, Name = "ignored", Order = 2, IsStarter = false }
        });
        var firstLeg = await context.TransportOptions.SingleAsync();
        firstLeg.RouteFrom = "Test Destination";
        firstLeg.RouteTo = "Second Destination";
        context.TransportOptions.Add(new TransportOption
        {
            Id = 31,
            Type = TransportType.Van,
            Provider = "Second Leg Transport",
            RouteFrom = "Second Destination",
            RouteTo = "Third Destination",
            DepartureTime = new DateTime(2026, 10, 10, 12, 0, 0),
            ArrivalTime = new DateTime(2026, 10, 10, 15, 0, 0),
            Capacity = 5,
            Price = 35m,
            Currency = "USD",
            Status = TransportStatus.Active
        });
        await context.SaveChangesAsync();
        return (context, connection);
    }

    private static JsonElement ThreeDestinationProposal(int secondTransportId = 31)
    {
        return JsonSerializer.SerializeToElement(new
        {
            trip_request_id = 1,
            customer_id = "cust-1",
            itinerary = new
            {
                schedule = new object[]
                {
                    new { day_number = 1, items = new[] { new { tour_id = 100, start_time = "09:00:00", end_time = "11:00:00" } } },
                    new { day_number = 2, items = new[] { new { tour_id = 101, start_time = "09:00:00", end_time = "11:00:00" } } },
                    new { day_number = 3, items = new[] { new { tour_id = 102, start_time = "09:00:00", end_time = "11:00:00" } } }
                }
            },
            booking_details = new
            {
                total_package_cost = 820m,
                currency = "USD",
                selected_room = new { room_id = 20 },
                transport_selections = new[]
                {
                    new { leg_index = 0, transport_option_id = 30 },
                    new { leg_index = 1, transport_option_id = secondTransportId }
                }
            },
            validation = new { is_valid = true }
        });
    }

    [Fact]
    public void TransportLegIndexModelIsNullableAndHasScopedUniqueIndex()
    {
        using var context = new AppDbContext(
            new DbContextOptionsBuilder<AppDbContext>()
                .UseSqlite("Data Source=:memory:")
                .Options);
        var entity = context.Model.FindEntityType(typeof(BookingItem))!;
        var property = entity.FindProperty(nameof(BookingItem.TransportLegIndex))!;
        var index = entity.GetIndexes().Single(candidate =>
            candidate.Properties.Select(property => property.Name)
                .SequenceEqual(new[] { nameof(BookingItem.BookingId), nameof(BookingItem.TransportLegIndex) }));

        Assert.Equal(typeof(int?), property.ClrType);
        Assert.True(index.IsUnique);
        Assert.Equal(
            "\"TransportLegIndex\" IS NOT NULL AND \"ItemType\" = 'Transport'",
            index.GetFilter());
        var designEntity = context.GetService<IDesignTimeModel>().Model
            .FindEntityType(typeof(BookingItem))!;
        Assert.Contains(
            designEntity.GetCheckConstraints(),
            constraint => constraint.Name == "CK_BookingItems_TransportLegIndex"
                && constraint.Sql.Contains("TransportLegIndex", StringComparison.Ordinal));
    }

    [Fact]
    public async Task ThreeDestinationProposalPersistsOneAuthoritativeTransportItemPerLeg()
    {
        var (context, connection) = await CreateThreeDestinationContextAsync();
        await using (context)
        await using (connection)
        {
            var result = await new AgentProposalPersistenceService(context)
                .PersistAsync(1, ThreeDestinationProposal(), 0);

            var booking = await context.Bookings
                .Include(item => item.BookingItems)
                .SingleAsync();
            var transportItems = booking.BookingItems
                .Where(item => item.ItemType == BookingItemType.Transport)
                .OrderBy(item => item.TransportLegIndex)
                .ToList();

            Assert.Equal(result.BookingId, booking.Id);
            Assert.Equal(2, transportItems.Count);
            Assert.Equal(new int?[] { 0, 1 }, transportItems.Select(item => item.TransportLegIndex).ToArray());
            Assert.Equal(new int?[] { 30, 31 }, transportItems.Select(item => item.TransportOptionId).ToArray());
            Assert.Equal(new[] { "Test Destination", "Second Destination" }, transportItems.Select(item => item.TransportRouteFromSnapshot).ToArray());
            Assert.Equal(new[] { "Second Destination", "Third Destination" }, transportItems.Select(item => item.TransportRouteToSnapshot).ToArray());
            Assert.Equal(new[] { 50m, 70m }, transportItems.Select(item => item.Subtotal).ToArray());
            Assert.Equal(820m, booking.TotalCost);
            // Booking display must use every saved leg, even after catalogue edits.
            var option = await context.TransportOptions.SingleAsync(item => item.Id == 30);
            option.Provider = "Changed catalogue provider";
            option.RouteTo = "Changed catalogue destination";
            option.DepartureTime = option.DepartureTime.AddDays(5);
            option.Price = 999m;
            await context.SaveChangesAsync();
            var response = await new BookingService(context).GetBookingByIdAsync(booking.Id, "cust-1");
            var displayedLegs = response!.BookingItems.Where(item => item.ItemType == BookingItemType.Transport).ToList();
            Assert.Equal(2, displayedLegs.Count);
            Assert.Equal(transportItems.Select(item => item.TransportLegIndex), displayedLegs.Select(item => item.TransportLegIndex));
            Assert.Equal(transportItems.Select(item => item.TransportProviderSnapshot), displayedLegs.Select(item => item.TransportProvider));
            Assert.Equal(transportItems.Select(item => item.TransportRouteFromSnapshot), displayedLegs.Select(item => item.RouteFrom));
            Assert.Equal(transportItems.Select(item => item.TransportRouteToSnapshot), displayedLegs.Select(item => item.RouteTo));
            Assert.Equal(transportItems.Select(item => item.TransportDepartureTimeSnapshot), displayedLegs.Select(item => item.DepartureTime));
            Assert.Equal(transportItems.Select(item => item.TransportArrivalTimeSnapshot), displayedLegs.Select(item => item.ArrivalTime));
            Assert.Equal(transportItems.Select(item => item.Subtotal), displayedLegs.Select(item => item.Subtotal));
        }
    }

    [Fact]
    public async Task InvalidSecondLegDoesNotPersistPartialMultiLegBooking()
    {
        var (context, connection) = await CreateThreeDestinationContextAsync();
        await using (context)
        await using (connection)
        {
            var proposal = ThreeDestinationProposal(secondTransportId: 30);
            var ex = await Assert.ThrowsAsync<ProposalPersistenceException>(() =>
                new AgentProposalPersistenceService(context).PersistAsync(1, proposal, 0));

            Assert.Equal("TRANSPORT_ROUTE_INCOMPATIBLE", ex.Code);
            Assert.Empty(await context.Itineraries.ToListAsync());
            Assert.Empty(await context.Bookings.ToListAsync());
            Assert.Equal(TripRequestStatus.Planning, (await context.TripRequests.SingleAsync()).Status);
        }
    }

    internal static async Task<(AppDbContext Context, SqliteConnection Connection)> CreateContextAsync(
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

    internal static JsonElement Proposal(
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
                selected_transport = new { transport_id = transportId },
                transport_selections = includeSecondDestination
                    ? new[] { new { leg_index = 0, transport_option_id = transportId } }
                    : null
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
    public async Task AdjacentMultiDestinationTransportLeg_PersistsOneOrderedTransportItem()
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

            var booking = await context.Bookings
                .Include(item => item.BookingItems)
                .SingleAsync();
            var transportItem = Assert.Single(
                booking.BookingItems.Where(item => item.ItemType == BookingItemType.Transport));
            Assert.Equal(0, transportItem.TransportLegIndex);
            Assert.Equal(30, transportItem.TransportOptionId);
            Assert.Equal(result.BookingId, booking.Id);
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
                    .PersistAsync(1, Proposal(transportId: 33, total: 540m, includeSecondDestination: true), 0));

            Assert.Equal("TRANSPORT_ROUTE_INCOMPATIBLE", ex.Code);
            Assert.Empty(await context.Bookings.ToListAsync());
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
