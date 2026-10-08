using System.Text.Json;
using System.Text.Json.Nodes;
using backend.Data;
using backend.DTOs;
using backend.Models;
using backend.Models.Enums;
using backend.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Moq;

namespace backend.Tests;

public class ItineraryChangeTests
{
    private sealed class RouteHandler : HttpMessageHandler
    {
        public Uri? Requested { get; private set; }
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
        {
            Requested = request.RequestUri;
            return Task.FromResult(new HttpResponseMessage(System.Net.HttpStatusCode.OK) {
                Content = new StringContent("{\"code\":\"Ok\",\"distances\":[[15000,15001,null]]}") });
        }
    }

    [Fact]
    public async Task RoadDistancesUseKilometresAndExcludeUnreachableOrMissingLocations()
    {
        var handler = new RouteHandler();
        var factory = new Mock<IHttpClientFactory>();
        factory.Setup(f => f.CreateClient(It.IsAny<string>())).Returns(() => new HttpClient(handler));
        var origin = new Hotel { Id = 10, Latitude = 7, Longitude = 80 };
        var distances = await new HotelRoadDistanceService(factory.Object, new ConfigurationBuilder().Build()).FromHotelAsync(origin,
            new[] { origin, new Hotel { Id = 11, Latitude = 7, Longitude = 80.1 }, new Hotel { Id = 12, Latitude = 7, Longitude = 80.2 },
                new Hotel { Id = 13, Latitude = 7, Longitude = 80.3 }, new Hotel { Id = 14 } }, default);
        Assert.Equal(0, distances[10]);
        Assert.Equal(15, distances[11]);
        Assert.Equal(15.001, distances[12], 3);
        Assert.False(distances.ContainsKey(13));
        Assert.False(distances.ContainsKey(14));
        Assert.Contains("/table/v1/driving/80,7;80.1,7;80.2,7;80.3,7", handler.Requested!.AbsoluteUri);
        Assert.Contains("annotations=distance", handler.Requested.Query);
    }

    private sealed class Roads : IHotelRoadDistanceService
    {
        public Task<Dictionary<int, double>> FromHotelAsync(Hotel origin, IReadOnlyList<Hotel> hotels, CancellationToken ct) =>
            Task.FromResult(new Dictionary<int, double> { [10] = 0, [11] = 15, [12] = 15.01 });
    }
    private sealed class Planner(bool fail = false) : IRevisionPlanningService
    {
        public bool Called { get; private set; }
        public Task TriggerAsync(int id, string comment, string auth, CancellationToken ct = default)
        {
            Called = true;
            if (fail) throw new HttpRequestException("Offline");
            return Task.CompletedTask;
        }
    }
    private static ItineraryChangeService Service(AppDbContext db, Planner? planner = null) =>
        new(db, new Roads(), planner ?? new Planner(), new CurrencyConversionService());

    private static async Task<int> SeedAsync(AppDbContext db)
    {
        var proposal = JsonNode.Parse(AgentProposalPersistenceTests.Proposal().GetRawText())!;
        proposal["itinerary"]!["route_destination_ids"] = new JsonArray(1);
        proposal["itinerary"]!["schedule"]![0]!["travel_minutes"] = 30;
        proposal["itinerary"]!["schedule"]![0]!["day_end_time"] = "17:00:00";
        var result = await new AgentProposalPersistenceService(db).PersistAsync(1, JsonSerializer.SerializeToElement(proposal), 0);
        db.Hotels.AddRange(new Hotel { Id = 11, DestinationId = 1, Name = "Nearby", Status = HotelStatus.Active },
            new Hotel { Id = 12, DestinationId = 1, Name = "Too far", Status = HotelStatus.Active });
        db.Rooms.AddRange(new Room { Id = 21, HotelId = 11, Capacity = 2, TotalRooms = 1, RoomType = "Double", PricePerNight = 75, Currency = "USD" },
            new Room { Id = 22, HotelId = 12, Capacity = 2, TotalRooms = 1, RoomType = "Double", PricePerNight = 60, Currency = "USD" },
            new Room { Id = 23, HotelId = 11, Capacity = 1, TotalRooms = 1, RoomType = "Single", PricePerNight = 40, Currency = "USD" });
        var current = await db.TransportOptions.SingleAsync();
        foreach (var id in new[] { 31, 32, 33, 34 })
            db.TransportOptions.Add(new TransportOption { Id = id, Provider = "Alternative", Type = id == 32 ? TransportType.Bus : current.Type,
                RouteFrom = current.RouteFrom, RouteTo = id == 33 ? "Other city" : current.RouteTo,
                DepartureTime = current.DepartureTime.AddDays(id == 34 ? 1 : 0), ArrivalTime = current.ArrivalTime.AddDays(id == 34 ? 1 : 0),
                Capacity = 4, Price = 30, Currency = "USD", Status = TransportStatus.Active });
        await db.SaveChangesAsync();
        return result.ItineraryId;
    }

