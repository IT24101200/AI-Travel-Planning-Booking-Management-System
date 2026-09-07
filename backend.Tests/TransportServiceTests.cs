using Microsoft.EntityFrameworkCore;
using backend.Data;
using backend.Models;
using backend.Services;
using backend.Models.Enums;

namespace backend.Tests
{
    public class TransportServiceTests
    {
        private static AppDbContext CreateContext()
        {
            var options = new DbContextOptionsBuilder<AppDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString())
                .Options;

            return new AppDbContext(options);
        }

        [Fact]
        public async Task SearchAsync_FiltersByType_ReturnsMatchingTransportOptions()
        {
            // Arrange
            using var context = CreateContext();

            context.TransportOptions.AddRange(
                new TransportOption 
                { 
                    Type = TransportType.Flight, Provider = "Air A", RouteFrom = "A", RouteTo = "B", 
                    Price = 100, Capacity = 150, Status = TransportStatus.Active 
                },
                new TransportOption 
                { 
                    Type = TransportType.Bus, Provider = "Bus B", RouteFrom = "A", RouteTo = "B", 
                    Price = 20, Capacity = 40, Status = TransportStatus.Active 
                },
                new TransportOption 
                { 
                    Type = TransportType.Train, Provider = "Train C", RouteFrom = "A", RouteTo = "B", 
                    Price = 50, Capacity = 200, Status = TransportStatus.Inactive 
                }
            );

            await context.SaveChangesAsync();

            var service = new TransportService(context);

            // Act
            // Note: In TransportService, if status is null, it defaults to Active.
            var results = await service.SearchAsync("Bus", null, null, null, null, null, null, false, 1, 10);

            // Assert
            Assert.Single(results);
            Assert.Equal("Bus B", results[0].Provider);
        }

        [Fact]
        public async Task SearchAsync_FiltersByRoute_ReturnsMatchingTransportOptions()
        {
            // Arrange
            using var context = CreateContext();

            context.TransportOptions.AddRange(
                new TransportOption 
                { 
                    Type = TransportType.Flight, Provider = "Air A", RouteFrom = "Colombo", RouteTo = "Kandy", 
                    Price = 100, Capacity = 150, Status = TransportStatus.Active 
                },
                new TransportOption 
                { 
                    Type = TransportType.Flight, Provider = "Air B", RouteFrom = "Kandy", RouteTo = "Galle", 
                    Price = 120, Capacity = 150, Status = TransportStatus.Active 
                }
            );

            await context.SaveChangesAsync();

            var service = new TransportService(context);

            // Act
            var results = await service.SearchAsync(null, "Colombo", null, null, null, null, null, false, 1, 10);

            // Assert
            Assert.Single(results);
            Assert.Equal("Air A", results[0].Provider);
        }
    }
}
