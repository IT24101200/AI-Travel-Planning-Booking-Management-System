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
        Assert.NotNull(result.TripDetails);
        Assert.NotNull(notification.TripDetailsJson);
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
        Assert.Null(result.TripDetails);
        Assert.Null(notification.TripDetailsJson);
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
    public async Task PaidTripNotificationContainsCompleteImmutablePlanAndContacts()
    {
        await using var context = CreateContext();
        await SeedBookingAsync(context, 40, BookingStatus.Confirmed);
        var itinerary = await context.Itineraries.FindAsync(40);
        var trip = await context.TripRequests.FindAsync(40);
        itinerary!.EndDate = itinerary.StartDate.AddDays(7);
        trip!.TravellerCount = 2;
        trip.PlanJson = """
            {"booking_details":{"itinerary":{"schedule":[{"day_number":1,"travel_legs":[
              {"from":{"name":"Airport"},"to":{"name":"Kandy hotel"},"distance_km":110,"duration_minutes":180}
            ]}]},"agent_debug":"Must not be included in customer confirmation"}}
            """;
        context.Destinations.Add(new Destination { Id = 40, Name = "Kandy" });
        var hotel = new Hotel { Id = 40, DestinationId = 40, Name = "Booked Kandy hotel",
            Address = "Kandy hotel address", ContactPhone = "+94 11 555 0100", ContactEmail = "hotel@example.test" };
        context.Hotels.Add(hotel);
        context.Rooms.Add(new Room { Id = 40, HotelId = 40, RoomType = "Double", Capacity = 2, PricePerNight = 100 });
        context.BookingItems.Add(new BookingItem { BookingId = 40, ItemType = BookingItemType.Room, RoomId = 40,
            CheckInDate = itinerary.StartDate, CheckOutDate = itinerary.EndDate, Quantity = 1 });
        var transport = new TransportOption { Id = 40, Type = TransportType.Car, Provider = "Booked operator",
            ContactPhone = "+94 77 555 0100", ContactEmail = "operator@example.test", RouteFrom = "Airport", RouteTo = "Kandy",
            DepartureTime = itinerary.StartDate.AddHours(8), ArrivalTime = itinerary.StartDate.AddHours(11), Capacity = 4 };
        context.TransportOptions.Add(transport);
        context.BookingItems.Add(new BookingItem { BookingId = 40, ItemType = BookingItemType.Transport, TransportOptionId = 40,
            TransportProviderSnapshot = transport.Provider, TransportLegIndex = 0, Quantity = 2 });
        var tour = new Tour { Id = 40, DestinationId = 40, Name = "A booked cultural journey in Kandy with complete planned activity information", Currency = "USD" };
        context.Tours.Add(tour);
        for (var i = 0; i < 40; i++)
            context.ItineraryItems.Add(new ItineraryItem { ItineraryId = 40, TourId = 40,
                DayNumber = i / 6 + 1, SequenceOrder = i % 6 + 1, StartTime = TimeSpan.FromHours(8 + i % 6), EndTime = TimeSpan.FromHours(9 + i % 6) });
        await context.SaveChangesAsync();
        var gateway = new FakeStripePaymentGateway();
        var service = new PaymentService(context, new ConfigurationBuilder().Build(), gateway);
        var paid = await service.ProcessPaymentAsync(new PaymentCreateDto { BookingId = 40, PaymentMethodId = "pm_card_visa" });

        Assert.Equal(PaymentStatus.Paid, paid.Status);
        Assert.Equal(40, paid.TripDetails!.Days.Sum(d => d.Stops.Count(s => s.Kind == "Journey")));
        Assert.Equal("+94 11 555 0100", Assert.Single(paid.TripDetails.Hotels).ContactPhone);
        Assert.Equal("operator@example.test", Assert.Single(paid.TripDetails.Transports).ContactEmail);
        Assert.Equal("Airport", Assert.Single(paid.TripDetails.Days[0].Routes).From);
        Assert.Equal(180, paid.TripDetails.Days[0].Routes[0].TravelMinutes);
        var stored = await context.Notifications.SingleAsync();
        Assert.True(stored.TripDetailsJson!.Length > 2000);
        Assert.True(stored.Content.Length < 2000);
        Assert.DoesNotContain("agent_debug", stored.TripDetailsJson);
        Assert.DoesNotContain("Must not be included", stored.TripDetailsJson);

        hotel.Name = "Renamed catalogue hotel";
        hotel.ContactPhone = "Changed phone";
        transport.ContactEmail = "changed@example.test";
        tour.Name = "Changed catalogue tour";
        await context.SaveChangesAsync();
        context.ChangeTracker.Clear();
        var notifications = new NotificationService(context);
        var retrieved = await notifications.GetByIdAsync(stored.Id);
        Assert.Equal("Booked Kandy hotel", retrieved!.TripDetails!.Hotels[0].Name);
        Assert.Equal("+94 11 555 0100", retrieved.TripDetails.Hotels[0].ContactPhone);
        Assert.Equal("operator@example.test", retrieved.TripDetails.Transports[0].ContactEmail);
        Assert.Contains("booked cultural journey", retrieved.TripDetails.Days[0].Stops.First(s => s.Kind == "Journey").Name);
        Assert.Empty(await notifications.GetByCustomerIdAsync("another-customer", null, null, null, 1, 100));
        await Assert.ThrowsAsync<PaymentAlreadyPaidException>(() => service.ProcessPaymentAsync(
            new PaymentCreateDto { BookingId = 40, PaymentMethodId = "pm_card_visa" }));
        Assert.Equal(1, gateway.Calls);
        Assert.Equal(1, await context.Notifications.CountAsync());
    }

    [Theory]
    [InlineData("{}")]
    [InlineData("{\"itinerary\":null}")]
    [InlineData("{\"itinerary\":{\"schedule\":[{\"day_number\":\"bad\"}]}}")]
    public async Task LegacyPlanCannotPreventPaidConfirmation(string planJson)
    {
        await using var context = CreateContext();
        await SeedBookingAsync(context, 41, BookingStatus.Confirmed);
        (await context.TripRequests.FindAsync(41))!.PlanJson = planJson;
        await context.SaveChangesAsync();
        var service = new PaymentService(context, new ConfigurationBuilder().Build(), new FakeStripePaymentGateway());
        var paid = await service.ProcessPaymentAsync(new PaymentCreateDto { BookingId = 41, PaymentMethodId = "pm_card_visa" });
        Assert.Equal(PaymentStatus.Paid, paid.Status);
        Assert.NotEmpty(paid.TripDetails!.Days);
        Assert.NotNull((await context.Notifications.SingleAsync()).TripDetailsJson);
    }

    [Theory]
    [InlineData("[]")]
    [InlineData("{broken")]
    public void ConfirmationBuilderIgnoresUnreadableOptionalRoadData(string planJson)
    {
        var booking = new Booking { Itinerary = new Itinerary { StartDate = DateTime.Today, EndDate = DateTime.Today,
            TripRequest = new TripRequest { PlanJson = planJson } } };
        Assert.Single(TripConfirmationBuilder.Build(booking).Days);
    }

    [Fact]
    public void ChangedOperatorDoesNotSupplyContactsForOriginalBookedOperator()
    {
        var booking = new Booking { Itinerary = new Itinerary { StartDate = DateTime.Today, EndDate = DateTime.Today,
            TripRequest = new TripRequest() }, BookingItems = new List<BookingItem> {
            new() { ItemType = BookingItemType.Transport, TransportProviderSnapshot = "Original operator",
                TransportOption = new TransportOption { Provider = "Other operator", ContactPhone = "Other phone" } } } };
        var transport = Assert.Single(TripConfirmationBuilder.Build(booking).Transports);
        Assert.Equal("Original operator", transport.Provider);
        Assert.Null(transport.ContactPhone);
    }

    [Fact]
    public async Task TransportContactDetailsRoundTripThroughStaffCrud()
    {
        await using var context = CreateContext();
        var service = new TransportService(context);
        var input = new CreateTransportOptionDto { Type = "Car", Provider = "Operator", RouteFrom = "Airport", RouteTo = "Kandy",
            DepartureTime = DateTime.Today.AddHours(8), ArrivalTime = DateTime.Today.AddHours(11), Capacity = 4,
            ContactPhone = " +94 77 555 0100 ", ContactEmail = " operator@example.test " };
        var created = await service.CreateAsync(input);
        Assert.Equal("+94 77 555 0100", created.ContactPhone);
        Assert.Equal("operator@example.test", created.ContactEmail);
        input.ContactPhone = "+94 77 555 0200";
        Assert.True(await service.UpdateAsync(created.Id, input));
        Assert.Equal("+94 77 555 0200", (await service.GetByIdAsync(created.Id))!.ContactPhone);
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
