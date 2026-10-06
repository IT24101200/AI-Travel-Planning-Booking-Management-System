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
                RawRequestText = "Trip to Paris",
                Status = TripRequestStatus.Planning
            });

            context.Itineraries.Add(new Itinerary
            {
                Id = 10,
                CustomerId = "cust-1",
                TripRequestId = 1,
                StartDate = DateTime.UtcNow,
                EndDate = DateTime.UtcNow.AddDays(5),
                Status = ItineraryStatus.Proposed,
                TotalEstimatedCost = 500
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
            Assert.Equal(500, result.TotalCost);
            Assert.Single(result.BookingItems);
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
            var paymentService = new PaymentService(context, new ConfigurationBuilder().Build());

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
                Amount = 300,
                Currency = "USD"
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
            var paymentService = new PaymentService(context, new ConfigurationBuilder().Build());

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
                Amount = 300,
                Currency = "USD"
            });

            // Assert
            Assert.NotNull(payment);
            Assert.Equal(PaymentStatus.Paid, payment.Status);
            Assert.StartsWith("ch_sb_", payment.StripeReference);
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
            var paymentService = new PaymentService(context, new ConfigurationBuilder().Build());

            var paymentDto = new PaymentCreateDto
            {
                BookingId = 9999,
                Amount = 100,
                Currency = "USD"
            };

            // Act & Assert (HTTP 404 response trigger)
            await Assert.ThrowsAsync<KeyNotFoundException>(() => paymentService.ProcessPaymentAsync(paymentDto));
        }
    }
}
