using Microsoft.EntityFrameworkCore;
using backend.Data;
using backend.Models;
using backend.Services;

namespace backend.Tests
{
    public class TourServiceTests
    {
        private static AppDbContext CreateContext()
        {
            var options = new DbContextOptionsBuilder<AppDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString())
                .Options;

            return new AppDbContext(options);
        }

        [Fact]
        public async Task SearchAsync_FiltersByCategory_ReturnsOnlyMatchingTours()
        {
            // Arrange
            using var context = CreateContext();

            // Seed a Destination so the foreign key constraint is satisfied
            context.Destinations.Add(new Destination
            {
                Id        = 1,
                Name      = "Test Destination",
                Country   = "Test Country"
            });

            // Seed 3 tours:
            // 1. Active Sightseeing  — should be returned
            // 2. Active Adventure    — excluded by category filter
            // 3. Inactive Sightseeing — excluded by default "Active" status filter
            context.Tours.AddRange(
                new Tour
                {
                    Name             = "City Walk",
                    Category         = "Sightseeing",
                    Status           = "Active",
                    DestinationId    = 1,
                    Currency         = "USD",
                    DefaultStartTime = TimeSpan.Zero
                },
                new Tour
                {
                    Name             = "Rock Climbing",
                    Category         = "Adventure",
                    Status           = "Active",
                    DestinationId    = 1,
                    Currency         = "USD",
                    DefaultStartTime = TimeSpan.Zero
                },
                new Tour
                {
                    Name             = "Museum Tour",
                    Category         = "Sightseeing",
                    Status           = "Inactive",
                    DestinationId    = 1,
                    Currency         = "USD",
                    DefaultStartTime = TimeSpan.Zero
                }
            );

            await context.SaveChangesAsync();

            var service = new TourService(context);

            // Act — status is null, so SearchAsync defaults to "Active"
            var results = await service.SearchAsync(
                destinationId: null,
                category: "Sightseeing",
                minPrice: null,
                maxPrice: null,
                status: null,
                page: 1,
                pageSize: 10);

            // Assert — only the Active Sightseeing tour should be returned
            Assert.Single(results);
            Assert.Equal("City Walk", results[0].Name);
            Assert.Equal("Sightseeing", results[0].Category);
            Assert.Equal("Active", results[0].Status);
        }
    }
}
