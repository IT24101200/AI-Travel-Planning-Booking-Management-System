using System.Text.Json;
using backend.Data;
using backend.DTOs;
using backend.Models;
using backend.Models.Enums;
using backend.Services;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace backend.Tests
{
    public class TripRequestServiceTests
    {
        private static AppDbContext CreateContext()
        {
            var options = new DbContextOptionsBuilder<AppDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString())
                .Options;

            return new AppDbContext(options);
        }

        [Fact]
        public async Task CreateAsync_ValidRequest_CreatesTripRequestSuccessfully()
        {
            var context = CreateContext();
            var service = new TripRequestService(context);

            var dto = new TripRequestCreateDto
            {
                RawRequestText = "Family holiday in Colombo",
                StartDate = DateTime.UtcNow.Date.AddDays(7),
                EndDate = DateTime.UtcNow.Date.AddDays(14),
                TravellerCount = 3,
                BudgetCeiling = 3000,
                Currency = "USD"
            };

            var result = await service.CreateAsync("cust-1", dto);

            Assert.NotNull(result);
            Assert.Equal("cust-1", result.CustomerId);
            Assert.Equal(3, result.TravellerCount);
            Assert.Equal(3000, result.BudgetCeiling);
            Assert.Equal("Pending", result.Status);
        }

        [Fact]
        public async Task CreateAsync_TravellerCountZero_ThrowsArgumentException()
        {
            var context = CreateContext();
            var service = new TripRequestService(context);

            var dto = new TripRequestCreateDto
            {
                StartDate = DateTime.UtcNow.Date.AddDays(5),
                EndDate = DateTime.UtcNow.Date.AddDays(10),
                TravellerCount = 0,
                BudgetCeiling = 1000
            };

            await Assert.ThrowsAsync<ArgumentException>(() => service.CreateAsync("cust-1", dto));
        }

        [Fact]
        public async Task CreateAsync_StartDateInPast_ThrowsArgumentException()
        {
            var context = CreateContext();
            var service = new TripRequestService(context);

            var dto = new TripRequestCreateDto
            {
                StartDate = DateTime.UtcNow.Date.AddDays(-2),
                EndDate = DateTime.UtcNow.Date.AddDays(5),
                TravellerCount = 2,
                BudgetCeiling = 1000
            };

            await Assert.ThrowsAsync<ArgumentException>(() => service.CreateAsync("cust-1", dto));
        }

        [Fact]
        public async Task CreateAsync_StartDateAfterEndDate_ThrowsArgumentException()
        {
            var context = CreateContext();
            var service = new TripRequestService(context);

            var dto = new TripRequestCreateDto
            {
                StartDate = DateTime.UtcNow.Date.AddDays(10),
                EndDate = DateTime.UtcNow.Date.AddDays(5),
                TravellerCount = 2,
                BudgetCeiling = 1000
            };

            await Assert.ThrowsAsync<ArgumentException>(() => service.CreateAsync("cust-1", dto));
        }

        [Fact]
        public async Task CreateAsync_BudgetBelowCustomerPreferenceMin_ThrowsArgumentException()
        {
            var context = CreateContext();
            var service = new TripRequestService(context);

            // Add customer preference with minimum budget of 2000
            context.Preferences.Add(new Preference
            {
                CustomerId = "cust-1",
                BudgetMin = 2000,
                Currency = "USD"
            });
            await context.SaveChangesAsync();

            var dto = new TripRequestCreateDto
            {
                StartDate = DateTime.UtcNow.Date.AddDays(5),
                EndDate = DateTime.UtcNow.Date.AddDays(10),
                TravellerCount = 2,
                BudgetCeiling = 1500, // Below minimum
                Currency = "USD"
            };

            var ex = await Assert.ThrowsAsync<ArgumentException>(() => service.CreateAsync("cust-1", dto));
            Assert.Contains("below your preferred minimum budget", ex.Message);
        }

        [Fact]
        public async Task CancelAsync_PendingTrip_CancelsSuccessfully()
        {
            var context = CreateContext();
            var service = new TripRequestService(context);

            var trip = new TripRequest
            {
                CustomerId = "cust-1",
                RawRequestText = "Trip to Tokyo",
                StartDate = DateTime.UtcNow.Date.AddDays(10),
                EndDate = DateTime.UtcNow.Date.AddDays(15),
                TravellerCount = 2,
                BudgetCeiling = 2000,
                Status = TripRequestStatus.Pending
            };
            context.TripRequests.Add(trip);
            await context.SaveChangesAsync();

            var cancelled = await service.CancelAsync(trip.Id, "cust-1");

            Assert.NotNull(cancelled);
            Assert.Equal("Cancelled", cancelled.Status);
        }

        [Fact]
        public async Task CancelAsync_PlanningTrip_CancelsSuccessfully()
        {
            await using var context = CreateContext();
            var service = new TripRequestService(context);
            var trip = new TripRequest
            {
                CustomerId = "cust-1",
                RawRequestText = "Trip to Ella",
                StartDate = DateTime.UtcNow.Date.AddDays(10),
                EndDate = DateTime.UtcNow.Date.AddDays(15),
                TravellerCount = 2,
                BudgetCeiling = 2000,
                Status = TripRequestStatus.Planning
            };
            context.TripRequests.Add(trip);
            await context.SaveChangesAsync();

            var cancelled = await service.CancelAsync(trip.Id, "cust-1");

            Assert.Equal("Cancelled", cancelled!.Status);
        }

        [Fact]
        public async Task CancelAsync_AwaitingApprovalTrip_CancelsRelatedProposalWithoutDeletingHistory()
        {
            await using var context = CreateContext();
            var service = new TripRequestService(context);
            var trip = new TripRequest
            {
                CustomerId = "cust-1",
                RawRequestText = "Trip to Kandy",
                StartDate = DateTime.UtcNow.Date.AddDays(10),
                EndDate = DateTime.UtcNow.Date.AddDays(15),
                TravellerCount = 2,
                BudgetCeiling = 2000,
                Status = TripRequestStatus.AwaitingApproval
            };
            var itinerary = new Itinerary
            {
                CustomerId = "cust-1",
                TripRequest = trip,
                StartDate = trip.StartDate,
                EndDate = trip.EndDate,
                Status = ItineraryStatus.Proposed,
                Currency = "LKR"
            };
            var booking = new Booking
            {
                BookingReference = "TRV-CANCEL-1",
                CustomerId = "cust-1",
                Itinerary = itinerary,
                Status = BookingStatus.AwaitingApproval,
                Currency = "LKR"
            };
            context.AddRange(trip, itinerary, booking);
            await context.SaveChangesAsync();

            await service.CancelAsync(trip.Id, "cust-1");

            Assert.Equal(TripRequestStatus.Cancelled, (await context.TripRequests.FindAsync(trip.Id))!.Status);
            Assert.Equal(ItineraryStatus.Discarded, (await context.Itineraries.FindAsync(itinerary.Id))!.Status);
            Assert.Equal(BookingStatus.Cancelled, (await context.Bookings.FindAsync(booking.Id))!.Status);
            Assert.NotNull(await context.TripRequests.FindAsync(trip.Id));
            Assert.NotNull(await context.Itineraries.FindAsync(itinerary.Id));
            Assert.NotNull(await context.Bookings.FindAsync(booking.Id));
        }

        [Fact]
        public async Task CancelAsync_DifferentCustomer_ReturnsNotFoundWithoutChangingTrip()
        {
            await using var context = CreateContext();
            var service = new TripRequestService(context);
            var trip = new TripRequest
            {
                CustomerId = "cust-1",
                RawRequestText = "Private trip",
                StartDate = DateTime.UtcNow.Date.AddDays(10),
                EndDate = DateTime.UtcNow.Date.AddDays(15),
                TravellerCount = 1,
                BudgetCeiling = 1000,
                Status = TripRequestStatus.Pending
            };
            context.TripRequests.Add(trip);
            await context.SaveChangesAsync();

            var result = await service.CancelAsync(trip.Id, "cust-2");

            Assert.Null(result);
            Assert.Equal(TripRequestStatus.Pending, (await context.TripRequests.FindAsync(trip.Id))!.Status);
        }

        [Theory]
        [InlineData(TripRequestStatus.Cancelled)]
        [InlineData(TripRequestStatus.Failed)]
        [InlineData(TripRequestStatus.Rejected)]
        [InlineData(TripRequestStatus.Approved)]
        public async Task CancelAsync_TerminalTrip_IsRejected(TripRequestStatus status)
        {
            await using var context = CreateContext();
            var service = new TripRequestService(context);
            var trip = new TripRequest
            {
                CustomerId = "cust-1",
                RawRequestText = "Terminal trip",
                StartDate = DateTime.UtcNow.Date.AddDays(10),
                EndDate = DateTime.UtcNow.Date.AddDays(15),
                TravellerCount = 1,
                BudgetCeiling = 1000,
                Status = status
            };
            context.TripRequests.Add(trip);
            await context.SaveChangesAsync();

            await Assert.ThrowsAsync<InvalidOperationException>(() => service.CancelAsync(trip.Id, "cust-1"));
        }

        [Fact]
        public async Task CancelAsync_PaidBooking_IsRejectedAndLeavesRelatedStateUnchanged()
        {
            await using var context = CreateContext();
            var service = new TripRequestService(context);
            var trip = new TripRequest
            {
                CustomerId = "cust-1",
                RawRequestText = "Paid trip",
                StartDate = DateTime.UtcNow.Date.AddDays(10),
                EndDate = DateTime.UtcNow.Date.AddDays(15),
                TravellerCount = 1,
                BudgetCeiling = 1000,
                Status = TripRequestStatus.AwaitingApproval
            };
            var itinerary = new Itinerary
            {
                CustomerId = "cust-1",
                TripRequest = trip,
                StartDate = trip.StartDate,
                EndDate = trip.EndDate,
                Status = ItineraryStatus.Proposed,
                Currency = "LKR"
            };
            var booking = new Booking
            {
                BookingReference = "TRV-PAID-1",
                CustomerId = "cust-1",
                Itinerary = itinerary,
                Status = BookingStatus.AwaitingApproval,
                Currency = "LKR",
                Payments = new List<Payment>
                {
                    new() { Status = PaymentStatus.Paid, Amount = 100, Currency = "LKR" }
                }
            };
            context.AddRange(trip, itinerary, booking);
            await context.SaveChangesAsync();

            var ex = await Assert.ThrowsAsync<InvalidOperationException>(() => service.CancelAsync(trip.Id, "cust-1"));

            Assert.Contains("already been paid", ex.Message);
            Assert.Equal(TripRequestStatus.AwaitingApproval, (await context.TripRequests.FindAsync(trip.Id))!.Status);
            Assert.Equal(BookingStatus.AwaitingApproval, (await context.Bookings.FindAsync(booking.Id))!.Status);
        }

        [Fact]
        public async Task CancelAsync_AlreadyApprovedTrip_ThrowsInvalidOperationException()
        {
            var context = CreateContext();
            var service = new TripRequestService(context);

            var trip = new TripRequest
            {
                CustomerId = "cust-1",
                RawRequestText = "Trip to Tokyo",
                StartDate = DateTime.UtcNow.Date.AddDays(10),
                EndDate = DateTime.UtcNow.Date.AddDays(15),
                TravellerCount = 2,
                BudgetCeiling = 2000,
                Status = TripRequestStatus.Approved
            };
            context.TripRequests.Add(trip);
            await context.SaveChangesAsync();

            await Assert.ThrowsAsync<InvalidOperationException>(() => service.CancelAsync(trip.Id, "cust-1"));
        }

        [Fact]
        public async Task AddAgentLogAsync_ValidDto_CreatesAndPersistsAgentLog()
        {
            var context = CreateContext();
            var service = new TripRequestService(context);

            var trip = new TripRequest
            {
                CustomerId = "cust-1",
                RawRequestText = "Trip",
                StartDate = DateTime.UtcNow.Date.AddDays(5),
                EndDate = DateTime.UtcNow.Date.AddDays(10),
                TravellerCount = 1,
                BudgetCeiling = 1000
            };
            context.TripRequests.Add(trip);
            await context.SaveChangesAsync();

            var logDto = new AgentLogCreateDto
            {
                TripRequestId = trip.Id,
                AgentName = "CoordinatorAgent",
                StepName = "DecomposeAndAllocateBudget",
                Input = "{\"budget\": 1000}",
                Output = "{\"theme\": \"Adventure\"}",
                Status = "Success"
            };

            var createdLog = await service.AddAgentLogAsync(logDto);

            Assert.NotNull(createdLog);
            Assert.Equal("CoordinatorAgent", createdLog.AgentName);
            Assert.Equal("DecomposeAndAllocateBudget", createdLog.StepName);
            Assert.Equal("Success", createdLog.Status);

            var allLogs = await service.GetAgentLogsAsync(trip.Id, "cust-1");
            Assert.Single(allLogs);
            Assert.Equal("CoordinatorAgent", allLogs[0].AgentName);
        }

        [Fact]
        public async Task UpdateAgentPlanAsync_ValidUpdate_UpdatesStatusAndPlanJson()
        {
            var context = CreateContext();
            var service = new TripRequestService(context);

            var trip = new TripRequest
            {
                CustomerId = "cust-1",
                RawRequestText = "Trip",
                StartDate = DateTime.UtcNow.Date.AddDays(5),
                EndDate = DateTime.UtcNow.Date.AddDays(10),
                TravellerCount = 1,
                BudgetCeiling = 1000,
                Status = TripRequestStatus.Planning
            };
            context.TripRequests.Add(trip);
            await context.SaveChangesAsync();

            using var doc = JsonDocument.Parse("{\"theme\": \"Tokyo Explorer\", \"total_cost\": 950}");
            var updateDto = new TripRequestAgentUpdateDto
            {
                Status = "AwaitingApproval",
                PlanJson = doc.RootElement,
                RetryCount = 1,
                FailureReason = null
            };

            var updated = await service.UpdateAgentPlanAsync(trip.Id, updateDto);

            Assert.NotNull(updated);
            Assert.Equal("AwaitingApproval", updated.Status);
            Assert.Equal(1, updated.RetryCount);
            Assert.NotNull(updated.PlanJson);
            Assert.Contains("Tokyo Explorer", updated.PlanJson);
        }
    }
}
