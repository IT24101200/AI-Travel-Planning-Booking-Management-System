using backend.DTOs;
using backend.Models.Enums;

namespace backend.Services
{
    public interface IBookingService
    {
        Task<BookingDto> CreateBookingAsync(BookingCreateDto dto);
        Task<BookingDto?> GetBookingByIdAsync(int id, string? userId = null, bool isStaff = false);
        Task<IEnumerable<BookingDto>> GetBookingsAsync(string? customerId = null, BookingStatus? status = null);
        Task<BookingDto> UpdateBookingStatusAsync(int id, BookingStatus newStatus);
        Task<IEnumerable<BookingDto>> GetPendingBookingsForApprovalAsync();
        Task<bool> DeleteBookingAsync(int id);
    }
}
