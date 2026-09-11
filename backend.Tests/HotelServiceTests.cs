using Microsoft.EntityFrameworkCore;
using backend.Data;
using backend.Models;
using backend.Services;
using backend.Models.Enums;

namespace backend.Tests
{
    public class HotelServiceTests
    {
        private static AppDbContext CreateContext()
        {
            var options = new DbContextOptionsBuilder<AppDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString())
                .Options;

            return new AppDbContext(options);
        }

        [Fact]
        public async Task GetAllAsync_FiltersByStarRating_ReturnsOnlyMatchingHotels()
        {
            // Arrange
            using var context = CreateContext();

            context.Destinations.Add(new Destination { Id = 1, Name = "Test", Country = "Test" });

            context.Hotels.AddRange(
                new Hotel { Id = 1, DestinationId = 1, Name = "Cheap Hotel", StarRating = 2, Status = HotelStatus.Active },
                new Hotel { Id = 2, DestinationId = 1, Name = "Luxury Hotel", StarRating = 5, Status = HotelStatus.Active },
                new Hotel { Id = 3, DestinationId = 1, Name = "Mid Hotel", StarRating = 3, Status = HotelStatus.Active }
            );

            await context.SaveChangesAsync();

            var service = new HotelService(context);

            // Act
            var results = await service.GetAllAsync(null, null, 4, null, null, false, 1, 10);

            // Assert
            Assert.Single(results);
            Assert.Equal("Luxury Hotel", results[0].Name);
        }

        [Fact]
        public async Task GetAllAsync_FiltersByDestination_ReturnsMatchingHotels()
        {
            // Arrange
            using var context = CreateContext();

            context.Destinations.Add(new Destination { Id = 1, Name = "Dest1", Country = "Country1" });
            context.Destinations.Add(new Destination { Id = 2, Name = "Dest2", Country = "Country2" });

            context.Hotels.AddRange(
                new Hotel { Id = 1, DestinationId = 1, Name = "Hotel A", StarRating = 4, Status = HotelStatus.Active },
                new Hotel { Id = 2, DestinationId = 2, Name = "Hotel B", StarRating = 4, Status = HotelStatus.Active }
            );

            await context.SaveChangesAsync();

            var service = new HotelService(context);

            // Act
            var results = await service.GetAllAsync(null, 2, null, null, null, false, 1, 10);

            // Assert
            Assert.Single(results);
            Assert.Equal("Hotel B", results[0].Name);
        }
    }
}
