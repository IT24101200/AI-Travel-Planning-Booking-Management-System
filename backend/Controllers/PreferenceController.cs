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
    public class PreferenceController : ControllerBase
    {
        private readonly IPreferenceService _preferenceService;
        private readonly ICustomerService _customerService;

        public PreferenceController(IPreferenceService preferenceService, ICustomerService customerService)
        {
            _preferenceService = preferenceService;
            _customerService = customerService;
        }

        /// <summary>
        /// Get the current customer's preferences.
        /// </summary>
        [HttpGet]
        [ProducesResponseType(typeof(PreferenceDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> GetMyPreferences()
        {
            var userId = GetUserId();
            var pref = await _preferenceService.GetByCustomerIdAsync(userId);

            if (pref == null)
                return NotFound(new { message = "Preferences not found. Please create your preferences first." });

            return Ok(pref);
        }

        /// <summary>
        /// Create or update the current customer's preferences.
        /// </summary>
        [HttpPut]
        [ProducesResponseType(typeof(PreferenceDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        public async Task<IActionResult> CreateOrUpdatePreferences([FromBody] PreferenceUpdateDto dto)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            var userId = GetUserId();

            // Verify customer exists
            if (!await _customerService.ExistsAsync(userId))
                return NotFound(new { message = "Customer profile not found." });

            try
            {
                var result = await _preferenceService.CreateOrUpdateAsync(userId, dto);
                return Ok(result);
            }
            catch (ArgumentException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        /// <summary>
        /// Search preferences with optional filters and pagination. TravelAgent or Admin only.
        /// </summary>
        [HttpGet("search")]
        [Authorize(Roles = "TravelAgent,Admin")]
        [ProducesResponseType(typeof(List<PreferenceDto>), StatusCodes.Status200OK)]
        public async Task<IActionResult> Search(
            [FromQuery] string? customerId,
            [FromQuery] decimal? minBudget,
            [FromQuery] decimal? maxBudget,
            [FromQuery] string? sortBy,
            [FromQuery] bool descending = false,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 10)
        {
            if (page < 1) page = 1;
            if (pageSize < 1) pageSize = 10;
            if (pageSize > 50) pageSize = 50;

            var prefs = await _preferenceService.SearchAsync(customerId, minBudget, maxBudget, sortBy, descending, page, pageSize);
            return Ok(prefs);
        }

        private string GetUserId()
        {
            return User.FindFirstValue(ClaimTypes.NameIdentifier)
                ?? throw new UnauthorizedAccessException("User ID not found in token.");
        }
    }
}
