using Microsoft.EntityFrameworkCore;
using backend.Data;
using backend.Models;
using backend.Services;
using backend.Models.Enums;
using Microsoft.AspNetCore.Authorization;
using backend.Controllers;
using System.Reflection;

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

        [Fact]
        public async Task CoverageAsync_ReturnsAvailableCountsForExactRouteAndWindow()
        {
            using var context = CreateContext();
            context.TransportOptions.AddRange(
                new TransportOption
                {
                    Id = 1,
                    Type = TransportType.Bus,
                    Provider = "Approved Bus",
                    RouteFrom = "Batticaloa",
                    RouteTo = "Colombo",
                    DepartureTime = new DateTime(2026, 10, 15, 8, 0, 0),
                    ArrivalTime = new DateTime(2026, 10, 15, 12, 0, 0),
                    Capacity = 12,
                    Price = 100,
                    Status = TransportStatus.Active
                },
                new TransportOption
                {
                    Id = 2,
                    Type = TransportType.Van,
                    Provider = "Inactive Bus",
                    RouteFrom = "Batticaloa",
                    RouteTo = "Colombo",
                    DepartureTime = new DateTime(2026, 10, 15, 9, 0, 0),
                    ArrivalTime = new DateTime(2026, 10, 15, 13, 0, 0),
                    Capacity = 12,
                    Price = 100,
                    Status = TransportStatus.Inactive
                });
            await context.SaveChangesAsync();

            var result = await new TransportService(context).GetCoverageAsync(
                " Batticaloa ",
                "Colombo",
                new DateTime(2026, 10, 15),
                new DateTime(2026, 10, 21),
                3);

            Assert.Equal("COVERAGE_AVAILABLE", result.ReasonCode);
            Assert.Equal(1, result.TotalActive);
            Assert.Equal(1, result.RouteMatches);
            Assert.Equal(1, result.DateMatches);
            Assert.Equal(1, result.CapacityMatches);
            Assert.Equal(1, result.AvailableMatches);
        }

        [Fact]
        public async Task CoverageAsync_ClassifiesRouteDateCapacityAndAvailabilityFailures()
        {
            using var context = CreateContext();
            context.TransportOptions.AddRange(
                new TransportOption
                {
                    Id = 1,
                    Type = TransportType.Bus,
                    Provider = "Wrong Date",
                    RouteFrom = "Colombo",
                    RouteTo = "Ella",
                    DepartureTime = new DateTime(2026, 10, 13, 8, 0, 0),
                    ArrivalTime = new DateTime(2026, 10, 13, 12, 0, 0),
                    Capacity = 12,
                    Price = 100,
                    Status = TransportStatus.Active
                },
                new TransportOption
                {
                    Id = 2,
                    Type = TransportType.Bus,
                    Provider = "Too Small",
                    RouteFrom = "Colombo",
                    RouteTo = "Ella",
                    DepartureTime = new DateTime(2026, 10, 15, 8, 0, 0),
                    ArrivalTime = new DateTime(2026, 10, 15, 12, 0, 0),
                    Capacity = 2,
                    Price = 100,
                    Status = TransportStatus.Active
                },
                new TransportOption
                {
                    Id = 3,
                    Type = TransportType.Bus,
                    Provider = "Fully Reserved",
                    RouteFrom = "Colombo",
                    RouteTo = "Ella",
                    DepartureTime = new DateTime(2026, 10, 16, 8, 0, 0),
                    ArrivalTime = new DateTime(2026, 10, 16, 12, 0, 0),
                    Capacity = 3,
                    Price = 100,
                    Status = TransportStatus.Active
                });
            var booking = new Booking
            {
                Id = 7,
                BookingReference = "ST-COVERAGE-7",
                CustomerId = "customer-7",
                ItineraryId = 7,
                Status = BookingStatus.Confirmed,
                BookingItems = new List<BookingItem>()
            };
            booking.BookingItems.Add(new BookingItem
            {
                Id = 70,
                BookingId = 7,
                Booking = booking,
                ItemType = BookingItemType.Transport,
                TransportOptionId = 3,
                Quantity = 3,
                UnitPrice = 100,
                Subtotal = 300,
                Currency = "LKR"
            });
            context.Bookings.Add(booking);
            await context.SaveChangesAsync();

            var service = new TransportService(context);
            var noRoute = await service.GetCoverageAsync(
                "Batticaloa", "Colombo", new DateTime(2026, 10, 15), new DateTime(2026, 10, 21), 3);
            var noDate = await service.GetCoverageAsync(
                "Colombo", "Ella", new DateTime(2026, 10, 14), new DateTime(2026, 10, 14), 3);
            var noCapacity = await service.GetCoverageAsync(
                "Colombo", "Ella", new DateTime(2026, 10, 15), new DateTime(2026, 10, 21), 4);

            Assert.Equal("NO_ROUTE", noRoute.ReasonCode);
            Assert.Equal("NO_DATE_MATCH", noDate.ReasonCode);
            Assert.Equal("NO_CAPACITY", noCapacity.ReasonCode);

            var noAvailability = await service.GetCoverageAsync(
                "Colombo", "Ella", new DateTime(2026, 10, 16), new DateTime(2026, 10, 16), 3);
            Assert.Equal("NO_AVAILABILITY", noAvailability.ReasonCode);
            Assert.Equal(1, noAvailability.CapacityMatches);
            Assert.Equal(0, noAvailability.AvailableMatches);
        }

        [Fact]
        public void CoverageEndpointRequiresStaffRole()
        {
            var method = typeof(TransportController).GetMethod(nameof(TransportController.Coverage));
            var authorize = method?.GetCustomAttribute<AuthorizeAttribute>();

            Assert.NotNull(authorize);
            Assert.Equal("TravelAgent,Admin", authorize!.Roles);
            Assert.Null(method?.GetCustomAttribute<AllowAnonymousAttribute>());
        }
    }
}
