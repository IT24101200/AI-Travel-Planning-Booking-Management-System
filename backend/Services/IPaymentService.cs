using backend.DTOs;

namespace backend.Services
{
    public interface IPaymentService
    {
        Task<PaymentDto> ProcessPaymentAsync(PaymentCreateDto dto);
        Task<PaymentDto?> GetPaymentByIdAsync(int id);
        Task<IEnumerable<PaymentDto>> GetPaymentsByBookingIdAsync(int bookingId);
        Task<IEnumerable<PaymentDto>> GetAllPaymentsAsync();
        Task<RevenueReportDto> GetRevenueReportAsync();
    }
}
