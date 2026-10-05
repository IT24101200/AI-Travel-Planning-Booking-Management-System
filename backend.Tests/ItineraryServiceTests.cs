using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using backend.Data;
using backend.DTOs;
using backend.Models;
using backend.Models.Enums;
using backend.Services;

namespace backend.Tests
{
    public class ItineraryServiceTests
    {
        private static AppDbContext CreateContext()
        {
            var options = new DbContextOptionsBuilder<AppDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString())
                .Options;

            return new AppDbContext(options);
        }

        private static async Task<(AppDbContext context, ItineraryService service, int itineraryId, int tourId)>
            SeedAsync()
        {
            var context = CreateContext();

            context.Destinations.Add(new Destination
            {
                Id      = 1,
                Name    = "Test Destination",
                Country = "Test Country"
            });

            var tour = new Tour
            {
                Id               = 1,
                DestinationId    = 1,
                Name             = "City Walk",
                Category         = "Sightseeing",
                Price            = 50,
                Currency         = "USD",
                DurationHours    = 2,
                DefaultStartTime = TimeSpan.Zero,
                Status           = "Active"
            };
            context.Tours.Add(tour);

            var itinerary = new Itinerary
            {
                Id            = 1,
                CustomerId    = "test-customer-1",
                TripRequestId = 1,
                StartDate     = DateTime.UtcNow.Date,
                EndDate       = DateTime.UtcNow.Date.AddDays(5),
                Status        = ItineraryStatus.Draft,
                Currency      = "USD"
            };
            context.Itineraries.Add(itinerary);

            await context.SaveChangesAsync();

            var service = new ItineraryService(context);
            return (context, service, itinerary.Id, tour.Id);
        }

        [Fact]
        public async Task ReadItineraries_ProjectCustomerNameAndTravellerCount()
        {
            var (context, service, itineraryId, _) = await SeedAsync();
            context.Customers.Add(new Customer { Id = "test-customer-1", FullName = "Asha Perera" });
            context.TripRequests.Add(new TripRequest
            {
                Id = 1,
                CustomerId = "test-customer-1",
                RawRequestText = "Plan a trip",
                StartDate = DateTime.UtcNow.Date,
                EndDate = DateTime.UtcNow.Date.AddDays(5),
                TravellerCount = 3
            });
            await context.SaveChangesAsync();
            context.ChangeTracker.Clear();

            var detail = await service.GetItineraryByIdAsync(itineraryId);
            var review = await service.GetAllItinerariesAsync();
            var customerList = await service.GetItinerariesByCustomerAsync("test-customer-1");

            Assert.Equal("Asha Perera", detail?.CustomerName);
            Assert.Equal(3, detail?.TravellerCount);
            Assert.Equal("Asha Perera", Assert.Single(review).CustomerName);
            Assert.Equal(3, Assert.Single(review).TravellerCount);
            Assert.Equal("Asha Perera", Assert.Single(customerList).CustomerName);
            Assert.Equal(3, Assert.Single(customerList).TravellerCount);
        }

        [Fact]
        public async Task ReadItinerary_MissingRelatedRows_ReturnsNullDetails()
        {
            var (context, service, itineraryId, _) = await SeedAsync();
            context.ChangeTracker.Clear();

            var detail = await service.GetItineraryByIdAsync(itineraryId);
            var review = await service.GetAllItinerariesAsync();

            Assert.NotNull(detail);
            Assert.Null(detail.CustomerName);
            Assert.Null(detail.TravellerCount);
            Assert.Null(Assert.Single(review).TravellerCount);
        }

