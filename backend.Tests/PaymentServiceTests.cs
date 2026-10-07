using backend.Data;
using backend.DTOs;
using backend.Models;
using backend.Models.Enums;
using backend.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;

namespace backend.Tests;

public sealed class FakeStripePaymentGateway : IStripePaymentGateway
{
    public bool Succeed { get; set; } = true;
    public decimal Amount { get; private set; }
    public string Currency { get; private set; } = string.Empty;
    public string LastIdempotencyKey { get; private set; } = string.Empty;
    public int Calls { get; private set; }

    public Task<StripePaymentResult> CreatePaymentIntentAsync(decimal amount, string currency, string paymentMethodId, string idempotencyKey, CancellationToken cancellationToken = default)
    {
        Calls++;
        Amount = amount;
        Currency = currency;
        LastIdempotencyKey = idempotencyKey;
        return Task.FromResult(Succeed
            ? new StripePaymentResult(true, "pi_test_success")
            : new StripePaymentResult(false, "pi_test_declined", "The test payment method was declined."));
    }
}

public sealed class PaymentServiceTests
{
    private static AppDbContext CreateContext(string? path = null)
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlite($"Data Source={path ?? $"payment_test_{Guid.NewGuid():N}.db"}")
            .Options;
        var context = new AppDbContext(options);
        context.Database.EnsureCreated();
        return context;
    }

    private static async Task SeedBookingAsync(AppDbContext context, int id, BookingStatus status, decimal total = 125.50m, string currency = "USD", string customerId = "customer-1")
    {
        context.Customers.Add(new Customer { Id = customerId, FullName = customerId });
        context.TripRequests.Add(new TripRequest
        {
            Id = id,
            CustomerId = customerId,
            RawRequestText = "Payment test trip",
            StartDate = DateTime.UtcNow.Date,
            EndDate = DateTime.UtcNow.Date.AddDays(1),
            TravellerCount = 1,
            BudgetCeiling = 500,
            Currency = currency,
            Status = TripRequestStatus.AwaitingApproval
        });
        context.Itineraries.Add(new Itinerary
        {
            Id = id,
            CustomerId = customerId,
            TripRequestId = id,
            StartDate = DateTime.UtcNow.Date,
            EndDate = DateTime.UtcNow.Date.AddDays(1),
            Currency = currency,
            Status = ItineraryStatus.Proposed
        });
        context.Bookings.Add(new Booking
        {
            Id = id,
            BookingReference = $"ST-PAY-{id}",
            CustomerId = customerId,
            ItineraryId = id,
            Status = status,
            TotalCost = total,
            Currency = currency
        });
        await context.SaveChangesAsync();
    }

    [Theory]
    [InlineData(BookingStatus.AwaitingApproval)]
    [InlineData(BookingStatus.Rejected)]
    [InlineData(BookingStatus.Cancelled)]
    public async Task NonConfirmedBookingCannotPay(BookingStatus status)
    {
        await using var context = CreateContext();
        await SeedBookingAsync(context, 1, status);
        var gateway = new FakeStripePaymentGateway();
        var service = new PaymentService(context, new ConfigurationBuilder().Build(), gateway);

        await Assert.ThrowsAsync<InvalidOperationException>(() => service.ProcessPaymentAsync(new PaymentCreateDto
        {
            BookingId = 1,
            PaymentMethodId = "pm_card_visa"
        }));
        Assert.Equal(0, gateway.Calls);
    }

    [Fact]
    public async Task ConfirmedPaymentUsesAuthoritativeBookingAmountAndCurrency()
    {
        await using var context = CreateContext();
        await SeedBookingAsync(context, 2, BookingStatus.Confirmed, 321.45m, "USD");
        var gateway = new FakeStripePaymentGateway();
        var service = new PaymentService(context, new ConfigurationBuilder().Build(), gateway);

        var result = await service.ProcessPaymentAsync(new PaymentCreateDto
        {
            BookingId = 2,
            Amount = 1,
            Currency = "JPY",
            PaymentMethodId = "pm_card_visa"
        });

        Assert.Equal(321.45m, result.Amount);
        Assert.Equal("USD", result.Currency);
        Assert.Equal(321.45m, gateway.Amount);
        Assert.Equal("USD", gateway.Currency);
        Assert.Equal(PaymentStatus.Paid, result.Status);
        Assert.StartsWith("pi_", result.StripeReference);
        var notification = await context.Notifications.SingleAsync();
        Assert.Equal(MessageType.PaymentSucceeded, notification.MessageType);
        Assert.Equal("Booking", notification.ReferenceType);
        Assert.Equal("2", notification.ReferenceId);
        Assert.DoesNotContain("ch_sb_", result.StripeReference);
    }

    [Fact]
    public async Task FailedStripeResponsePersistsFailedPaymentAndKeepsBookingConfirmed()
    {
        await using var context = CreateContext();
        await SeedBookingAsync(context, 3, BookingStatus.Confirmed);
        var gateway = new FakeStripePaymentGateway { Succeed = false };
        var service = new PaymentService(context, new ConfigurationBuilder().Build(), gateway);

        var result = await service.ProcessPaymentAsync(new PaymentCreateDto
        {
            BookingId = 3,
            PaymentMethodId = "pm_card_chargeDeclined"
        });

        Assert.Equal(PaymentStatus.Failed, result.Status);
        Assert.Equal(BookingStatus.Confirmed, (await context.Bookings.FindAsync(3))!.Status);
        Assert.Equal("The test payment method was declined.", result.FailureReason);
        var notification = await context.Notifications.SingleAsync();
        Assert.Equal(MessageType.PaymentFailed, notification.MessageType);
        Assert.Equal("Your payment could not be completed. Please try again.", notification.Content);
        Assert.DoesNotContain("declined", notification.Content, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task DuplicateSuccessfulPaymentIsBlocked()
    {
        await using var context = CreateContext();
        await SeedBookingAsync(context, 4, BookingStatus.Confirmed);
        context.Payments.Add(new Payment
        {
            BookingId = 4,
            Amount = 125.50m,
            Currency = "USD",
            Status = PaymentStatus.Paid,
            StripeReference = "pi_test_existing",
            IdempotencyKey = "booking-4-payment-1"
        });
        await context.SaveChangesAsync();
        var gateway = new FakeStripePaymentGateway();
        var service = new PaymentService(context, new ConfigurationBuilder().Build(), gateway);

        await Assert.ThrowsAsync<PaymentAlreadyPaidException>(() => service.ProcessPaymentAsync(new PaymentCreateDto
        {
            BookingId = 4,
            PaymentMethodId = "pm_card_visa"
        }));
        Assert.Equal(0, gateway.Calls);
    }

    [Fact]
    public async Task ConcurrentPaymentAttemptsProduceAtMostOnePaidRow()
    {
        var path = $"payment_concurrency_{Guid.NewGuid():N}.db";
        await using (var seed = CreateContext(path))
        {
            await SeedBookingAsync(seed, 6, BookingStatus.Confirmed);
        }

        await using var firstContext = CreateContext(path);
        await using var secondContext = CreateContext(path);
        var firstGateway = new FakeStripePaymentGateway();
        var secondGateway = new FakeStripePaymentGateway();
        var first = new PaymentService(firstContext, new ConfigurationBuilder().Build(), firstGateway);
        var second = new PaymentService(secondContext, new ConfigurationBuilder().Build(), secondGateway);

        var results = await Task.WhenAll(
            CaptureAsync(() => first.ProcessPaymentAsync(new PaymentCreateDto { BookingId = 6, PaymentMethodId = "pm_card_visa" })),
            CaptureAsync(() => second.ProcessPaymentAsync(new PaymentCreateDto { BookingId = 6, PaymentMethodId = "pm_card_visa" })));

        await using var verify = CreateContext(path);
        var payments = await verify.Payments.Where(p => p.BookingId == 6).ToListAsync();
        Assert.Single(payments.Where(p => p.Status == PaymentStatus.Paid));
        Assert.Equal(1, results.Count(r => r.Success));
        Assert.Equal(1, results.Count(r => r.Error is PaymentAlreadyPaidException));
    }

    private static async Task<(bool Success, Exception? Error)> CaptureAsync(Func<Task<PaymentDto>> operation)
    {
        try
        {
            await operation();
            return (true, null);
        }
        catch (Exception ex)
        {
            return (false, ex);
        }
    }

    [Fact]
    public async Task RevenueCountsOnlyPaidPayments()
    {
        await using var context = CreateContext();
        await SeedBookingAsync(context, 5, BookingStatus.Confirmed);
        context.Payments.AddRange(
            new Payment { BookingId = 5, Amount = 100, Currency = "USD", Status = PaymentStatus.Paid, StripeReference = "pi_test_paid" },
            new Payment { BookingId = 5, Amount = 200, Currency = "USD", Status = PaymentStatus.Failed },
            new Payment { BookingId = 5, Amount = 300, Currency = "USD", Status = PaymentStatus.Pending });
        await context.SaveChangesAsync();
        var service = new PaymentService(context, new ConfigurationBuilder().Build(), new FakeStripePaymentGateway());

        var report = await service.GetRevenueReportAsync();

        Assert.Equal(100, report.TotalRevenue);
        Assert.Equal(1, report.PaidPaymentsCount);
        Assert.Equal(1, report.FailedPaymentsCount);
        Assert.Equal(1, report.PendingPaymentsCount);
    }
}
