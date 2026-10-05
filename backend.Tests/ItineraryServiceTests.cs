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

        private static async Task<(AppDbContext context, ItineraryService service, int itineraryId)>
            SeedStatusAsync(ItineraryStatus status, bool withItem = false)
        {
            var (context, service, itineraryId, tourId) = await SeedAsync();
            var itinerary = await context.Itineraries.FindAsync(itineraryId);
            itinerary!.Status = status;

            if (withItem)
            {
                context.ItineraryItems.Add(new ItineraryItem
                {
                    Id = 1,
                    ItineraryId = itineraryId,
                    TourId = tourId,
                    DayNumber = 1,
                    SequenceOrder = 1,
                    StartTime = new TimeSpan(9, 0, 0),
                    EndTime = new TimeSpan(11, 0, 0),
                    PriceAtSelection = 50
                });
            }

            await context.SaveChangesAsync();
            context.ChangeTracker.Clear();
            return (context, service, itineraryId);
        }

        [Theory]
        [InlineData(true, ItineraryStatus.Draft, ItineraryStatus.Proposed, true)]
        [InlineData(true, ItineraryStatus.Draft, ItineraryStatus.Draft, false)]
        [InlineData(true, ItineraryStatus.Proposed, ItineraryStatus.Draft, false)]
        [InlineData(true, ItineraryStatus.Draft, ItineraryStatus.Discarded, false)]
        [InlineData(true, ItineraryStatus.Proposed, ItineraryStatus.Discarded, false)]
        [InlineData(false, ItineraryStatus.Proposed, ItineraryStatus.Accepted, false)]
        [InlineData(false, ItineraryStatus.Proposed, ItineraryStatus.Draft, false)]
        [InlineData(false, ItineraryStatus.Draft, ItineraryStatus.Discarded, false)]
        [InlineData(false, ItineraryStatus.Proposed, ItineraryStatus.Discarded, false)]
        public async Task UpdateStatus_AllAllowedTransitions_SaveStatus(
            bool isStaff, ItineraryStatus from, ItineraryStatus to, bool withItem)
        {
            var (context, service, itineraryId) = await SeedStatusAsync(from, withItem);

            var result = await service.UpdateItineraryStatusAsync(
                itineraryId, to.ToString(), isStaff ? null : "test-customer-1", isStaff);

            Assert.Equal(ItineraryStatusUpdateOutcome.Updated, result.Outcome);
            context.ChangeTracker.Clear();
            Assert.Equal(to, (await context.Itineraries.FindAsync(itineraryId))!.Status);
        }

        [Theory]
        [InlineData(ItineraryStatus.Draft)]
        [InlineData(ItineraryStatus.Proposed)]
        public async Task UpdateStatus_StaffCannotAccept(ItineraryStatus from)
        {
            var (context, service, itineraryId) = await SeedStatusAsync(from, true);

            var result = await service.UpdateItineraryStatusAsync(itineraryId, "Accepted", null, true);

            Assert.Equal(ItineraryStatusUpdateOutcome.Forbidden, result.Outcome);
            Assert.Equal(from, (await context.Itineraries.FindAsync(itineraryId))!.Status);
        }

        [Fact]
        public async Task UpdateStatus_CannotProposeDraftWithoutActivities()
        {
            var (context, service, itineraryId) = await SeedStatusAsync(ItineraryStatus.Draft);

            var result = await service.UpdateItineraryStatusAsync(itineraryId, "Proposed", null, true);

            Assert.Equal(ItineraryStatusUpdateOutcome.Invalid, result.Outcome);
            Assert.Equal("Cannot approve an itinerary with no activities.", result.Message);
            Assert.Equal(ItineraryStatus.Draft, (await context.Itineraries.FindAsync(itineraryId))!.Status);
        }

        [Theory]
        [InlineData(ItineraryStatus.Accepted, true)]
        [InlineData(ItineraryStatus.Accepted, false)]
        [InlineData(ItineraryStatus.Discarded, true)]
        [InlineData(ItineraryStatus.Discarded, false)]
        public async Task UpdateStatus_FinalStatesCannotChange(ItineraryStatus from, bool isStaff)
        {
            var (context, service, itineraryId) = await SeedStatusAsync(from);

            var result = await service.UpdateItineraryStatusAsync(
                itineraryId, "Draft", isStaff ? null : "test-customer-1", isStaff);

            Assert.Equal(ItineraryStatusUpdateOutcome.Invalid, result.Outcome);
            Assert.Equal(from, (await context.Itineraries.FindAsync(itineraryId))!.Status);
        }

        [Fact]
        public async Task UpdateStatus_CustomerCannotAcceptSomeoneElsesItinerary()
        {
            var (context, service, itineraryId) = await SeedStatusAsync(ItineraryStatus.Proposed);

            var result = await service.UpdateItineraryStatusAsync(itineraryId, "Accepted", "other-customer", false);

            Assert.Equal(ItineraryStatusUpdateOutcome.Forbidden, result.Outcome);
            Assert.Equal(ItineraryStatus.Proposed, (await context.Itineraries.FindAsync(itineraryId))!.Status);
        }

        [Theory]
        [InlineData("Approve")]
        [InlineData("")]
        [InlineData("999")]
        [InlineData("Draft, Proposed")]
        public async Task UpdateStatus_InvalidStatusTextIsRejected(string status)
        {
            var (context, service, itineraryId) = await SeedStatusAsync(ItineraryStatus.Draft, true);

            var result = await service.UpdateItineraryStatusAsync(itineraryId, status, null, true);

            Assert.Equal(ItineraryStatusUpdateOutcome.Invalid, result.Outcome);
            Assert.Equal(ItineraryStatus.Draft, (await context.Itineraries.FindAsync(itineraryId))!.Status);
        }

        [Theory]
        [InlineData(true, ItineraryStatus.Proposed, "Proposed")]
        [InlineData(false, ItineraryStatus.Draft, "Accepted")]
        [InlineData(false, ItineraryStatus.Draft, "Proposed")]
        [InlineData(false, ItineraryStatus.Proposed, "Proposed")]
        public async Task UpdateStatus_OtherTransitionsAreRejected(
            bool isStaff, ItineraryStatus from, string target)
        {
            var (context, service, itineraryId) = await SeedStatusAsync(from, true);

            var result = await service.UpdateItineraryStatusAsync(
                itineraryId, target, isStaff ? null : "test-customer-1", isStaff);

            Assert.Equal(ItineraryStatusUpdateOutcome.Invalid, result.Outcome);
            Assert.Equal(from, (await context.Itineraries.FindAsync(itineraryId))!.Status);
        }

        [Fact]
        public async Task UpdateStatus_MissingItineraryIsNotFound()
        {
            var (_, service, _) = await SeedStatusAsync(ItineraryStatus.Draft);

            var result = await service.UpdateItineraryStatusAsync(999, "Proposed", null, true);

            Assert.Equal(ItineraryStatusUpdateOutcome.NotFound, result.Outcome);
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
