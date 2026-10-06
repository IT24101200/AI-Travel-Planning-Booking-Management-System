using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text.Encodings.Web;
using backend.Data;
using backend.DTOs;
using backend.Models;
using backend.Models.Enums;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace backend.Tests
{
    // -------------------------------------------------------------------------
    //  Custom WebApplicationFactory
    //
    //  Replaces the production PostgreSQL DbContext with an in-process SQLite
    //  database.  SQLite supports real BEGIN/COMMIT/ROLLBACK transactions (unlike
    //  the InMemory provider), which means the application-level capacity check
    //  that runs inside the transaction actually serialises writes correctly.
    //
    //  NOTE: "SELECT ... FOR UPDATE" is a PostgreSQL syntax extension.  SQLite
    //  silently ignores it (it parses as a no-op hint), so the DB-level lock is
    //  NOT exercised in this test.  What the test DOES prove is that the
    //  application-layer guard (capacity re-check inside the transaction) catches
    //  the second concurrent writer and returns a clear 400 -- not a 500 crash,
    //  not a silent duplicate booking.  The FOR UPDATE clause provides the
    //  additional serialisation guarantee in production against PostgreSQL.
    // -------------------------------------------------------------------------
    public class TravelPlanningWebFactory : WebApplicationFactory<Program>
    {
        private readonly string _dbName = $"integration_test_{Guid.NewGuid():N}.db";

        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            builder.UseEnvironment("Testing");

            builder.ConfigureServices(services =>
            {
                // Replace Postgres DbContext with SQLite
                services.RemoveAll<DbContextOptions<AppDbContext>>();
                services.RemoveAll<AppDbContext>();

                services.AddDbContext<AppDbContext>(options =>
                    options.UseSqlite($"Data Source={_dbName};Cache=Shared"));

                // Ensure schema is created
                var sp = services.BuildServiceProvider();
                using var scope = sp.CreateScope();
                var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
                db.Database.EnsureCreated();

                // Override authentication: remove all existing schemes and replace
                // with a stub that always authenticates as "test-customer-1".
                // Without this, the JWT bearer scheme from Program.cs runs first
                // and rejects the test Authorization header with 401.
                services.RemoveAll<IAuthenticationSchemeProvider>();
                services.RemoveAll<IAuthenticationHandlerProvider>();

                services
                    .AddAuthentication(options =>
                    {
                        options.DefaultAuthenticateScheme = "Test";
                        options.DefaultChallengeScheme    = "Test";
                        options.DefaultScheme             = "Test";
                    })
                    .AddScheme<AuthenticationSchemeOptions, TestAuthHandler>(
                        "Test", _ => { });
            });
        }

        protected override void Dispose(bool disposing)
        {
            base.Dispose(disposing);
            // Clean up the SQLite file after all tests in this factory instance.
            if (File.Exists(_dbName))
                try { File.Delete(_dbName); } catch { /* best-effort */ }
        }
    }

    // -------------------------------------------------------------------------
    //  Stub authentication handler -- always authenticates as "test-customer-1"
    //  with role "Customer".  This lets the test hit [Authorize] endpoints
    //  without issuing a real JWT.
    // -------------------------------------------------------------------------
    public class TestAuthHandler : AuthenticationHandler<AuthenticationSchemeOptions>
    {
        public TestAuthHandler(
            IOptionsMonitor<AuthenticationSchemeOptions> options,
            ILoggerFactory logger,
            UrlEncoder encoder)
            : base(options, logger, encoder) { }

        protected override Task<AuthenticateResult> HandleAuthenticateAsync()
        {
            var claims = new[]
            {
                new Claim(ClaimTypes.NameIdentifier, "test-customer-1"),
                new Claim(ClaimTypes.Name, "Test User"),
                new Claim(ClaimTypes.Role, "Customer")
            };
            var identity = new ClaimsIdentity(claims, "Test");
            var principal = new ClaimsPrincipal(identity);
            var ticket = new AuthenticationTicket(principal, "Test");
            return Task.FromResult(AuthenticateResult.Success(ticket));
        }
    }

    // -------------------------------------------------------------------------
    //  Shared seed helper
    // -------------------------------------------------------------------------
    internal static class SeedHelper
    {
        internal static async Task SeedAsync(AppDbContext db)
        {
            if (db.Customers.Any()) return; // already seeded

            // Customer
            db.Customers.Add(new Customer
            {
                Id = "test-customer-1",
                FullName = "Integration Test User",
                JoinedAt = DateTime.UtcNow
            });

            // TripRequest
            db.TripRequests.Add(new TripRequest
            {
                Id = 1,
                CustomerId = "test-customer-1",
                RawRequestText = "Integration test trip",
                Status = TripRequestStatus.Planning
            });

            // Itinerary
            db.Itineraries.Add(new Itinerary
            {
                Id = 1,
                CustomerId = "test-customer-1",
                TripRequestId = 1,
                StartDate = DateTime.UtcNow,
                EndDate = DateTime.UtcNow.AddDays(7),
                Status = ItineraryStatus.Proposed,
                TotalEstimatedCost = 200
            });

            // Destination (required FK for Hotel)
            db.Destinations.Add(new Destination
            {
                Id = 1,
                Name = "Test Destination",
                Country = "Testland"
            });

            // Hotel (required FK for Room)
            db.Hotels.Add(new Hotel
            {
                Id = 1,
                Name = "Test Hotel",
                DestinationId = 1,
                StarRating = 3
            });

            // Room with TotalRooms = 1 -- exactly one unit, the race target
            db.Rooms.Add(new Room
            {
                Id = 1,
                HotelId = 1,
                RoomType = "Single",
                Capacity = 2,
                TotalRooms = 1,       // only one room available
                PricePerNight = 100,
                Currency = "USD"
            });

            // TransportOption with Capacity = 1 -- exactly one seat
            db.TransportOptions.Add(new TransportOption
            {
                Id = 1,
                Type = TransportType.Flight,
                Provider = "Test Airlines",
                RouteFrom = "CMB",
                RouteTo = "LHR",
                DepartureTime = DateTime.UtcNow.AddDays(1),
                ArrivalTime = DateTime.UtcNow.AddDays(1).AddHours(10),
                Capacity = 1,         // only one seat available
                Price = 500,
                Currency = "USD",
                Status = TransportStatus.Active
            });

            await db.SaveChangesAsync();
        }
    }

    // -------------------------------------------------------------------------
    //  The actual integration tests
    // -------------------------------------------------------------------------
    public class ConcurrentBookingIntegrationTests : IClassFixture<TravelPlanningWebFactory>
    {
        private readonly TravelPlanningWebFactory _factory;

        public ConcurrentBookingIntegrationTests(TravelPlanningWebFactory factory)
        {
            _factory = factory;
        }

        // Helper: create a pre-configured HttpClient
        private HttpClient CreateClient()
        {
            var client = _factory.CreateClient();
            // The TestAuthHandler ignores the token value; the presence of the
            // Authorization header is enough to trigger the stub scheme.
            client.DefaultRequestHeaders.Authorization =
                new AuthenticationHeaderValue("Test", "token");
            return client;
        }

        // Helper: seed DB via the factory's DI scope
        private async Task SeedDatabaseAsync()
        {
            using var scope = _factory.Services.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            await SeedHelper.SeedAsync(db);
        }

        // ---------------------------------------------------------------------
        //  TEST 1 -- Two concurrent requests for the last available Room
        //
        //  Asserts:
        //  - Exactly one 201 Created
        //  - Exactly one 400 Bad Request (capacity exhausted, clear error body)
        //  - No 5xx crashes
        //  - Database contains exactly one BookingItem for RoomId=1
        // ---------------------------------------------------------------------
        [Fact]
        public async Task ConcurrentRoom_LastUnit_ExactlyOneSucceeds()
        {
            await SeedDatabaseAsync();

            var checkIn  = DateTime.UtcNow.Date.AddDays(10);
            var checkOut = checkIn.AddDays(3);

            var payload = new BookingCreateDto
            {
                CustomerId  = "test-customer-1",
                ItineraryId = 1,
                TotalCost   = 300,
                Currency    = "USD",
                Items       = new List<BookingItemCreateDto>
                {
                    new BookingItemCreateDto
                    {
                        ItemType     = BookingItemType.Room,
                        RoomId       = 1,
                        CheckInDate  = checkIn,
                        CheckOutDate = checkOut,
                        Quantity     = 1,
                        UnitPrice    = 100
                    }
                }
            };

            // Fire both requests simultaneously
            var client1 = CreateClient();
            var client2 = CreateClient();

            var task1 = client1.PostAsJsonAsync("/api/booking", payload);
            var task2 = client2.PostAsJsonAsync("/api/booking", payload);

            var results = await Task.WhenAll(task1, task2);

            var statuses = results.Select(r => (int)r.StatusCode).OrderBy(s => s).ToArray();
            var body1 = await results[0].Content.ReadAsStringAsync();
            var body2 = await results[1].Content.ReadAsStringAsync();

            Console.WriteLine($"[ConcurrentRoom] Response 1: {(int)results[0].StatusCode}  Body: {body1}");
            Console.WriteLine($"[ConcurrentRoom] Response 2: {(int)results[1].StatusCode}  Body: {body2}");

            // Core assertion: exactly one success, exactly one failure
            var successCount = results.Count(r =>
                r.StatusCode == HttpStatusCode.Created ||
                r.StatusCode == HttpStatusCode.OK);

            var failureCount = results.Count(r =>
                r.StatusCode == HttpStatusCode.BadRequest ||
                r.StatusCode == HttpStatusCode.Conflict);

            Assert.True(successCount == 1,
                $"Expected exactly 1 success (201/200) but got {successCount}. " +
                $"Statuses: [{string.Join(", ", statuses)}]");

            Assert.True(failureCount == 1,
                $"Expected exactly 1 failure (400/409) but got {failureCount}. " +
                $"Statuses: [{string.Join(", ", statuses)}]");

            // Verify no 5xx crashes occurred
            Assert.False(
                results.Any(r => (int)r.StatusCode >= 500),
                "A 5xx server error means the guard threw an unhandled exception.");

            // Verify the DB has exactly one booking item for this room
            using var scope = _factory.Services.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var roomBookings = await db.BookingItems
                .Where(bi => bi.RoomId == 1 && bi.ItemType == BookingItemType.Room)
                .CountAsync();

            Assert.Equal(1, roomBookings);
        }

        // ---------------------------------------------------------------------
        //  TEST 2 -- Two concurrent requests for the last available seat on a
        //  TransportOption (Capacity = 1).
        //
        //  Asserts:
        //  - Exactly one 201 Created
        //  - Exactly one 400 Bad Request (capacity exhausted, clear error body)
        //  - No 5xx crashes
        //  - Database contains exactly one BookingItem for TransportOptionId=1
        // ---------------------------------------------------------------------
        [Fact]
        public async Task ConcurrentTransport_LastSeat_ExactlyOneSucceeds()
        {
            await SeedDatabaseAsync();

            var payload = new BookingCreateDto
            {
                CustomerId  = "test-customer-1",
                ItineraryId = 1,
                TotalCost   = 500,
                Currency    = "USD",
                Items       = new List<BookingItemCreateDto>
                {
                    new BookingItemCreateDto
                    {
                        ItemType          = BookingItemType.Transport,
                        TransportOptionId = 1,
                        Quantity          = 1,
                        UnitPrice         = 500
                    }
                }
            };

            // Fire both requests simultaneously
            var client1 = CreateClient();
            var client2 = CreateClient();

            var task1 = client1.PostAsJsonAsync("/api/booking", payload);
            var task2 = client2.PostAsJsonAsync("/api/booking", payload);

            var results = await Task.WhenAll(task1, task2);

            var statuses = results.Select(r => (int)r.StatusCode).OrderBy(s => s).ToArray();
            var body1 = await results[0].Content.ReadAsStringAsync();
            var body2 = await results[1].Content.ReadAsStringAsync();

            Console.WriteLine($"[ConcurrentTransport] Response 1: {(int)results[0].StatusCode}  Body: {body1}");
            Console.WriteLine($"[ConcurrentTransport] Response 2: {(int)results[1].StatusCode}  Body: {body2}");

            // Core assertion: exactly one success, exactly one failure
            var successCount = results.Count(r =>
                r.StatusCode == HttpStatusCode.Created ||
                r.StatusCode == HttpStatusCode.OK);

            var failureCount = results.Count(r =>
                r.StatusCode == HttpStatusCode.BadRequest ||
                r.StatusCode == HttpStatusCode.Conflict);

            Assert.True(successCount == 1,
                $"Expected exactly 1 success (201/200) but got {successCount}. " +
                $"Statuses: [{string.Join(", ", statuses)}]");

            Assert.True(failureCount == 1,
                $"Expected exactly 1 failure (400/409) but got {failureCount}. " +
                $"Statuses: [{string.Join(", ", statuses)}]");

            // Verify no 5xx crashes occurred
            Assert.False(
                results.Any(r => (int)r.StatusCode >= 500),
                "A 5xx server error means the guard threw an unhandled exception.");

            // Verify the DB has exactly one booking item for this transport option
            using var scope = _factory.Services.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var transportBookings = await db.BookingItems
                .Where(bi => bi.TransportOptionId == 1
                          && bi.ItemType == BookingItemType.Transport)
                .CountAsync();

            Assert.Equal(1, transportBookings);
        }
    }
}
