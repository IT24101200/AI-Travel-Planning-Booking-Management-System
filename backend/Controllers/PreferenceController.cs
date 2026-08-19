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

        private string GetUserId()
        {
            return User.FindFirstValue(ClaimTypes.NameIdentifier)
                ?? throw new UnauthorizedAccessException("User ID not found in token.");
        }
    }
}
