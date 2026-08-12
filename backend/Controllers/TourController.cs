using Microsoft.AspNetCore.Mvc;
using backend.DTOs;
using backend.Services;

namespace backend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class TourController : ControllerBase
    {
        private readonly TourService _service;

        public TourController(TourService service)
        {
            _service = service;
        }

        // GET /api/tour
        [HttpGet]
        public async Task<IActionResult> Search(
            [FromQuery] int? destinationId,
            [FromQuery] string? category,
            [FromQuery] decimal? minPrice,
            [FromQuery] decimal? maxPrice,
            [FromQuery] string? status,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 10)
        {
            var results = await _service.SearchAsync(
                destinationId, category, minPrice, maxPrice, status, page, pageSize);
            return Ok(results);
        }

        // GET /api/tour/{id}
        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(int id)
        {
            var tour = await _service.GetByIdAsync(id);
            if (tour is null) return NotFound();
            return Ok(tour);
        }

        // POST /api/tour
        [HttpPost]
        public async Task<IActionResult> Create([FromBody] CreateTourDto dto)
        {
            var created = await _service.CreateAsync(dto);
            return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
        }

        // PUT /api/tour/{id}
        [HttpPut("{id}")]
        public async Task<IActionResult> Update(int id, [FromBody] CreateTourDto dto)
        {
            var updated = await _service.UpdateAsync(id, dto);
            if (!updated) return NotFound();
            return NoContent();
        }

        // DELETE /api/tour/{id} — soft delete only
        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            var deleted = await _service.SoftDeleteAsync(id);
            if (!deleted) return NotFound();
            return NoContent();
        }
    }
}
