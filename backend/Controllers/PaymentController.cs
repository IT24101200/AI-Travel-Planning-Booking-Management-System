using backend.DTOs;
using backend.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace backend.Controllers
{
    /// <summary>
    /// Student D — Payment API Controller.
    /// Integrates with Stripe Sandbox for payment processing and revenue reports.
    /// </summary>
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class PaymentController : ControllerBase
    {
        private readonly IPaymentService _paymentService;

        public PaymentController(IPaymentService paymentService)
        {
            _paymentService = paymentService;
        }

        /// <summary>
        /// Process payment through Stripe Sandbox.
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
                var payment = await _paymentService.ProcessPaymentAsync(dto);
                return CreatedAtAction(nameof(GetPaymentById), new { id = payment.Id }, payment);
            }
            catch (KeyNotFoundException ex)
            {
                return NotFound(new { message = ex.Message });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
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
            var result = (await _paymentService.GetPaymentsByBookingIdAsync(bookingId)).ToList();
            if (result.Any())
            {
                var currentUserId = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
                var isStaff = User.IsInRole("TravelAgent") || User.IsInRole("Admin");

                if (!isStaff && result.First().CustomerId != currentUserId)
                {
                    return Forbid();
                }
            }

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
