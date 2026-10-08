using backend.Data;
using backend.DTOs;
using backend.Models;
using backend.Models.Enums;
using backend.Services;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Moq;

namespace backend.Tests
{
    public class BookingServiceTests
    {
        private static AppDbContext CreateContext()
        {
            // Use SQLite (not InMemory) so that BeginTransactionAsync works
            // correctly. InMemory raises TransactionIgnoredWarning-as-error
            // when BookingService calls BeginTransactionAsync(RepeatableRead).
            var dbPath = $"unit_test_{Guid.NewGuid():N}.db";
            var options = new DbContextOptionsBuilder<AppDbContext>()
                .UseSqlite($"Data Source={dbPath}")
                .Options;

            var context = new AppDbContext(options);
            context.Database.EnsureCreated();
            return context;
        }

        private static async Task SeedDependenciesAsync(AppDbContext context)
        {
            context.Users.Add(new IdentityUser
            {
                Id = "agent-user-1",
                UserName = "agent-user-1"
            });

            context.Customers.Add(new Customer
            {
                Id = "cust-1",
                FullName = "John Doe",
                JoinedAt = DateTime.UtcNow
            });

            context.TripRequests.Add(new TripRequest
            {
                Id = 1,
                CustomerId = "cust-1",
                DestinationId = 1,
                RawRequestText = "Trip to Paris",
                Status = TripRequestStatus.Planning,
                StartDate = DateTime.UtcNow.Date.AddDays(5),
                EndDate = DateTime.UtcNow.Date.AddDays(20),
                TravellerCount = 2,
                BudgetCeiling = 100000,
                Currency = "USD"
            });

            context.Itineraries.Add(new Itinerary
            {
                Id = 10,
                CustomerId = "cust-1",
                TripRequestId = 1,
                StartDate = DateTime.UtcNow,
                EndDate = DateTime.UtcNow.AddDays(5),
                Status = ItineraryStatus.Proposed,
                TotalEstimatedCost = 500,
                Currency = "USD"
            });

            context.Destinations.Add(new Destination
            {
                Id = 1,
                Name = "Paris",
                Country = "France"
            });

            context.Tours.Add(new Tour
            {
                Id = 100,
                DestinationId = 1,
                Name = "Eiffel Tower Tour",
                Category = "Sightseeing",
                Price = 100,
                Currency = "USD"
            });

            context.Hotels.Add(new Hotel
            {
                Id = 200,
                DestinationId = 1,
                Name = "Audit Hotel",
                Status = HotelStatus.Active
            });

            context.Rooms.Add(new Room
            {
                Id = 300,
                HotelId = 200,
                RoomType = "Deluxe",
                Capacity = 4,
                TotalRooms = 10,
                PricePerNight = 25000,
                Currency = "USD",
                Status = RoomStatus.Active
            });

            context.TransportOptions.Add(new TransportOption
            {
                Id = 400,
                Type = TransportType.Car,
                Provider = "Audit Transport",
                RouteFrom = "Paris",
                RouteTo = "Lyon",
                DepartureTime = DateTime.UtcNow.AddDays(10),
                ArrivalTime = DateTime.UtcNow.AddDays(10).AddHours(2),
                Capacity = 10,
                Price = 75,
                Currency = "USD",
                Status = TransportStatus.Active
            });

            await context.SaveChangesAsync();
        }

        [Fact]
        public async Task CreateBooking_InitialStatusIsAwaitingApproval_AndGeneratesReference()
        {
            // Arrange
            using var context = CreateContext();
            await SeedDependenciesAsync(context);
            var service = new BookingService(context);

            var dto = new BookingCreateDto
            {
                CustomerId = "cust-1",
                ItineraryId = 10,
                TotalCost = 500,
                Currency = "USD",
                Items = new List<BookingItemCreateDto>
                {
                    new BookingItemCreateDto
                    {
                        ItemType = BookingItemType.Tour,
                        TourId = 100,
                        Quantity = 2,
                        UnitPrice = 100
                    }
                }
            };

            // Act
            var result = await service.CreateBookingAsync(dto);

            // Assert
            Assert.NotNull(result);
            Assert.Equal(BookingStatus.AwaitingApproval, result.Status);
            Assert.StartsWith("TRV-", result.BookingReference);
            Assert.Equal(200, result.TotalCost);
            Assert.Single(result.BookingItems);
        }

