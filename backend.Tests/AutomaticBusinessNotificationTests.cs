using backend.Data;
using backend.DTOs;
using backend.Models;
using backend.Models.Enums;
using backend.Services;
using Microsoft.AspNetCore.Identity;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Moq;

namespace backend.Tests;

public sealed class AutomaticBusinessNotificationTests
{
    private static async Task<(AppDbContext Context, SqliteConnection Connection)> CreateContextAsync()
    {
        var connection = new SqliteConnection("Data Source=:memory:");
        await connection.OpenAsync();
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlite(connection)
            .Options;
        var context = new AppDbContext(options);
        await context.Database.EnsureCreatedAsync();
        context.Customers.Add(new Customer
        {
            Id = "customer-1",
            FullName = "Test Customer",
            Role = "Customer"
        });
        await context.SaveChangesAsync();
        return (context, connection);
    }

    [Fact]
    public async Task EventNotification_IsPersistedOnce_WithReferencesAndEventKey()
    {
        var (context, connection) = await CreateContextAsync();
        await using (context)
        await using (connection)
        {
            var service = new NotificationService(context);

            var first = await service.CreateEventNotificationAsync(
                "customer-1",
                MessageType.TripPlanningReady,
                "Your itinerary is ready to review.",
                "TripRequest",
                "17",
                "trip:17:planning-ready:44");
            var retry = await service.CreateEventNotificationAsync(
                "customer-1",
                MessageType.TripPlanningReady,
                "Your itinerary is ready to review.",
                "TripRequest",
                "17",
                "trip:17:planning-ready:44");

            Assert.Equal(first.Id, retry.Id);
            Assert.Equal("TripRequest", first.ReferenceType);
            Assert.Equal("17", first.ReferenceId);
            Assert.Equal("trip:17:planning-ready:44", first.EventKey);
            Assert.Equal("InApp", first.Channel);
            Assert.Equal(1, await context.Notifications.CountAsync());
        }
    }

    [Fact]
    public async Task PlanningFailure_UsesSafeCustomerMessageAndAuthoritativeTripReference()
    {
        var (context, connection) = await CreateContextAsync();
        await using (context)
        await using (connection)
        {
            context.TripRequests.Add(new TripRequest
            {
                Id = 71,
                CustomerId = "customer-1",
                RawRequestText = "Test planning failure",
                StartDate = DateTime.UtcNow.Date.AddDays(5),
                EndDate = DateTime.UtcNow.Date.AddDays(8),
                TravellerCount = 1,
                BudgetCeiling = 500,
                Currency = "USD",
                Status = TripRequestStatus.Planning
            });
            await context.SaveChangesAsync();

            var result = await new TripRequestService(context).UpdateAgentPlanAsync(71, new TripRequestAgentUpdateDto
            {
                Status = "Failed",
                FailureReason = "Internal provider exception with SQL details",
                RetryCount = 2
            });

            Assert.Equal("Failed", result?.Status);
            var notification = await context.Notifications.SingleAsync();
            Assert.Equal(MessageType.TripPlanningFailed, notification.MessageType);
            Assert.Equal("TripRequest", notification.ReferenceType);
            Assert.Equal("71", notification.ReferenceId);
            Assert.Equal("We couldn't complete your itinerary. You can try again.", notification.Content);
            Assert.DoesNotContain("exception", notification.Content, StringComparison.OrdinalIgnoreCase);
            Assert.DoesNotContain("SQL", notification.Content, StringComparison.OrdinalIgnoreCase);
        }
    }

    [Fact]
    public async Task ApprovalRejection_NotifiesOnceAndDoesNotTrustCallerRecipient()
    {
        var (context, connection) = await CreateContextAsync();
        await using (context)
        await using (connection)
        {
            context.Users.Add(new IdentityUser { Id = "agent-1", UserName = "agent-1" });
            context.TripRequests.Add(new TripRequest
            {
                Id = 81,
                CustomerId = "customer-1",
                RawRequestText = "Approval test",
                StartDate = DateTime.UtcNow.Date.AddDays(5),
                EndDate = DateTime.UtcNow.Date.AddDays(8),
                TravellerCount = 1,
                BudgetCeiling = 500,
                Currency = "USD",
                Status = TripRequestStatus.AwaitingApproval
            });
            context.Itineraries.Add(new Itinerary
            {
                Id = 181,
                CustomerId = "customer-1",
                TripRequestId = 81,
                StartDate = DateTime.UtcNow.Date.AddDays(5),
                EndDate = DateTime.UtcNow.Date.AddDays(8),
                Currency = "USD",
                Status = ItineraryStatus.Proposed
            });
            context.Bookings.Add(new Booking
            {
                Id = 281,
                BookingReference = "ST-NOTIFY-281",
                CustomerId = "customer-1",
                ItineraryId = 181,
                Currency = "USD",
                Status = BookingStatus.AwaitingApproval
            });
            await context.SaveChangesAsync();

            var store = new Mock<IUserStore<IdentityUser>>();
            var userManager = new Mock<UserManager<IdentityUser>>(
                store.Object, null!, null!, null!, null!, null!, null!, null!, null!);
            var service = new ApprovalService(context, userManager.Object);

            await service.CreateApprovalAsync("agent-1", new ApprovalCreateDto
            {
                BookingId = 281,
                Decision = ApprovalDecision.Rejected,
                Comment = "Internal reviewer notes must not be sent to the customer."
            });

            var notification = await context.Notifications.SingleAsync();
            Assert.Equal("customer-1", notification.CustomerId);
            Assert.Equal(MessageType.TripRejected, notification.MessageType);
            Assert.Equal("TripRequest", notification.ReferenceType);
            Assert.Equal("81", notification.ReferenceId);
            Assert.DoesNotContain("Internal reviewer", notification.Content);
        }
    }
}
