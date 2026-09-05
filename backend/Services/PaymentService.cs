using System.Globalization;
using backend.Data;
using backend.DTOs;
using backend.Models;
using backend.Models.Enums;
using Microsoft.EntityFrameworkCore;

namespace backend.Services
{
    public class PaymentService : IPaymentService
    {
        private readonly AppDbContext _db;
        private readonly IConfiguration _configuration;

        public PaymentService(AppDbContext db, IConfiguration configuration)
        {
            _db = db;
            _configuration = configuration;
        }

        public async Task<PaymentDto> ProcessPaymentAsync(PaymentCreateDto dto)
        {
            if (dto == null)
                throw new ArgumentNullException(nameof(dto));

            var booking = await _db.Bookings
                .Include(b => b.Customer)
                .FirstOrDefaultAsync(b => b.Id == dto.BookingId);

            if (booking == null)
                throw new KeyNotFoundException($"Booking with ID {dto.BookingId} not found.");

            // Rule 2: Non-negotiable guard — Payment ONLY fires after Confirmed!
            if (booking.Status != BookingStatus.Confirmed)
            {
                throw new InvalidOperationException(
                    $"Payment cannot be processed. Booking status is '{booking.Status}', but payment is only permitted when status is 'Confirmed'.");
            }

            var amount = dto.Amount > 0 ? dto.Amount : booking.TotalCost;
            var currency = string.IsNullOrWhiteSpace(dto.Currency) ? booking.Currency : dto.Currency;

            // Rule 7: Stripe Sandbox integration (synchronous success/fail response, no webhook/idempotency key)
            string stripeRef = $"ch_sb_{Guid.NewGuid().ToString("N").Substring(0, 16)}";
            PaymentStatus paymentStatus = PaymentStatus.Paid;

            // Simple failure simulation if token is specifically "tok_chargeDeclined"
            if (dto.StripeToken == "tok_chargeDeclined")
            {
                paymentStatus = PaymentStatus.Failed;
            }

            var payment = new Payment
            {
                BookingId = dto.BookingId,
                Amount = amount,
                Currency = currency,
                Status = paymentStatus,
                StripeReference = stripeRef,
                PaymentDate = DateTime.UtcNow
            };

            _db.Payments.Add(payment);
            await _db.SaveChangesAsync();

            return new PaymentDto
            {
                Id = payment.Id,
                BookingId = payment.BookingId,
                BookingReference = booking.BookingReference,
                CustomerName = booking.Customer?.FullName ?? string.Empty,
                Amount = payment.Amount,
                Currency = payment.Currency,
                Status = payment.Status,
                StripeReference = payment.StripeReference,
                PaymentDate = payment.PaymentDate
            };
        }

        public async Task<PaymentDto?> GetPaymentByIdAsync(int id)
        {
            var payment = await _db.Payments
                .Include(p => p.Booking)
                    .ThenInclude(b => b.Customer)
                .FirstOrDefaultAsync(p => p.Id == id);

            if (payment == null)
                return null;

            return new PaymentDto
            {
                Id = payment.Id,
                BookingId = payment.BookingId,
                BookingReference = payment.Booking?.BookingReference ?? string.Empty,
                CustomerName = payment.Booking?.Customer?.FullName ?? string.Empty,
                Amount = payment.Amount,
                Currency = payment.Currency,
                Status = payment.Status,
                StripeReference = payment.StripeReference,
                PaymentDate = payment.PaymentDate
            };
        }

        public async Task<IEnumerable<PaymentDto>> GetPaymentsByBookingIdAsync(int bookingId)
        {
            var payments = await _db.Payments
                .Include(p => p.Booking)
                    .ThenInclude(b => b.Customer)
                .Where(p => p.BookingId == bookingId)
                .OrderByDescending(p => p.PaymentDate)
                .ToListAsync();

            return payments.Select(p => new PaymentDto
            {
                Id = p.Id,
                BookingId = p.BookingId,
                BookingReference = p.Booking?.BookingReference ?? string.Empty,
                CustomerName = p.Booking?.Customer?.FullName ?? string.Empty,
                Amount = p.Amount,
                Currency = p.Currency,
                Status = p.Status,
                StripeReference = p.StripeReference,
                PaymentDate = p.PaymentDate
            });
        }

        public async Task<IEnumerable<PaymentDto>> GetAllPaymentsAsync()
        {
            var payments = await _db.Payments
                .Include(p => p.Booking)
                    .ThenInclude(b => b.Customer)
                .OrderByDescending(p => p.PaymentDate)
                .ToListAsync();

            return payments.Select(p => new PaymentDto
            {
                Id = p.Id,
                BookingId = p.BookingId,
                BookingReference = p.Booking?.BookingReference ?? string.Empty,
                CustomerName = p.Booking?.Customer?.FullName ?? string.Empty,
                Amount = p.Amount,
                Currency = p.Currency,
                Status = p.Status,
                StripeReference = p.StripeReference,
                PaymentDate = p.PaymentDate
            });
        }

        public async Task<RevenueReportDto> GetRevenueReportAsync()
        {
            var allPayments = await GetAllPaymentsAsync();
            var paymentList = allPayments.ToList();

            var totalRevenue = paymentList
                .Where(p => p.Status == PaymentStatus.Paid)
                .Sum(p => p.Amount);

            var monthlyRevenue = paymentList
                .Where(p => p.Status == PaymentStatus.Paid)
                .GroupBy(p => new { p.PaymentDate.Year, p.PaymentDate.Month })
                .Select(g => new MonthlyRevenueDto
                {
                    Year = g.Key.Year,
                    Month = g.Key.Month,
                    MonthName = CultureInfo.CurrentCulture.DateTimeFormat.GetMonthName(g.Key.Month),
                    Revenue = g.Sum(p => p.Amount)
                })
                .OrderByDescending(m => m.Year)
                .ThenByDescending(m => m.Month)
                .ToList();

            return new RevenueReportDto
            {
                TotalRevenue = totalRevenue,
                PaidPaymentsCount = paymentList.Count(p => p.Status == PaymentStatus.Paid),
                PendingPaymentsCount = paymentList.Count(p => p.Status == PaymentStatus.Pending),
                FailedPaymentsCount = paymentList.Count(p => p.Status == PaymentStatus.Failed),
                MonthlyRevenue = monthlyRevenue,
                RecentPayments = paymentList.Take(10).ToList()
            };
        }
    }
}