        [Fact]
        public async Task ReadItineraries_SQLiteProjectsRelatedDetailsAndItems()
        {
            await using var connection = new SqliteConnection("Data Source=:memory:");
            await connection.OpenAsync();
            var options = new DbContextOptionsBuilder<AppDbContext>()
                .UseSqlite(connection)
                .Options;
            await using var context = new AppDbContext(options);
            await context.Database.EnsureCreatedAsync();

            context.Customers.Add(new Customer { Id = "customer-1", FullName = "Asha Perera" });
            context.TripRequests.Add(new TripRequest
            {
                Id = 1,
                CustomerId = "customer-1",
                RawRequestText = "Plan a trip",
                StartDate = DateTime.UtcNow.Date,
                EndDate = DateTime.UtcNow.Date.AddDays(2),
                TravellerCount = 3
            });
            context.Itineraries.Add(new Itinerary
            {
                Id = 1,
                CustomerId = "customer-1",
                TripRequestId = 1,
                StartDate = DateTime.UtcNow.Date,
                EndDate = DateTime.UtcNow.Date.AddDays(2)
            });
            context.Destinations.Add(new Destination
            {
                Id = 1,
                Name = "Test Destination",
                Country = "Test Country"
            });
            context.Tours.Add(new Tour
            {
                Id = 1,
                DestinationId = 1,
                Name = "City Walk",
                Category = "Sightseeing",
                Price = 50,
                Currency = "USD",
                DurationHours = 2,
                DefaultStartTime = TimeSpan.Zero,
                Status = "Active"
            });
            context.ItineraryItems.Add(new ItineraryItem
            {
                Id = 1,
                ItineraryId = 1,
                TourId = 1,
                DayNumber = 1,
                SequenceOrder = 1,
                StartTime = new TimeSpan(9, 0, 0),
                EndTime = new TimeSpan(11, 0, 0),
                PriceAtSelection = 50
            });
            await context.SaveChangesAsync();
            context.ChangeTracker.Clear();

            var service = new ItineraryService(context);
            var detail = await service.GetItineraryByIdAsync(1);
            var review = await service.GetAllItinerariesAsync();

            Assert.Equal("Asha Perera", detail?.CustomerName);
            Assert.Equal(3, detail?.TravellerCount);
            Assert.Equal("City Walk", Assert.Single(detail!.Items).TourName);
            Assert.Equal("Asha Perera", Assert.Single(review).CustomerName);
            Assert.Equal(3, Assert.Single(review).TravellerCount);
        }

        [Fact]
        public async Task AddItemToItineraryAsync_NoOverlap_Succeeds()
        {
            // Arrange
            var (_, service, itineraryId, tourId) = await SeedAsync();

            var dto = new ItineraryItemCreateDto
            {
                TourId        = tourId,
                DayNumber     = 1,
                SequenceOrder = 1,
                StartTime     = new TimeSpan(9, 0, 0),
                EndTime       = new TimeSpan(11, 0, 0)
            };

            // Act
            var (success, errorMessage, data) = await service.AddItemToItineraryAsync(itineraryId, dto);

            // Assert
            Assert.True(success);
            Assert.Null(errorMessage);
            Assert.NotNull(data);
            Assert.Single(data!.Items);
        }

        [Fact]
        public async Task AddItemToItineraryAsync_OverlappingTimeOnSameDay_IsRejected()
        {
            // Arrange
            var (_, service, itineraryId, tourId) = await SeedAsync();

            var firstItem = new ItineraryItemCreateDto
            {
                TourId        = tourId,
                DayNumber     = 1,
                SequenceOrder = 1,
                StartTime     = new TimeSpan(9, 0, 0),
                EndTime       = new TimeSpan(11, 0, 0)
            };
            var firstResult = await service.AddItemToItineraryAsync(itineraryId, firstItem);
            Assert.True(firstResult.Success); // sanity check the first add worked

            // Act — second item overlaps: 10:00–12:00 overlaps 09:00–11:00
            var overlappingItem = new ItineraryItemCreateDto
            {
                TourId        = tourId,
                DayNumber     = 1,
                SequenceOrder = 2,
                StartTime     = new TimeSpan(10, 0, 0),
                EndTime       = new TimeSpan(12, 0, 0)
            };
            var (success, errorMessage, data) = await service.AddItemToItineraryAsync(itineraryId, overlappingItem);

            // Assert
            Assert.False(success);
            Assert.NotNull(errorMessage);
            Assert.Contains("conflict", errorMessage!.ToLower());
            Assert.Null(data);
        }

        [Fact]
        public async Task AddItemToItineraryAsync_SameTimeDifferentDay_Succeeds()
        {
            // Arrange
            var (_, service, itineraryId, tourId) = await SeedAsync();

            var dayOneItem = new ItineraryItemCreateDto
            {
                TourId        = tourId,
                DayNumber     = 1,
                SequenceOrder = 1,
                StartTime     = new TimeSpan(9, 0, 0),
                EndTime       = new TimeSpan(11, 0, 0)
            };
            await service.AddItemToItineraryAsync(itineraryId, dayOneItem);

            // Act — same time range, but DayNumber = 2, so it should NOT conflict
            var dayTwoItem = new ItineraryItemCreateDto
            {
                TourId        = tourId,
                DayNumber     = 2,
                SequenceOrder = 1,
                StartTime     = new TimeSpan(9, 0, 0),
                EndTime       = new TimeSpan(11, 0, 0)
            };
            var (success, errorMessage, data) = await service.AddItemToItineraryAsync(itineraryId, dayTwoItem);

            // Assert
            Assert.True(success);
            Assert.Null(errorMessage);
            Assert.Equal(2, data!.Items.Count);
        }
    }
}