        [Fact]
        public async Task CreateBooking_IgnoresClientPricesAndCalculatesFromActiveCatalog()
        {
            using var context = CreateContext();
            await SeedDependenciesAsync(context);
            var service = new BookingService(context);
            var checkIn = new DateTime(2030, 1, 10);
            var checkOut = new DateTime(2030, 1, 15);

            var result = await service.CreateBookingAsync(new BookingCreateDto
            {
                CustomerId = "cust-1",
                ItineraryId = 10,
                Currency = "USD",
                TotalCost = 1,
                Items = new List<BookingItemCreateDto>
                {
                    new()
                    {
                        ItemType = BookingItemType.Tour,
                        TourId = 100,
                        Quantity = 2,
                        UnitPrice = 1
                    },
                    new()
                    {
                        ItemType = BookingItemType.Room,
                        RoomId = 300,
                        CheckInDate = checkIn,
                        CheckOutDate = checkOut,
                        Quantity = 1,
                        UnitPrice = 1
                    },
                    new()
                    {
                        ItemType = BookingItemType.Transport,
                        TransportOptionId = 400,
                        Quantity = 2,
                        UnitPrice = 1
                    }
                }
            });

            Assert.Equal(125350m, result.TotalCost);
            Assert.Equal(3, result.BookingItems.Count);
            Assert.Equal(100m, result.BookingItems.Single(i => i.ItemType == BookingItemType.Tour).UnitPrice);
            Assert.Equal(25000m, result.BookingItems.Single(i => i.ItemType == BookingItemType.Room).UnitPrice);
            Assert.Equal(75m, result.BookingItems.Single(i => i.ItemType == BookingItemType.Transport).UnitPrice);
            Assert.Equal(125350m, result.BookingItems.Sum(i => i.Subtotal));
            var transportItem = result.BookingItems.Single(i => i.ItemType == BookingItemType.Transport);
            Assert.Equal("Car", transportItem.TransportType);
            Assert.Equal("Audit Transport", transportItem.TransportProvider);
            Assert.Equal("Paris", transportItem.RouteFrom);
            Assert.Equal("Lyon", transportItem.RouteTo);
        }

        [Fact]
        public async Task CreateBooking_RejectsInactiveRoom()
        {
            using var context = CreateContext();
            await SeedDependenciesAsync(context);
            var room = await context.Rooms.SingleAsync(r => r.Id == 300);
            room.Status = RoomStatus.Inactive;
            await context.SaveChangesAsync();

            var service = new BookingService(context);
            var exception = await Assert.ThrowsAsync<InvalidOperationException>(() => service.CreateBookingAsync(new BookingCreateDto
            {
                CustomerId = "cust-1",
                ItineraryId = 10,
                Currency = "USD",
                Items = new List<BookingItemCreateDto>
                {
                    new()
                    {
                        ItemType = BookingItemType.Room,
                        RoomId = 300,
                        CheckInDate = new DateTime(2030, 1, 10),
                        CheckOutDate = new DateTime(2030, 1, 11),
                        Quantity = 1,
                        UnitPrice = 1
                    }
                }
            }));

            Assert.Equal("The selected room is no longer available.", exception.Message);
        }