    [Fact]
    public async Task OptionsRespectRoadBoundaryCapacityRouteDateTypeAndOwnership()
    {
        var (db, connection) = await AgentProposalPersistenceTests.CreateContextAsync();
        await using (db) await using (connection)
        {
            var id = await SeedAsync(db);
            var options = await Service(db).OptionsAsync(id, "cust-1");
            Assert.Equal(new[] { 20, 21 }, options.Hotels.Single().Options.Select(o => o.RoomId));
            Assert.Equal(150m, options.Hotels.Single().Options.Single(o => o.RoomId == 21).Total);
            Assert.Equal(new[] { 30, 31 }, options.Transports.Single().Options.Select(o => o.TransportOptionId));
            await Assert.ThrowsAsync<KeyNotFoundException>(() => Service(db).OptionsAsync(id, "someone-else"));
        }
    }

    [Theory]
    [InlineData(22)]
    [InlineData(23)]
    public async Task RejectsForgedOutOfRangeOrUndersizedRoom(int roomId)
    {
        var (db, connection) = await AgentProposalPersistenceTests.CreateContextAsync();
        await using (db) await using (connection)
        {
            var id = await SeedAsync(db);
            var roomItem = await db.BookingItems.SingleAsync(i => i.ItemType == BookingItemType.Room);
            await Assert.ThrowsAsync<ArgumentException>(() => Service(db).RequestAsync(id, "cust-1",
                new() { Hotels = new() { new() { BookingItemId = roomItem.Id, RoomId = roomId } } }, "Bearer test"));
            Assert.Null(CustomerRevisionContract.Read(await db.TripRequests.SingleAsync()));
        }
    }

    [Fact]
    public async Task RevisionKeepsOriginalUntilValidResultThenReplacesItOnce()
    {
        var (db, connection) = await AgentProposalPersistenceTests.CreateContextAsync();
        await using (db) await using (connection)
        {
            var id = await SeedAsync(db);
            var planner = new Planner();
            var room = await db.BookingItems.SingleAsync(i => i.ItemType == BookingItemType.Room);
            var transport = await db.BookingItems.SingleAsync(i => i.ItemType == BookingItemType.Transport);
            await Service(db, planner).RequestAsync(id, "cust-1", new() { Notes = "Quieter hotel",
                Hotels = new() { new() { BookingItemId = room.Id, RoomId = 21 } },
                Transports = new() { new() { BookingItemId = transport.Id, TransportOptionId = 31 } } }, "Bearer test");
            Assert.True(planner.Called);
            var original = await db.Bookings.SingleAsync();
            Assert.Equal(BookingStatus.AwaitingApproval, original.Status);
            var trip = await db.TripRequests.SingleAsync();
            var pending = CustomerRevisionContract.Read(trip)!;
            Assert.True(CustomerRevisionContract.Pending(pending));
            var root = JsonNode.Parse(trip.PlanJson!)!;
            root["booking_details"]!["selected_room"]!["room_id"] = 21;
            root["booking_details"]!["selected_transport"]!["transport_id"] = 31;
            root["booking_details"]!["total_package_cost"] = 410;
            var proposal = JsonSerializer.SerializeToElement(root);
            var service = new AgentProposalPersistenceService(db);
            var result = await service.PersistAsync(1, proposal, 0);
            Assert.NotEqual(id, result.ItineraryId);
            Assert.Equal(BookingStatus.Cancelled, original.Status);
            Assert.Equal(ItineraryStatus.Discarded, (await db.Itineraries.SingleAsync(i => i.Id == id)).Status);
            var revised = await db.Bookings.Include(b => b.BookingItems).SingleAsync(b => b.Id == result.BookingId);
            Assert.Equal(410m, revised.TotalCost);
            Assert.Contains(revised.BookingItems, i => i.RoomId == 21);
            Assert.Contains(revised.BookingItems, i => i.TransportOptionId == 31);
            Assert.True((await service.PersistAsync(1, proposal, 0)).AlreadyPersisted);
            Assert.Equal(2, await db.Bookings.CountAsync());
            Assert.Equal("Applied", CustomerRevisionContract.Read(trip)!["status"]!.GetValue<string>());
        }
    }

