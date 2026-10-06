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
