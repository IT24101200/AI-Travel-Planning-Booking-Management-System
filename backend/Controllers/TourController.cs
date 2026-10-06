using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using backend.DTOs;
using backend.Services;

namespace backend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class TourController : ControllerBase
    {
        private const long MaxImageBytes = 5 * 1024 * 1024;
        private static readonly HashSet<string> AllowedImageTypes =
            new(StringComparer.OrdinalIgnoreCase) { "image/jpeg", "image/png", "image/webp" };

        private readonly TourService _service;
        private readonly IWebHostEnvironment _environment;

        public TourController(TourService service, IWebHostEnvironment environment)
        {
            _service = service;
            _environment = environment;
        }

        // GET /api/tour
        [HttpGet]
        [AllowAnonymous]
        public async Task<IActionResult> Search(
            [FromQuery] string? search,
            [FromQuery] int? destinationId,
            [FromQuery] string? category,
            [FromQuery] decimal? minPrice,
            [FromQuery] decimal? maxPrice,
            [FromQuery] string? status,
            [FromQuery] string? sortBy,
            [FromQuery] bool descending = false,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 10)
        {
            var results = await _service.SearchAsync(
                search, destinationId, category, minPrice, maxPrice, status, sortBy, descending, page, pageSize);
            return Ok(results);
        }

        // GET /api/tour/{id}
        [HttpGet("{id}")]
        [AllowAnonymous]
        public async Task<IActionResult> GetById(int id)
        {
            var tour = await _service.GetByIdAsync(id);
            if (tour is null) return NotFound();
            return Ok(tour);
        }

        // POST /api/tour
        [HttpPost]
        [Authorize(Roles = "TravelAgent,Admin")]
        [Consumes("multipart/form-data")]
        public async Task<IActionResult> Create([FromForm] CreateTourDto dto, IFormFile? image)
        {
            var imageError = await ValidateImageAsync(image);
            if (imageError is not null)
                return BadRequest(new { message = imageError });

            string? savedFilePath = null;
            try
            {
                var uploadDirectory = Path.Combine(_environment.WebRootPath ?? Path.Combine(_environment.ContentRootPath, "wwwroot"), "uploads", "tours");
                Directory.CreateDirectory(uploadDirectory);

                var extension = Path.GetExtension(image!.FileName).ToLowerInvariant();
                var fileName = $"{Guid.NewGuid():N}{extension}";
                savedFilePath = Path.Combine(uploadDirectory, fileName);
                await using (var stream = System.IO.File.Create(savedFilePath))
                {
                    await image.CopyToAsync(stream);
                }

                dto.ImageUrl = $"/uploads/tours/{fileName}";
                var created = await _service.CreateAsync(dto);
                return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
            }
            catch (ArgumentException ex)
            {
                DeleteSavedFile(savedFilePath);
                return BadRequest(new { message = ex.Message });
            }
            catch
            {
                DeleteSavedFile(savedFilePath);
                throw;
            }
        }

        // PUT /api/tour/{id}
        [HttpPut("{id}")]
        [Authorize(Roles = "TravelAgent,Admin")]
        public async Task<IActionResult> Update(int id, [FromBody] CreateTourDto dto)
        {
            try
            {
                var updated = await _service.UpdateAsync(id, dto);
                if (!updated) return NotFound();
                return NoContent();
            }
            catch (ArgumentException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        // DELETE /api/tour/{id} — soft delete only
        [HttpDelete("{id}")]
        [Authorize(Roles = "TravelAgent,Admin")]
        public async Task<IActionResult> Delete(int id)
        {
            var deleted = await _service.SoftDeleteAsync(id);
            if (!deleted) return NotFound();
            return NoContent();
        }

        private static async Task<string?> ValidateImageAsync(IFormFile? image)
        {
            if (image is null || image.Length == 0)
                return "A tour image is required.";
            if (image.Length > MaxImageBytes)
                return "The image must be 5 MB or smaller.";

            var extension = Path.GetExtension(image.FileName).ToLowerInvariant();
            if (extension is not (".jpg" or ".jpeg" or ".png" or ".webp") || !AllowedImageTypes.Contains(image.ContentType))
                return "Only JPEG, PNG, and WebP images are allowed.";

            var header = new byte[12];
            await using var stream = image.OpenReadStream();
            var bytesRead = await stream.ReadAsync(header.AsMemory(0, header.Length));
            var isJpeg = bytesRead >= 3 && header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF;
            var isPng = bytesRead >= 8 && header.AsSpan(0, 8).SequenceEqual(new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A });
            var isWebP = bytesRead >= 12
                && System.Text.Encoding.ASCII.GetString(header, 0, 4) == "RIFF"
                && System.Text.Encoding.ASCII.GetString(header, 8, 4) == "WEBP";

            var signatureMatches = extension switch
            {
                ".jpg" or ".jpeg" => isJpeg,
                ".png" => isPng,
                ".webp" => isWebP,
                _ => false
            };
            return signatureMatches ? null : "The selected file is not a valid image.";
        }

        private static void DeleteSavedFile(string? path)
        {
            if (!string.IsNullOrWhiteSpace(path) && System.IO.File.Exists(path))
                System.IO.File.Delete(path);
        }
    }
}