    [Fact]
    public async Task InvalidOrStaleCallbackCannotChangeCurrentBookingAndFailureRestoresOriginal()
    {
        var (db, connection) = await AgentProposalPersistenceTests.CreateContextAsync();
        await using (db) await using (connection)
        {
            var id = await SeedAsync(db);
            var room = await db.BookingItems.SingleAsync(i => i.ItemType == BookingItemType.Room);
            await Service(db).RequestAsync(id, "cust-1", new() { Hotels = new() { new() { BookingItemId = room.Id, RoomId = 21 } } }, "Bearer test");
            var trip = await db.TripRequests.SingleAsync();
            var proposal = JsonSerializer.SerializeToElement(JsonNode.Parse(trip.PlanJson!));
            var service = new AgentProposalPersistenceService(db);
            Assert.Equal("REVISION_SELECTION_MISMATCH", (await Assert.ThrowsAsync<ProposalPersistenceException>(() => service.PersistAsync(1, proposal, 0))).Code);
            Assert.Equal("STALE_REVISION", (await Assert.ThrowsAsync<ProposalPersistenceException>(() => service.PersistAsync(1, AgentProposalPersistenceTests.Proposal(), 0))).Code);
            Assert.Equal(BookingStatus.AwaitingApproval, (await db.Bookings.SingleAsync()).Status);
            await new TripRequestService(db).UpdateAgentPlanAsync(1, new() { Status = "Failed", FailureReason = "Selected timetable does not fit", PlanJson = proposal });
            Assert.Equal(TripRequestStatus.AwaitingApproval, trip.Status);
            Assert.Equal("Failed", CustomerRevisionContract.Read(trip)!["status"]!.GetValue<string>());
            Assert.Equal(20, (await db.BookingItems.SingleAsync(i => i.ItemType == BookingItemType.Room)).RoomId);
            Assert.Contains("Selected timetable", trip.FailureReason);
            Assert.Single(await db.Itineraries.ToListAsync());
        }
    }

    [Fact]
    public async Task PendingRevisionBlocksPaymentAndApprovalOfOriginalProposal()
    {
        var (db, connection) = await AgentProposalPersistenceTests.CreateContextAsync();
        await using (db) await using (connection)
        {
            var id = await SeedAsync(db);
            var booking = await db.Bookings.SingleAsync();
            await Service(db).RequestAsync(id, "cust-1", new() { Notes = "Please revise" }, "Bearer test");
            var approvalError = await Assert.ThrowsAsync<InvalidOperationException>(() => new ApprovalService(db, null!).CreateApprovalAsync("staff", new() {
                BookingId = booking.Id, Decision = ApprovalDecision.Approved }));
            Assert.Contains("customer requested changes", approvalError.Message);
            var gateway = new Mock<IStripePaymentGateway>(MockBehavior.Strict);
            var paymentError = await Assert.ThrowsAsync<InvalidOperationException>(() => new PaymentService(db, new ConfigurationBuilder().Build(), gateway.Object)
                .ProcessPaymentAsync(new() { BookingId = booking.Id, PaymentMethodId = "pm_test" }));
            Assert.Contains("change request", paymentError.Message);
            Assert.Empty(await db.Payments.ToListAsync());
            Assert.Empty(await db.BookingApprovals.ToListAsync());
        }
    }

    [Fact]
    public async Task OwnConfirmedReservationDoesNotBlockKeepingExistingInventory()
    {
        var (db, connection) = await AgentProposalPersistenceTests.CreateContextAsync();
        await using (db) await using (connection)
        {
            var id = await SeedAsync(db);
            var original = await db.Bookings.SingleAsync();
            original.Status = BookingStatus.Confirmed;
            (await db.Rooms.SingleAsync(r => r.Id == 20)).TotalRooms = 1;
            (await db.TransportOptions.SingleAsync(t => t.Id == 30)).Capacity = 2;
            var trip = await db.TripRequests.SingleAsync();
            trip.Status = TripRequestStatus.Approved;
            await db.SaveChangesAsync();
            var options = await Service(db).OptionsAsync(id, "cust-1");
            Assert.Contains(options.Hotels.Single().Options, o => o.RoomId == 20);
            Assert.Contains(options.Transports.Single().Options, o => o.TransportOptionId == 30);
            await Service(db).RequestAsync(id, "cust-1", new() { Notes = "Recheck travel schedule, keep these choices" }, "Bearer test");
            var result = await new AgentProposalPersistenceService(db).PersistAsync(1, JsonSerializer.SerializeToElement(JsonNode.Parse(trip.PlanJson!)), 0);
            Assert.NotEqual(original.Id, result.BookingId);
            Assert.Equal(BookingStatus.Cancelled, original.Status);
        }
    }

    [Fact]
    public async Task DispatchFailureRollsBackRequestAndPaymentsBlockChanges()
    {
        var (db, connection) = await AgentProposalPersistenceTests.CreateContextAsync();
        await using (db) await using (connection)
        {
            var id = await SeedAsync(db);
            await Assert.ThrowsAsync<HttpRequestException>(() => Service(db, new Planner(true)).RequestAsync(id, "cust-1", new() { Notes = "Please revise" }, "Bearer test"));
            db.ChangeTracker.Clear();
            var trip = await db.TripRequests.SingleAsync();
            Assert.Null(CustomerRevisionContract.Read(trip));
            Assert.Equal(TripRequestStatus.AwaitingApproval, trip.Status);
            var booking = await db.Bookings.SingleAsync();
            db.Payments.Add(new Payment { BookingId = booking.Id, Amount = booking.TotalCost, Currency = "USD", Status = PaymentStatus.Paid });
            await db.SaveChangesAsync();
            await Assert.ThrowsAsync<InvalidOperationException>(() => Service(db).OptionsAsync(id, "cust-1"));
        }
    }
}
