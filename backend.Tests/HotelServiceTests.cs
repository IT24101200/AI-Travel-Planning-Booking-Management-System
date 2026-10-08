using Microsoft.EntityFrameworkCore;
using backend.Data;
using backend.DTOs;
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

        [Fact]
        public async Task UpdateAsync_WithOmittedCoordinates_PreservesExistingCoordinates()
        {
            using var context = CreateContext();
            context.Hotels.Add(new Hotel
            {
                Id = 10,
                DestinationId = 1,
                Name = "Mapped Hotel",
                Latitude = 6.9271,
                Longitude = 79.8612,
                Status = HotelStatus.Active
            });
            await context.SaveChangesAsync();

            var service = new HotelService(context);
            var updated = await service.UpdateAsync(10, new HotelUpdateDto
            {
                DestinationId = 1,
                Name = "Renamed Hotel",
                StarRating = 4,
                Status = "Active"
            });

            var hotel = await context.Hotels.SingleAsync(h => h.Id == 10);
            Assert.True(updated);
            Assert.Equal("Renamed Hotel", hotel.Name);
            Assert.Equal(6.9271, hotel.Latitude);
            Assert.Equal(79.8612, hotel.Longitude);
        }

        [Fact]
        public async Task UpdateStatusAsync_ChangesOnlyStatusAndPreservesCoordinates()
        {
            using var context = CreateContext();
            context.Hotels.Add(new Hotel
            {
                Id = 11,
                DestinationId = 1,
                Name = "Status Hotel",
                Latitude = 7.2906,
                Longitude = 80.6337,
                Status = HotelStatus.Active
            });
            await context.SaveChangesAsync();

            var service = new HotelService(context);
            Assert.True(await service.UpdateStatusAsync(11, "Inactive"));

            var hotel = await context.Hotels.SingleAsync(h => h.Id == 11);
            Assert.Equal(HotelStatus.Inactive, hotel.Status);
            Assert.Equal(7.2906, hotel.Latitude);
            Assert.Equal(80.6337, hotel.Longitude);
        }

        [Fact]
        public async Task PublicHotelAndRoomReadsHideInactiveInventory_ButManagementReadsCanIncludeIt()
        {
            using var context = CreateContext();
            context.Hotels.AddRange(
                new Hotel { Id = 20, DestinationId = 1, Name = "Active Hotel", Status = HotelStatus.Active },
                new Hotel { Id = 21, DestinationId = 1, Name = "Inactive Hotel", Status = HotelStatus.Inactive });
            context.Rooms.AddRange(
                new Room { Id = 201, HotelId = 20, RoomType = "Active Room", Capacity = 2, TotalRooms = 3, Status = RoomStatus.Active },
                new Room { Id = 202, HotelId = 20, RoomType = "Inactive Room", Capacity = 2, TotalRooms = 3, Status = RoomStatus.Inactive },
                new Room { Id = 211, HotelId = 21, RoomType = "Hidden Room", Capacity = 2, TotalRooms = 3, Status = RoomStatus.Active });
            await context.SaveChangesAsync();

            var service = new HotelService(context);

            Assert.Null(await service.GetByIdAsync(21));
            Assert.NotNull(await service.GetByIdAsync(21, includeInactive: true));
            Assert.Equal(new[] { 201 }, (await service.GetRoomsByHotelAsync(20))!.Select(r => r.Id));
            Assert.Null(await service.GetRoomsByHotelAsync(21));
            Assert.Equal(new[] { 201, 202 }, (await service.GetRoomsByHotelAsync(20, includeInactive: true))!.Select(r => r.Id));
            Assert.Null(await service.GetRoomByIdAsync(20, 202));
            Assert.NotNull(await service.GetRoomByIdAsync(20, 202, includeInactive: true));
            Assert.Single(await service.SearchRoomsAsync(null, null, null, null, false, 1, 20));
        }

        [Fact]
        public async Task DeleteRoomAsync_SoftDeletesAndPreservesHistoricalBookingForeignKey()
        {
            using var context = CreateContext();
            context.Hotels.Add(new Hotel { Id = 30, DestinationId = 1, Name = "History Hotel" });
            context.Rooms.Add(new Room
            {
                Id = 301,
                HotelId = 30,
                RoomType = "Historic Room",
                Capacity = 2,
                TotalRooms = 2,
                PricePerNight = 100
            });
            context.Bookings.Add(new Booking
            {
                Id = 3010,
                BookingReference = "TRV-HISTORY",
                CustomerId = "history-customer",
                ItineraryId = 3011,
                Status = BookingStatus.Confirmed,
                TotalCost = 100,
                BookingItems = new List<BookingItem>
                {
                    new()
                    {
                        ItemType = BookingItemType.Room,
                        RoomId = 301,
                        Quantity = 1,
                        UnitPrice = 100,
                        Subtotal = 100
                    }
                }
            });
            await context.SaveChangesAsync();

            var service = new HotelService(context);
            Assert.True(await service.DeleteRoomAsync(30, 301));

            var room = await context.Rooms.SingleAsync(r => r.Id == 301);
            var bookingItem = await context.BookingItems.SingleAsync(i => i.RoomId == 301);
            Assert.Equal(RoomStatus.Inactive, room.Status);
            Assert.Equal(301, bookingItem.RoomId);
            Assert.Null(await service.GetRoomByIdAsync(30, 301));
        }
    }
}