        [Fact]
        public async Task UpdateBookingStatus_RejectsInvalidTransitions()
        {
            // Arrange
            using var context = CreateContext();
            await SeedDependenciesAsync(context);
            var service = new BookingService(context);

            var dto = new BookingCreateDto
            {
                CustomerId = "cust-1",
                ItineraryId = 10,
                TotalCost = 500,
                Items = new List<BookingItemCreateDto>
                {
                    new BookingItemCreateDto
                    {
                        ItemType = BookingItemType.Tour,
                        TourId = 100,
                        Quantity = 1,
                        UnitPrice = 500
                    }
                }
            };

            var booking = await service.CreateBookingAsync(dto); // Status: AwaitingApproval

            // Act & Assert — AwaitingApproval -> Confirmed is VALID
            var updated = await service.UpdateBookingStatusAsync(booking.Id, BookingStatus.Confirmed);
            Assert.Equal(BookingStatus.Confirmed, updated.Status);
            var confirmation = await context.Notifications.SingleAsync();
            Assert.Equal(MessageType.BookingConfirmed, confirmation.MessageType);
            Assert.Equal("Booking", confirmation.ReferenceType);
            Assert.Equal(booking.Id.ToString(), confirmation.ReferenceId);

            // A retried confirmation is an idempotent no-op for notifications.
            await service.UpdateBookingStatusAsync(booking.Id, BookingStatus.Confirmed);
            Assert.Equal(1, await context.Notifications.CountAsync());

            // Act & Assert — Confirmed -> Draft is INVALID
            await Assert.ThrowsAsync<InvalidOperationException>(() =>
                service.UpdateBookingStatusAsync(booking.Id, BookingStatus.Draft));
        }

        [Fact]
        public async Task ProcessPayment_RefusesIfBookingIsNotConfirmed_Rule2Guard()
        {
            // Arrange
            using var context = CreateContext();
            await SeedDependenciesAsync(context);

            var bookingService = new BookingService(context);
            var paymentService = new PaymentService(context, new ConfigurationBuilder().Build(), new FakeStripePaymentGateway());

            var booking = await bookingService.CreateBookingAsync(new BookingCreateDto
            {
                CustomerId = "cust-1",
                ItineraryId = 10,
                TotalCost = 300,
                Items = new List<BookingItemCreateDto>
                {
                    new BookingItemCreateDto
                    {
                        ItemType = BookingItemType.Tour,
                        TourId = 100,
                        Quantity = 1,
                        UnitPrice = 300
                    }
                }
            }); // Status: AwaitingApproval

            var paymentDto = new PaymentCreateDto
            {
                BookingId = booking.Id,
                PaymentMethodId = "pm_card_visa"
            };

            // Act & Assert — Must throw InvalidOperationException because booking status is AwaitingApproval, not Confirmed
            var ex = await Assert.ThrowsAsync<InvalidOperationException>(() =>
                paymentService.ProcessPaymentAsync(paymentDto));

            Assert.Contains("status is 'AwaitingApproval', but payment is only permitted when status is 'Confirmed'", ex.Message);
        }

        [Fact]
        public async Task ProcessPayment_SucceedsWhenBookingIsConfirmed()
        {
            // Arrange
            using var context = CreateContext();
            await SeedDependenciesAsync(context);

            var bookingService = new BookingService(context);
            var paymentService = new PaymentService(context, new ConfigurationBuilder().Build(), new FakeStripePaymentGateway());

            var booking = await bookingService.CreateBookingAsync(new BookingCreateDto
            {
                CustomerId = "cust-1",
                ItineraryId = 10,
                TotalCost = 300,
                Items = new List<BookingItemCreateDto>
                {
                    new BookingItemCreateDto
                    {
                        ItemType = BookingItemType.Tour,
                        TourId = 100,
                        Quantity = 1,
                        UnitPrice = 300
                    }
                }
            });

            // Transition to Confirmed
            await bookingService.UpdateBookingStatusAsync(booking.Id, BookingStatus.Confirmed);

            // Act
            var payment = await paymentService.ProcessPaymentAsync(new PaymentCreateDto
            {
                BookingId = booking.Id,
                PaymentMethodId = "pm_card_visa"
            });

            // Assert
            Assert.NotNull(payment);
            Assert.Equal(PaymentStatus.Paid, payment.Status);
            Assert.StartsWith("pi_test_", payment.StripeReference);
        }

