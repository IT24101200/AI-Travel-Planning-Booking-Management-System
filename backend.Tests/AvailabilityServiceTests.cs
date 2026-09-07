using Microsoft.EntityFrameworkCore;
using backend.Data;
using backend.Models;
using backend.Services;

namespace backend.Tests
{
    public class AvailabilityServiceTests
    {
        private static AppDbContext CreateContext()
        {
            var options = new DbContextOptionsBuilder<AppDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString())
                .Options;

            return new AppDbContext(options);
        }

        [Fact]
        public async Task CheckRoomAvailabilityAsync_RoomExists_ReturnsAvailability()
        {
            // Arrange
            using var context = CreateContext();
            
            context.Destinations.Add(new Destination { Id = 1, Name = "Test Dest", Country = "Test Country" });
            context.Hotels.Add(new Hotel { Id = 1, DestinationId = 1, Name = "Test Hotel" });
            context.Rooms.Add(new Room { Id = 1, HotelId = 1, RoomType = "Standard", TotalRooms = 10, PricePerNight = 100 });
            await context.SaveChangesAsync();

            var service = new AvailabilityService(context);
            var checkIn = DateTime.UtcNow.AddDays(1);
            var checkOut = DateTime.UtcNow.AddDays(5);

            // Act
            var result = await service.CheckRoomAvailabilityAsync(1, checkIn, checkOut);

            // Assert
            Assert.NotNull(result);
            Assert.Equal(1, result.RoomId);
            Assert.Equal(10, result.TotalRooms);
            // Phase 1 check: booked rooms is 0
            Assert.Equal(0, result.BookedRooms);
            Assert.Equal(10, result.AvailableRooms);
            Assert.Equal(100, result.PricePerNight);
        }

        [Fact]
        public async Task CheckRoomAvailabilityAsync_RoomDoesNotExist_ReturnsNull()
        {
            // Arrange
            using var context = CreateContext();
            var service = new AvailabilityService(context);
            
            // Act
            var result = await service.CheckRoomAvailabilityAsync(999, DateTime.UtcNow, DateTime.UtcNow.AddDays(2));

            // Assert
            Assert.Null(result);
        }

        [Fact]
        public async Task CheckTransportAvailabilityAsync_TransportExists_ReturnsAvailability()
        {
            // Arrange
            using var context = CreateContext();
            
            context.TransportOptions.Add(new TransportOption 
            { 
                Id = 1, 
                Type = backend.Models.Enums.TransportType.Bus,
                Provider = "Test Bus",
                RouteFrom = "A",
                RouteTo = "B",
                Capacity = 40,
                Price = 50,
                DepartureTime = DateTime.UtcNow.AddDays(1),
                ArrivalTime = DateTime.UtcNow.AddDays(1).AddHours(2)
            });
            await context.SaveChangesAsync();

            var service = new AvailabilityService(context);

            // Act
            var result = await service.CheckTransportAvailabilityAsync(1);

            // Assert
            Assert.NotNull(result);
            Assert.Equal(1, result.TransportOptionId);
            Assert.Equal(40, result.TotalCapacity);
            Assert.Equal(0, result.BookedSeats);
            Assert.Equal(40, result.AvailableSeats);
            Assert.Equal(50, result.Price);
        }

        [Fact]
        public async Task CheckTransportAvailabilityAsync_TransportDoesNotExist_ReturnsNull()
        {
            // Arrange
            using var context = CreateContext();
            var service = new AvailabilityService(context);
            
            // Act
            var result = await service.CheckTransportAvailabilityAsync(999);

            // Assert
            Assert.Null(result);
        }
    }
}
