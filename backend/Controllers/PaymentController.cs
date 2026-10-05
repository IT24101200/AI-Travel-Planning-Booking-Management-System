using backend.DTOs;
using backend.Services;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace backend.Controllers
{
    /// <summary>
    /// Student D — Payment API Controller.
    /// Integrates with Stripe TEST Mode for payment processing and revenue reports.
    /// </summary>
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class PaymentController : ControllerBase
    {
        private readonly IPaymentService _paymentService;
        private readonly IBookingService _bookingService;

        public PaymentController(IPaymentService paymentService, IBookingService bookingService)
        {
            _paymentService = paymentService;
            _bookingService = bookingService;
        }

        /// <summary>
        /// Process payment through a server-side Stripe TEST Mode PaymentIntent.
        /// Rule 2 Guard: Returns 400 Bad Request if booking status is NOT Confirmed.
        /// </summary>
        [HttpPost]
        [ProducesResponseType(typeof(PaymentDto), StatusCodes.Status201Created)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> ProcessPayment([FromBody] PaymentCreateDto dto)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            try
            {
                var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
                if (string.IsNullOrWhiteSpace(userId))
                    return Unauthorized(new { message = "An authenticated customer identity is required for payment." });
                if (User.IsInRole("TravelAgent") || User.IsInRole("Admin"))
                    return Forbid();

                var booking = await _bookingService.GetBookingByIdAsync(dto.BookingId, userId, false);
                if (booking == null)
                    return NotFound(new { message = $"Booking with ID {dto.BookingId} not found." });

                var payment = await _paymentService.ProcessPaymentAsync(dto);
                return CreatedAtAction(nameof(GetPaymentById), new { id = payment.Id }, payment);
            }
            catch (KeyNotFoundException ex)
            {
                return NotFound(new { message = ex.Message });
            }
            catch (PaymentAlreadyPaidException ex)
            {
                return Conflict(new { message = ex.Message });
            }
            catch (PaymentGatewayException ex)
            {
                return StatusCode(StatusCodes.Status502BadGateway, new { message = ex.Message });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
            catch (UnauthorizedAccessException)
            {
                return Forbid();
            }
        }

        /// <summary>
        /// Get payment details by ID.
        /// Verified for ownership: customers can only view their own payment.
        /// </summary>
        [HttpGet("{id}")]
        [ProducesResponseType(typeof(PaymentDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status403Forbidden)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> GetPaymentById(int id)
        {
            var payment = await _paymentService.GetPaymentByIdAsync(id);
            if (payment == null)
                return NotFound(new { message = $"Payment with ID {id} not found." });

            var currentUserId = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
            var isStaff = User.IsInRole("TravelAgent") || User.IsInRole("Admin");

            if (!isStaff && payment.CustomerId != currentUserId)
            {
                return Forbid();
            }

            return Ok(payment);
        }

        /// <summary>
        /// Get all payments for a specific booking.
        /// Verified for ownership: customers can only view payments for their own booking.
        /// </summary>
        [HttpGet("booking/{bookingId}")]
        [ProducesResponseType(typeof(IEnumerable<PaymentDto>), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status403Forbidden)]
        public async Task<IActionResult> GetPaymentsByBooking(int bookingId)
        {
            var currentUserId = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
            var isStaff = User.IsInRole("TravelAgent") || User.IsInRole("Admin");
            try
            {
                var booking = await _bookingService.GetBookingByIdAsync(bookingId, currentUserId, isStaff);
                if (booking == null)
                    return NotFound(new { message = $"Booking with ID {bookingId} not found." });
            }
            catch (UnauthorizedAccessException)
            {
                return Forbid();
            }

            var result = (await _paymentService.GetPaymentsByBookingIdAsync(bookingId)).ToList();
            return Ok(result);
        }

        /// <summary>
        /// Get all payment records. Only TravelAgent or Admin can view all payments.
        /// </summary>
        [HttpGet]
        [Authorize(Roles = "TravelAgent,Admin")]
        [ProducesResponseType(typeof(IEnumerable<PaymentDto>), StatusCodes.Status200OK)]
        public async Task<IActionResult> GetAllPayments()
        {
            var result = await _paymentService.GetAllPaymentsAsync();
            return Ok(result);
        }

        /// <summary>
        /// Get Revenue Summary & Monthly Analytics Report for Staff Dashboard.
        /// Only TravelAgent or Admin can view the revenue report.
        /// </summary>
        [HttpGet("revenue-report")]
        [Authorize(Roles = "TravelAgent,Admin")]
        [ProducesResponseType(typeof(RevenueReportDto), StatusCodes.Status200OK)]
        public async Task<IActionResult> GetRevenueReport()
        {
            var report = await _paymentService.GetRevenueReportAsync();
            return Ok(report);
        }
    }
}
