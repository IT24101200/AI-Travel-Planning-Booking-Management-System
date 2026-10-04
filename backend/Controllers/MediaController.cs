using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace backend.Controllers
{
    /// <summary>
    /// Controller for staff and admin media management.
    /// Uploads and manages images in Supabase Cloud Storage (with local backup).
    /// Note: User profile images are strictly excluded and cannot be managed here.
    /// </summary>
    [ApiController]
    [Route("api/[controller]")]
    [Authorize(Roles = "TravelAgent,Admin")]
    public class MediaController : ControllerBase
    {
        private const long MaxImageBytes = 5 * 1024 * 1024; // 5 MB max
        private const string BucketName = "catalog-images";

        private static readonly HashSet<string> AllowedImageTypes =
            new(StringComparer.OrdinalIgnoreCase) { "image/jpeg", "image/png", "image/webp" };

        private static readonly HashSet<string> AllowedCategories =
            new(StringComparer.OrdinalIgnoreCase) { "tours", "destinations", "hotels", "transport", "general" };

        private readonly IWebHostEnvironment _environment;
        private readonly IConfiguration _configuration;
        private readonly IHttpClientFactory _httpClientFactory;
        private readonly string? _supabaseUrl;
        private readonly string? _supabaseKey;

        public MediaController(
            IWebHostEnvironment environment,
            IConfiguration configuration,
            IHttpClientFactory httpClientFactory)
        {
            _environment = environment;
            _configuration = configuration;
            _httpClientFactory = httpClientFactory;

            // Resolve Supabase credentials
            _supabaseUrl = (_configuration["SUPABASE_URL"]
                ?? Environment.GetEnvironmentVariable("SUPABASE_URL"))?
                .Trim(' ', '"', '\'')
                .TrimEnd('/');

            _supabaseKey = (_configuration["SUPABASE_ANON_KEY"]
                ?? _configuration["SUPABASE_KEY"]
                ?? Environment.GetEnvironmentVariable("SUPABASE_ANON_KEY")
                ?? Environment.GetEnvironmentVariable("SUPABASE_KEY"))?
                .Trim(' ', '"', '\'');
        }

        /// <summary>
        /// Upload a catalog image directly to Supabase Cloud Storage.
        /// POST /api/media/upload?category=tours
        /// </summary>
        [HttpPost("upload")]
        [Consumes("multipart/form-data")]
        public async Task<IActionResult> Upload(IFormFile? file, [FromQuery] string category = "general")
        {
            // Sanitize category
            var safeCategory = (category ?? "general").Trim().ToLowerInvariant();

            // Strict rule: profile pictures are not managed by staff media catalog
            if (safeCategory.Contains("profile"))
            {
                return BadRequest(new { message = "User profile images cannot be managed through the staff media catalog." });
            }

            if (!AllowedCategories.Contains(safeCategory))
            {
                safeCategory = "general";
            }

            // Validate file presence and format
            var validationError = await ValidateImageAsync(file);
            if (validationError is not null)
            {
                return BadRequest(new { message = validationError });
            }

            var extension = Path.GetExtension(file!.FileName).ToLowerInvariant();
            var uniqueFileName = $"{Guid.NewGuid():N}{extension}";
            string? publicUrl = null;

            // 1. Try uploading to Supabase Cloud Storage
            if (!string.IsNullOrWhiteSpace(_supabaseUrl) && !string.IsNullOrWhiteSpace(_supabaseKey))
            {
                try
                {
                    var client = _httpClientFactory.CreateClient();
                    var requestUri = $"{_supabaseUrl}/storage/v1/object/{BucketName}/{safeCategory}/{uniqueFileName}";

                    using var request = new HttpRequestMessage(HttpMethod.Post, requestUri);
                    request.Headers.Add("apikey", _supabaseKey);
                    request.Headers.Add("Authorization", $"Bearer {_supabaseKey}");

                    await using var fileStream = file.OpenReadStream();
                    using var streamContent = new StreamContent(fileStream);
                    streamContent.Headers.ContentType = new System.Net.Http.Headers.MediaTypeHeaderValue(file.ContentType);
                    request.Content = streamContent;

                    var response = await client.SendAsync(request);
                    if (response.IsSuccessStatusCode)
                    {
                        publicUrl = $"{_supabaseUrl}/storage/v1/object/public/{BucketName}/{safeCategory}/{uniqueFileName}";
                    }
                }
                catch (Exception ex)
                {
                    // Log cloud upload attempt failure, will fall back to local disk
                    Console.WriteLine($"[MediaController] Supabase cloud upload fallback: {ex.Message}");
                }
            }

            // 2. Also save local copy in wwwroot/uploads as backup/fallback
            try
            {
                var uploadsRoot = GetUploadsRootDirectory();
                var targetDirectory = Path.Combine(uploadsRoot, safeCategory);
                Directory.CreateDirectory(targetDirectory);
                var savedFilePath = Path.Combine(targetDirectory, uniqueFileName);

                await using (var stream = System.IO.File.Create(savedFilePath))
                {
                    await file.CopyToAsync(stream);
                }

                // If cloud URL wasn't generated, use the local static URL
                publicUrl ??= $"/uploads/{safeCategory}/{uniqueFileName}";

                return Ok(new
                {
                    url = publicUrl,
                    fileName = file.FileName,
                    storedFileName = uniqueFileName,
                    category = safeCategory,
                    sizeBytes = file.Length,
                    uploadedAt = DateTime.UtcNow,
                    storage = publicUrl.StartsWith("http", StringComparison.OrdinalIgnoreCase) ? "supabase-cloud" : "local"
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = $"Failed to save uploaded file: {ex.Message}" });
            }
        }

        /// <summary>
        /// List all uploaded media files from Supabase Cloud Storage and local storage.
        /// GET /api/media?category=tours&search=beach
        /// </summary>
        [HttpGet]
        public async Task<IActionResult> GetAll([FromQuery] string? category, [FromQuery] string? search)
        {
            try
            {
                var filterCategory = category?.Trim().ToLowerInvariant();
                var searchTerm = search?.Trim().ToLowerInvariant();
                var mediaList = new List<MediaItemDto>();
                var seenUrls = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

                // 1. Fetch from Supabase Cloud Storage if configured
                if (!string.IsNullOrWhiteSpace(_supabaseUrl) && !string.IsNullOrWhiteSpace(_supabaseKey))
                {
                    try
                    {
                        var client = _httpClientFactory.CreateClient();

                        foreach (var cat in AllowedCategories)
                        {
                            if (!string.IsNullOrWhiteSpace(filterCategory) && filterCategory != "all" && filterCategory != cat)
                            {
                                continue;
                            }

                            var requestUri = $"{_supabaseUrl}/storage/v1/object/list/{BucketName}";
                            using var request = new HttpRequestMessage(HttpMethod.Post, requestUri);
                            request.Headers.Add("apikey", _supabaseKey);
                            request.Headers.Add("Authorization", $"Bearer {_supabaseKey}");

                            var payload = JsonSerializer.Serialize(new
                            {
                                prefix = cat,
                                limit = 100,
                                sortBy = new { column = "created_at", order = "desc" }
                            });
                            request.Content = new StringContent(payload, Encoding.UTF8, "application/json");

                            var response = await client.SendAsync(request);
                            if (response.IsSuccessStatusCode)
                            {
                                var json = await response.Content.ReadAsStringAsync();
                                var items = JsonSerializer.Deserialize<List<SupabaseStorageItem>>(json);
                                if (items != null)
                                {
                                    foreach (var item in items)
                                    {
                                        if (string.IsNullOrWhiteSpace(item.Name) || item.Name.EndsWith("/")) continue;

                                        var publicUrl = $"{_supabaseUrl}/storage/v1/object/public/{BucketName}/{cat}/{item.Name}";
                                        if (seenUrls.Add(publicUrl))
                                        {
                                            if (!string.IsNullOrWhiteSpace(searchTerm) &&
                                                !item.Name.ToLowerInvariant().Contains(searchTerm) &&
                                                !cat.Contains(searchTerm))
                                            {
                                                continue;
                                            }

                                            mediaList.Add(new MediaItemDto
                                            {
                                                Url = publicUrl,
                                                FileName = item.Name,
                                                Category = cat,
                                                SizeBytes = item.Metadata?.Size ?? 0,
                                                LastModified = item.CreatedAt ?? DateTime.UtcNow
                                            });
                                        }
                                    }
                                }
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine($"[MediaController] Error listing Supabase files: {ex.Message}");
                    }
                }

                // 2. Also merge local media files if any
                var uploadsRoot = GetUploadsRootDirectory();
                if (Directory.Exists(uploadsRoot))
                {
                    foreach (var cat in AllowedCategories)
                    {
                        if (!string.IsNullOrWhiteSpace(filterCategory) && filterCategory != "all" && filterCategory != cat)
                        {
                            continue;
                        }

                        var categoryPath = Path.Combine(uploadsRoot, cat);
                        if (!Directory.Exists(categoryPath)) continue;

                        var dirInfo = new DirectoryInfo(categoryPath);
                        var files = dirInfo.GetFiles()
                            .Where(f => f.Extension.Equals(".jpg", StringComparison.OrdinalIgnoreCase) ||
                                        f.Extension.Equals(".jpeg", StringComparison.OrdinalIgnoreCase) ||
                                        f.Extension.Equals(".png", StringComparison.OrdinalIgnoreCase) ||
                                        f.Extension.Equals(".webp", StringComparison.OrdinalIgnoreCase));

                        foreach (var f in files)
                        {
                            var localUrl = $"/uploads/{cat}/{f.Name}";
                            // Avoid duplicate if already fetched with same filename
                            if (seenUrls.Any(u => u.EndsWith(f.Name, StringComparison.OrdinalIgnoreCase))) continue;

                            if (!string.IsNullOrWhiteSpace(searchTerm) &&
                                !f.Name.ToLowerInvariant().Contains(searchTerm) &&
                                !cat.Contains(searchTerm))
                            {
                                continue;
                            }

                            seenUrls.Add(localUrl);
                            mediaList.Add(new MediaItemDto
                            {
                                Url = localUrl,
                                FileName = f.Name,
                                Category = cat,
                                SizeBytes = f.Length,
                                LastModified = f.LastWriteTimeUtc
                            });
                        }
                    }
                }

                return Ok(mediaList.OrderByDescending(m => m.LastModified).ToList());
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = $"Failed to retrieve media library: {ex.Message}" });
            }
        }

        /// <summary>
        /// Delete an uploaded media file from cloud and/or local storage.
        /// DELETE /api/media?url=...
        /// </summary>
        [HttpDelete]
        public async Task<IActionResult> Delete([FromQuery] string url)
        {
            if (string.IsNullOrWhiteSpace(url))
            {
                return BadRequest(new { message = "Image URL is required for deletion." });
            }

            try
            {
                // Strict check: Prevent deleting profile images
                if (url.Contains("profile", StringComparison.OrdinalIgnoreCase))
                {
                    return BadRequest(new { message = "User profile images cannot be deleted via the media catalog." });
                }

                // 1. Delete from Supabase Storage if it's a Supabase URL
                if (url.StartsWith("http", StringComparison.OrdinalIgnoreCase) && url.Contains(BucketName))
                {
                    if (!string.IsNullOrWhiteSpace(_supabaseUrl) && !string.IsNullOrWhiteSpace(_supabaseKey))
                    {
                        var marker = $"/storage/v1/object/public/{BucketName}/";
                        var idx = url.IndexOf(marker, StringComparison.OrdinalIgnoreCase);
                        if (idx >= 0)
                        {
                            var objectPath = url.Substring(idx + marker.Length);
                            var client = _httpClientFactory.CreateClient();
                            var requestUri = $"{_supabaseUrl}/storage/v1/object/{BucketName}/{objectPath}";

                            using var request = new HttpRequestMessage(HttpMethod.Delete, requestUri);
                            request.Headers.Add("apikey", _supabaseKey);
                            request.Headers.Add("Authorization", $"Bearer {_supabaseKey}");

                            await client.SendAsync(request);
                        }
                    }
                }

                // 2. Also delete local copy if present
                var uploadsRoot = Path.GetFullPath(GetUploadsRootDirectory());
                var fileName = Path.GetFileName(new Uri(url.StartsWith("http") ? url : $"http://localhost{url}").AbsolutePath);

                foreach (var cat in AllowedCategories)
                {
                    var localFile = Path.Combine(uploadsRoot, cat, fileName);
                    if (System.IO.File.Exists(localFile))
                    {
                        System.IO.File.Delete(localFile);
                    }
                }

                return Ok(new { message = "Media file deleted successfully." });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = $"Error deleting media file: {ex.Message}" });
            }
        }

        // ── Helper Methods ───────────────────────────────────────────────────

        private string GetUploadsRootDirectory()
        {
            var webRoot = _environment.WebRootPath ?? Path.Combine(_environment.ContentRootPath, "wwwroot");
            var uploads = Path.Combine(webRoot, "uploads");
            if (!Directory.Exists(uploads))
            {
                Directory.CreateDirectory(uploads);
            }
            return uploads;
        }

        private static async Task<string?> ValidateImageAsync(IFormFile? image)
        {
            if (image is null || image.Length == 0)
                return "An image file is required.";

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
                && Encoding.ASCII.GetString(header, 0, 4) == "RIFF"
                && Encoding.ASCII.GetString(header, 8, 4) == "WEBP";

            var signatureMatches = extension switch
            {
                ".jpg" or ".jpeg" => isJpeg,
                ".png" => isPng,
                ".webp" => isWebP,
                _ => false
            };

            return signatureMatches ? null : "The selected file is not a valid image.";
        }
    }

    public class MediaItemDto
    {
        public string Url { get; set; } = string.Empty;
        public string FileName { get; set; } = string.Empty;
        public string Category { get; set; } = string.Empty;
        public long SizeBytes { get; set; }
        public DateTime LastModified { get; set; }
    }

    public class SupabaseStorageItem
    {
        [JsonPropertyName("name")]
        public string? Name { get; set; }

        [JsonPropertyName("created_at")]
        public DateTime? CreatedAt { get; set; }

        [JsonPropertyName("metadata")]
        public SupabaseStorageMetadata? Metadata { get; set; }
    }

    public class SupabaseStorageMetadata
    {
        [JsonPropertyName("size")]
        public long Size { get; set; }

        [JsonPropertyName("mimetype")]
        public string? MimeType { get; set; }
    }
}
