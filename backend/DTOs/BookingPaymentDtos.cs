using System.ComponentModel.DataAnnotations;
using backend.Models.Enums;

namespace backend.DTOs
{
    // ── Booking DTOs ──

    public class BookingCreateDto
    {
        [Required(ErrorMessage = "CustomerId is required.")]
        public string CustomerId { get; set; } = string.Empty;

        [Required(ErrorMessage = "ItineraryId is required.")]
        [Range(1, int.MaxValue, ErrorMessage = "ItineraryId must be a valid positive integer.")]
        public int ItineraryId { get; set; }

        [Range(0, double.MaxValue, ErrorMessage = "TotalCost cannot be negative.")]
        public decimal TotalCost { get; set; }

        [MaxLength(10)]
        public string Currency { get; set; } = "USD";

        [Required(ErrorMessage = "Items list cannot be null.")]
        [MinLength(1, ErrorMessage = "Booking must contain at least one item.")]
        public List<BookingItemCreateDto> Items { get; set; } = new List<BookingItemCreateDto>();
    }

    public class BookingItemCreateDto
    {
        [Required(ErrorMessage = "ItemType is required.")]
        public BookingItemType ItemType { get; set; }

        public int? TourId { get; set; }
        public int? RoomId { get; set; }
        public int? TransportOptionId { get; set; }

        public DateTime? CheckInDate { get; set; }
        public DateTime? CheckOutDate { get; set; }

        [Range(1, 1000, ErrorMessage = "Quantity must be at least 1.")]
        public int Quantity { get; set; } = 1;

        [Range(0, double.MaxValue, ErrorMessage = "UnitPrice cannot be negative.")]
        public decimal UnitPrice { get; set; }
    }

    public class BookingDto
    {
        public int Id { get; set; }
        public string BookingReference { get; set; } = string.Empty;
        public string CustomerId { get; set; } = string.Empty;
        public string CustomerName { get; set; } = string.Empty;
        public int ItineraryId { get; set; }
        public int TripRequestId { get; set; }
        public BookingStatus Status { get; set; }
        public decimal TotalCost { get; set; }
        public string Currency { get; set; } = "USD";
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }

        public List<BookingItemDto> BookingItems { get; set; } = new List<BookingItemDto>();
        public List<ApprovalDto> BookingApprovals { get; set; } = new List<ApprovalDto>();
        public List<PaymentDto> Payments { get; set; } = new List<PaymentDto>();
        public List<AgentLogDto> AgentLogs { get; set; } = new List<AgentLogDto>();
    }

    public class BookingItemDto
    {
        public int Id { get; set; }
        public int BookingId { get; set; }
        public BookingItemType ItemType { get; set; }
        public int? TourId { get; set; }
        public string? TourName { get; set; }
        public int? RoomId { get; set; }
        public int? TransportOptionId { get; set; }
        public DateTime? CheckInDate { get; set; }
        public DateTime? CheckOutDate { get; set; }
        public int Quantity { get; set; }
        public decimal UnitPrice { get; set; }
        public decimal Subtotal { get; set; }
    }

    public class BookingStatusUpdateDto
    {
        [Required(ErrorMessage = "Status is required.")]
        public BookingStatus Status { get; set; }
    }

    // ── Approval DTOs ──

    public class ApprovalCreateDto
    {
        [Required(ErrorMessage = "BookingId is required.")]
        [Range(1, int.MaxValue, ErrorMessage = "BookingId must be a valid positive integer.")]
        public int BookingId { get; set; }

        [Required(ErrorMessage = "Decision is required.")]
        public ApprovalDecision Decision { get; set; }

        [MaxLength(1000, ErrorMessage = "Comment cannot exceed 1000 characters.")]
        public string Comment { get; set; } = string.Empty;
    }

    public class ApprovalDto
    {
        public int Id { get; set; }
        public int BookingId { get; set; }
        public string TravelAgentId { get; set; } = string.Empty;
        public string TravelAgentName { get; set; } = string.Empty;
        public ApprovalDecision Decision { get; set; }
        public string Comment { get; set; } = string.Empty;
        public DateTime DecidedAt { get; set; }
    }

    // ── Payment DTOs ──

    public class PaymentCreateDto
    {
        [Required(ErrorMessage = "BookingId is required.")]
        [Range(1, int.MaxValue, ErrorMessage = "BookingId must be a valid positive integer.")]
        public int BookingId { get; set; }

        [Range(0, double.MaxValue, ErrorMessage = "Amount cannot be negative.")]
        public decimal Amount { get; set; }

        [MaxLength(10)]
        public string Currency { get; set; } = "USD";

        /// <summary>
        /// Stripe Sandbox test card token (default: tok_visa).
        /// </summary>
        public string StripeToken { get; set; } = "tok_visa";
    }

    public class PaymentDto
    {
        public int Id { get; set; }
        public int BookingId { get; set; }
        public string BookingReference { get; set; } = string.Empty;
        public string CustomerId { get; set; } = string.Empty;
        public string CustomerName { get; set; } = string.Empty;
        public decimal Amount { get; set; }
        public string Currency { get; set; } = "USD";
        public PaymentStatus Status { get; set; }
        public string? StripeReference { get; set; }
        public DateTime PaymentDate { get; set; }
    }

    public class RevenueReportDto
    {
        public decimal TotalRevenue { get; set; }
        public int PaidPaymentsCount { get; set; }
        public int PendingPaymentsCount { get; set; }
        public int FailedPaymentsCount { get; set; }
        public List<MonthlyRevenueDto> MonthlyRevenue { get; set; } = new List<MonthlyRevenueDto>();
        public List<PaymentDto> RecentPayments { get; set; } = new List<PaymentDto>();
    }

    public class MonthlyRevenueDto
    {
        public int Year { get; set; }
        public int Month { get; set; }
        public string MonthName { get; set; } = string.Empty;
        public decimal Revenue { get; set; }
    }
}