        [Fact]
        public async Task CreateApproval_UpdatesBookingStatusToConfirmed_AndRecordsAuditRow()
        {
            // Arrange
            using var context = CreateContext();
            await SeedDependenciesAsync(context);

            var store = new Mock<IUserStore<IdentityUser>>();
            var userManagerMock = new Mock<UserManager<IdentityUser>>(
                store.Object, null!, null!, null!, null!, null!, null!, null!, null!);

            var bookingService = new BookingService(context);
            var approvalService = new ApprovalService(context, userManagerMock.Object);

            var booking = await bookingService.CreateBookingAsync(new BookingCreateDto
            {
                CustomerId = "cust-1",
                ItineraryId = 10,
                TotalCost = 450,
                Items = new List<BookingItemCreateDto>
                {
                    new BookingItemCreateDto
                    {
                        ItemType = BookingItemType.Tour,
                        TourId = 100,
                        Quantity = 1,
                        UnitPrice = 450
                    }
                }
            });

            // Act
            var approval = await approvalService.CreateApprovalAsync("agent-user-1", new ApprovalCreateDto
            {
                BookingId = booking.Id,
                Decision = ApprovalDecision.Approved,
                Comment = "Looks good, approved."
            });

            // Assert
            Assert.NotNull(approval);
            Assert.Equal(ApprovalDecision.Approved, approval.Decision);

            var updatedBooking = await bookingService.GetBookingByIdAsync(booking.Id);
            Assert.Equal(BookingStatus.Confirmed, updatedBooking!.Status);
        }

        [Fact]
        public async Task CreateBooking_ThrowsKeyNotFoundException_WhenCustomerDoesNotExist()
        {
            // Arrange
            using var context = CreateContext();
            var service = new BookingService(context);

            var dto = new BookingCreateDto
            {
                CustomerId = "non-existent-cust",
                ItineraryId = 10,
                Items = new List<BookingItemCreateDto>
                {
                    new BookingItemCreateDto { ItemType = BookingItemType.Tour, TourId = 1, Quantity = 1, UnitPrice = 100 }
                }
            };

            // Act & Assert (HTTP 404 response trigger)
            await Assert.ThrowsAsync<KeyNotFoundException>(() => service.CreateBookingAsync(dto));
        }

        [Fact]
        public async Task CreateBooking_ThrowsArgumentException_WhenItemHasMultipleOrNoFKs()
        {
            // Arrange
            using var context = CreateContext();
            await SeedDependenciesAsync(context);
            var service = new BookingService(context);

            var dto = new BookingCreateDto
            {
                CustomerId = "cust-1",
                ItineraryId = 10,
                Items = new List<BookingItemCreateDto>
                {
                    // Invalid item with BOTH TourId and RoomId set (violates Rule 6)
                    new BookingItemCreateDto
                    {
                        ItemType = BookingItemType.Tour,
                        TourId = 100,
                        RoomId = 5,
                        Quantity = 1,
                        UnitPrice = 100
                    }
                }
            };

            // Act & Assert (HTTP 400 response trigger)
            var ex = await Assert.ThrowsAsync<ArgumentException>(() => service.CreateBookingAsync(dto));
            Assert.Contains("must have exactly one of TourId, RoomId, or TransportOptionId set", ex.Message);
        }

        [Fact]
        public async Task ProcessPayment_ThrowsKeyNotFoundException_WhenBookingDoesNotExist()
        {
            // Arrange
            using var context = CreateContext();
            var paymentService = new PaymentService(context, new ConfigurationBuilder().Build(), new FakeStripePaymentGateway());

            var paymentDto = new PaymentCreateDto
            {
                BookingId = 9999,
                Amount = 100,
                Currency = "USD",
                PaymentMethodId = "pm_card_visa"
            };

            // Act & Assert (HTTP 404 response trigger)
            await Assert.ThrowsAsync<KeyNotFoundException>(() => paymentService.ProcessPaymentAsync(paymentDto));
        }
    }
}
