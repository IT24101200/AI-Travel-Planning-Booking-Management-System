using System.Security.Claims;
using backend.DTOs;
using backend.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace backend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class CustomerController : ControllerBase
    {
        private readonly ICustomerService _customerService;

        public CustomerController(ICustomerService customerService)
        {
            _customerService = customerService;
        }

        /// <summary>
        /// Get the current authenticated customer's profile.
        /// </summary>
        [HttpGet("me")]
        [ProducesResponseType(typeof(CustomerDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> GetMyProfile()
        {
            var userId = GetUserId();
            var customer = await _customerService.GetByIdAsync(userId);

            if (customer == null)
                return NotFound(new { message = "Customer profile not found." });

            await _customerService.UpdateLastActiveAsync(userId);
            return Ok(customer);
        }

        /// <summary>
        /// Update the current authenticated customer's profile.
        /// </summary>
        [HttpPut("me")]
        [ProducesResponseType(typeof(CustomerDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> UpdateMyProfile([FromBody] CustomerUpdateDto dto)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            var userId = GetUserId();
            var updated = await _customerService.UpdateAsync(userId, dto);

            if (updated == null)
                return NotFound(new { message = "Customer profile not found." });

            return Ok(updated);
        }

        /// <summary>
        /// Get a specific customer's profile by ID.
        /// Customers can only view their own profile; TravelAgent and Admin can view any profile.
        /// </summary>
        [HttpGet("{id}")]
        [ProducesResponseType(typeof(CustomerDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status403Forbidden)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> GetById(string id)
        {
            var currentUserId = GetUserId();
            var isStaff = User.IsInRole("TravelAgent") || User.IsInRole("Admin");

            if (!isStaff && currentUserId != id)
            {
                return Forbid();
            }

            var customer = await _customerService.GetByIdAsync(id);

            if (customer == null)
                return NotFound(new { message = "Customer not found." });

            return Ok(customer);
        }

        /// <summary>
        /// List all customers with search, sort, and pagination (Staff Customer Directory).
        /// Only TravelAgent or Admin can access the full customer list.
        /// </summary>
        [HttpGet]
        [Authorize(Roles = "TravelAgent,Admin")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> GetAll(
            [FromQuery] string? search,
            [FromQuery] string? sortBy,
            [FromQuery] bool descending = false,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 10)
        {
            if (page < 1) page = 1;
            if (pageSize < 1) pageSize = 10;
            if (pageSize > 50) pageSize = 50;

            var customers = await _customerService.GetAllAsync(search, sortBy, descending, page, pageSize);
            var totalCount = await _customerService.GetTotalCountAsync(search);

            return Ok(new
            {
                data = customers,
                totalCount,
                page,
                pageSize,
                totalPages = (int)Math.Ceiling((double)totalCount / pageSize)
            });
        }

        private string GetUserId()
        {
            return User.FindFirstValue(ClaimTypes.NameIdentifier)
                ?? throw new UnauthorizedAccessException("User ID not found in token.");
        }
    }
}
