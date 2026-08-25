using backend.DTOs;
using backend.Services;
using Microsoft.AspNetCore.Mvc;

namespace backend.Controllers
{
    /// <summary>
    /// Student D — Payment API Controller.
    /// Integrates with Stripe Sandbox for payment processing and revenue reports.
    /// </summary>
    [ApiController]
    [Route("api/[controller]")]
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
        /// </summary>
        [HttpGet("{id}")]
        [ProducesResponseType(typeof(PaymentDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> GetPaymentById(int id)
        {
            var payment = await _paymentService.GetPaymentByIdAsync(id);
            if (payment == null)
                return NotFound(new { message = $"Payment with ID {id} not found." });

            return Ok(payment);
        }

        /// <summary>
        /// Get all payments for a specific booking.
        /// </summary>
        [HttpGet("booking/{bookingId}")]
        [ProducesResponseType(typeof(IEnumerable<PaymentDto>), StatusCodes.Status200OK)]
        public async Task<IActionResult> GetPaymentsByBooking(int bookingId)
        {
            var result = await _paymentService.GetPaymentsByBookingIdAsync(bookingId);
            return Ok(result);
        }

        /// <summary>
        /// Get all payment records.
        /// </summary>
        [HttpGet]
        [ProducesResponseType(typeof(IEnumerable<PaymentDto>), StatusCodes.Status200OK)]
        public async Task<IActionResult> GetAllPayments()
        {
            var result = await _paymentService.GetAllPaymentsAsync();
            return Ok(result);
        }

        /// <summary>
        /// Get Revenue Summary & Monthly Analytics Report for Staff Dashboard.
        /// </summary>
        [HttpGet("revenue-report")]
        [ProducesResponseType(typeof(RevenueReportDto), StatusCodes.Status200OK)]
        public async Task<IActionResult> GetRevenueReport()
        {
            var report = await _paymentService.GetRevenueReportAsync();
            return Ok(report);
        }
    }
}
