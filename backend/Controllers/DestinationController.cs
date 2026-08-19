using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using backend.DTOs;
using backend.Services;

namespace backend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class DestinationController : ControllerBase
    {
        private readonly DestinationService _service;

        public DestinationController(DestinationService service)
        {
            _service = service;
        }

        // GET /api/destinations
        [HttpGet]
        [Authorize]
        public async Task<IActionResult> GetAll()
        {
            var destinations = await _service.GetAllAsync();
            return Ok(destinations);
        }

        // GET /api/destinations/{id}
        [HttpGet("{id}")]
        [Authorize]
        public async Task<IActionResult> GetById(int id)
        {
            var destination = await _service.GetByIdAsync(id);
            if (destination is null) return NotFound();
            return Ok(destination);
        }

        // POST /api/destinations
        [HttpPost]
        [Authorize(Roles = "TravelAgent,Admin")]
        public async Task<IActionResult> Create([FromBody] CreateDestinationDto dto)
        {
            var created = await _service.CreateAsync(dto);
            return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
        }

        // PUT /api/destinations/{id}
        [HttpPut("{id}")]
        [Authorize(Roles = "TravelAgent,Admin")]
        public async Task<IActionResult> Update(int id, [FromBody] CreateDestinationDto dto)
        {
            var updated = await _service.UpdateAsync(id, dto);
            if (!updated) return NotFound();
            return NoContent();
        }

        // DELETE /api/destinations/{id}
        [HttpDelete("{id}")]
        [Authorize(Roles = "TravelAgent,Admin")]
        public async Task<IActionResult> Delete(int id)
        {
            var deleted = await _service.DeleteAsync(id);
            if (!deleted) return NotFound();
            return NoContent();
        }
    }
}
