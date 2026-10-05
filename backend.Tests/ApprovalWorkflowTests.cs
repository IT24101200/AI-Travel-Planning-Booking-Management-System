using backend.Data;
using backend.DTOs;
using backend.Models;
using backend.Models.Enums;
using backend.Services;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Moq;

namespace backend.Tests;

public sealed class ApprovalWorkflowTests
{
    private static AppDbContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlite($"Data Source=approval_workflow_{Guid.NewGuid():N}.db")
            .Options;
        var context = new AppDbContext(options);
        context.Database.EnsureCreated();
        return context;
    }

    [Fact]
    public async Task RevisionRequest_PreservesProposal_CancelsOldBooking_AndReturnsTripToPlanning()
    {
        await using var context = CreateContext();
        context.Users.Add(new IdentityUser { Id = "agent-7", UserName = "agent-7" });
        context.Customers.Add(new Customer { Id = "customer-1", FullName = "Customer" });
        context.TripRequests.Add(new TripRequest
        {
            Id = 42,
            CustomerId = "customer-1",
            RawRequestText = "Beach trip",
            StartDate = DateTime.UtcNow.Date,
            EndDate = DateTime.UtcNow.Date.AddDays(2),
            TravellerCount = 1,
            BudgetCeiling = 1000,
            Currency = "USD",
            Status = TripRequestStatus.AwaitingApproval,
            PlanJson = "{\"version\":1}"
        });
        context.Itineraries.Add(new Itinerary
        {
            Id = 7,
            CustomerId = "customer-1",
            TripRequestId = 42,
            StartDate = DateTime.UtcNow.Date,
            EndDate = DateTime.UtcNow.Date.AddDays(2),
            Status = ItineraryStatus.Proposed,
            Currency = "USD"
        });
        context.Bookings.Add(new Booking
        {
            Id = 9,
            BookingReference = "ST-HISTORY-9",
            CustomerId = "customer-1",
            ItineraryId = 7,
            Status = BookingStatus.AwaitingApproval,
            Currency = "USD"
        });
        await context.SaveChangesAsync();

        var userStore = new Mock<IUserStore<IdentityUser>>();
        var userManager = new Mock<UserManager<IdentityUser>>(
            userStore.Object, null!, null!, null!, null!, null!, null!, null!, null!);
        var service = new ApprovalService(context, userManager.Object);

        var result = await service.CreateApprovalAsync("agent-7", new ApprovalCreateDto
        {
            BookingId = 9,
            Decision = ApprovalDecision.RevisionRequested,
            Comment = "Please reduce the daily travel time."
        });

        var booking = await context.Bookings.Include(b => b.Itinerary).SingleAsync(b => b.Id == 9);
        var trip = await context.TripRequests.SingleAsync(t => t.Id == 42);

        Assert.Equal(ApprovalDecision.RevisionRequested, result.Decision);
        Assert.Equal("agent-7", result.TravelAgentId);
        Assert.Equal(BookingStatus.Cancelled, booking.Status);
        Assert.Equal(ItineraryStatus.Discarded, booking.Itinerary.Status);
        Assert.Equal(TripRequestStatus.Planning, trip.Status);
        Assert.Null(trip.PlanJson);
        Assert.Equal("Please reduce the daily travel time.", trip.FailureReason);
        Assert.Single(await context.BookingApprovals.ToListAsync());
    }
}
