using System.Data;
using System.Globalization;
using backend.Data;
using backend.DTOs;
using backend.Models;
using backend.Models.Enums;
using Microsoft.EntityFrameworkCore;

namespace backend.Services;

public sealed class PaymentService : IPaymentService
{
    private static readonly System.Collections.Concurrent.ConcurrentDictionary<int, SemaphoreSlim> BookingLocks = new();
    private readonly AppDbContext _db;
    private readonly IStripePaymentGateway _stripe;
    private readonly ICurrencyConversionService _currency;

    public PaymentService(AppDbContext db, IConfiguration configuration, IStripePaymentGateway stripe, ICurrencyConversionService? currency = null)
    {
        _db = db;
        _stripe = stripe;
        _currency = currency ?? new CurrencyConversionService(configuration);
    }

    public async Task<PaymentDto> ProcessPaymentAsync(PaymentCreateDto dto)
    {
        if (dto == null)
            throw new ArgumentNullException(nameof(dto));

        var bookingLock = BookingLocks.GetOrAdd(dto.BookingId, _ => new SemaphoreSlim(1, 1));
        await bookingLock.WaitAsync();
        try
        {
            await using var transaction = await _db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
            if (_db.Database.ProviderName?.Contains("Npgsql", StringComparison.OrdinalIgnoreCase) == true)
            {
                await _db.Database.ExecuteSqlRawAsync(
                    "SELECT pg_advisory_xact_lock({0})", new object[] { dto.BookingId });
            }

            var booking = await _db.Bookings
                .Include(b => b.Customer)
                .Include(b => b.Payments)
                .SingleOrDefaultAsync(b => b.Id == dto.BookingId);

            if (booking == null)
                throw new KeyNotFoundException($"Booking with ID {dto.BookingId} not found.");

            if (string.IsNullOrWhiteSpace(dto.PaymentMethodId))
                throw new InvalidOperationException("A Stripe PaymentMethodId is required.");

            if (booking.Status != BookingStatus.Confirmed)
                throw new InvalidOperationException(
                    $"Payment cannot be processed. Booking status is '{booking.Status}', but payment is only permitted when status is 'Confirmed'.");

            if (booking.TotalCost <= 0)
                throw new InvalidOperationException("A confirmed booking must have a positive total cost before payment.");

            string currency;
            try
            {
                currency = _currency.Normalize(booking.Currency, "Booking currency");
            }
            catch (ArgumentException ex)
            {
                throw new InvalidOperationException(ex.Message, ex);
            }

            if (booking.Payments.Any(p => p.Status == PaymentStatus.Paid))
                throw new PaymentAlreadyPaidException($"Booking {booking.Id} already has a successful payment.");

            // A Pending row represents an ambiguous/retryable attempt. Reuse its
            // idempotency key so a timeout cannot create a second Stripe charge.
            var payment = booking.Payments
                .Where(p => p.Status == PaymentStatus.Pending)
                .OrderByDescending(p => p.Id)
                .FirstOrDefault();
            if (payment == null)
            {
                var attempt = booking.Payments.Count + 1;
                payment = new Payment
                {
                    BookingId = booking.Id,
                    Amount = booking.TotalCost,
                    Currency = currency,
                    ExchangeRateToLkr = booking.ExchangeRateToLkr,
                    Status = PaymentStatus.Pending,
                    IdempotencyKey = $"booking-{booking.Id}-payment-{attempt}",
                    PaymentDate = DateTime.UtcNow
                };
                _db.Payments.Add(payment);
                await _db.SaveChangesAsync();
            }
            else if (!string.Equals(payment.Currency, currency, StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidOperationException("The pending payment currency does not match the booking currency.");
            }

            StripePaymentResult stripeResult;
            try
            {
                stripeResult = await _stripe.CreatePaymentIntentAsync(
                    booking.TotalCost,
                    currency,
                    dto.PaymentMethodId.Trim(),
                    payment.IdempotencyKey!,
                    CancellationToken.None);
            }
            catch (Exception ex)
            {
                // Do not claim failure as Paid. Keep Pending because the external
                // result may be ambiguous and the same Stripe key must be retried.
                payment.FailureReason = SafeFailure(ex.Message);
                await _db.SaveChangesAsync();
                await transaction.CommitAsync();
                throw new PaymentGatewayException("Stripe payment could not be confirmed. The payment remains retryable.", ex);
            }

            payment.StripeReference = stripeResult.PaymentIntentId;
            payment.Status = stripeResult.Succeeded ? PaymentStatus.Paid : PaymentStatus.Failed;
            payment.FailureReason = stripeResult.Succeeded ? null : SafeFailure(stripeResult.FailureReason);
            payment.PaymentDate = DateTime.UtcNow;
            await _db.SaveChangesAsync();
            await transaction.CommitAsync();

            return Map(payment, booking);
        }
        finally
        {
            bookingLock.Release();
        }
    }

    public async Task<PaymentDto?> GetPaymentByIdAsync(int id)
    {
        var payment = await _db.Payments.Include(p => p.Booking).ThenInclude(b => b.Customer)
            .FirstOrDefaultAsync(p => p.Id == id);
        return payment == null ? null : Map(payment, payment.Booking);
    }

    public async Task<IEnumerable<PaymentDto>> GetPaymentsByBookingIdAsync(int bookingId)
    {
        var payments = await _db.Payments.Include(p => p.Booking).ThenInclude(b => b.Customer)
            .Where(p => p.BookingId == bookingId)
            .OrderByDescending(p => p.PaymentDate)
            .ToListAsync();
        return payments.Select(p => Map(p, p.Booking));
    }

    public async Task<IEnumerable<PaymentDto>> GetAllPaymentsAsync()
    {
        var payments = await _db.Payments.Include(p => p.Booking).ThenInclude(b => b.Customer)
            .OrderByDescending(p => p.PaymentDate)
            .ToListAsync();
        return payments.Select(p => Map(p, p.Booking));
    }

    public async Task<RevenueReportDto> GetRevenueReportAsync()
    {
        var payments = (await GetAllPaymentsAsync()).ToList();
        var paid = payments.Where(p => p.Status == PaymentStatus.Paid).ToList();
        var monthly = paid.GroupBy(p => new { p.PaymentDate.Year, p.PaymentDate.Month, p.Currency })
            .Select(g => new MonthlyRevenueDto
            {
                Year = g.Key.Year,
                Month = g.Key.Month,
                MonthName = CultureInfo.CurrentCulture.DateTimeFormat.GetMonthName(g.Key.Month),
                Currency = g.Key.Currency,
                Revenue = g.Sum(p => p.Amount)
            })
            .OrderByDescending(m => m.Year).ThenByDescending(m => m.Month).ToList();

        return new RevenueReportDto
        {
            TotalRevenue = paid.Sum(p => p.Amount),
            RevenueByCurrency = paid.GroupBy(p => p.Currency).ToDictionary(g => g.Key, g => g.Sum(p => p.Amount)),
            PaidPaymentsCount = paid.Count,
            PendingPaymentsCount = payments.Count(p => p.Status == PaymentStatus.Pending),
            FailedPaymentsCount = payments.Count(p => p.Status == PaymentStatus.Failed),
            MonthlyRevenue = monthly,
            RecentPayments = payments.Take(10).ToList()
        };
    }

    private static PaymentDto Map(Payment payment, Booking booking) => new()
    {
        Id = payment.Id,
        BookingId = payment.BookingId,
        BookingReference = booking.BookingReference,
        CustomerId = booking.CustomerId,
        CustomerName = booking.Customer?.FullName ?? string.Empty,
        Amount = payment.Amount,
        Currency = payment.Currency,
        Status = payment.Status,
        StripeReference = payment.StripeReference,
        FailureReason = payment.FailureReason,
        ExchangeRateToLkr = payment.ExchangeRateToLkr,
        PaymentDate = payment.PaymentDate
    };

    private static string? SafeFailure(string? message) =>
        string.IsNullOrWhiteSpace(message) ? "Stripe payment was not confirmed." : message[..Math.Min(500, message.Length)];
}

public sealed class PaymentAlreadyPaidException : InvalidOperationException
{
    public PaymentAlreadyPaidException(string message) : base(message) { }
}

public sealed class PaymentGatewayException : InvalidOperationException
{
    public PaymentGatewayException(string message, Exception innerException) : base(message, innerException) { }
}
