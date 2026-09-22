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
