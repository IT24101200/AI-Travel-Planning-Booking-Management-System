using System.ComponentModel.DataAnnotations;
using backend.Data;
using backend.Models;
using backend.Models.Enums;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;

namespace backend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AuthController : ControllerBase
    {
        private readonly UserManager<IdentityUser> _userManager;
        private readonly SignInManager<IdentityUser> _signInManager;
        private readonly IConfiguration _configuration;
        private readonly AppDbContext _db;

        public AuthController(
            UserManager<IdentityUser> userManager,
            SignInManager<IdentityUser> signInManager,
            IConfiguration configuration,
            AppDbContext db)
        {
            _userManager = userManager;
            _signInManager = signInManager;
            _configuration = configuration;
            _db = db;
        }

        /// <summary>
        /// Register a new customer account.
        /// </summary>
        [HttpPost("register")]
        [AllowAnonymous]
        [ProducesResponseType(StatusCodes.Status201Created)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        public async Task<IActionResult> Register([FromBody] RegisterDto dto)
        {
            if (!ModelState.IsValid)
            {
                var errors = ModelState.Values.SelectMany(v => v.Errors).Select(e => e.ErrorMessage).ToList();
                return BadRequest(new { message = "Validation failed.", errors = errors });
            }

            var existingUser = await _userManager.FindByEmailAsync(dto.Email);
            if (existingUser != null)
                return BadRequest(new { message = "An account with this email already exists." });

            var user = new IdentityUser
            {
                UserName = dto.Email,
                Email = dto.Email
            };

            var result = await _userManager.CreateAsync(user, dto.Password);
            if (!result.Succeeded)
            {
                return BadRequest(new { message = "Registration failed.", errors = result.Errors.Select(e => e.Description) });
            }

            // Assign Customer role in ASP.NET Identity
            await _userManager.AddToRoleAsync(user, "Customer");

            // Create the Customer profile linked to the Identity user
            var customer = new Customer
            {
                Id = user.Id,
                FullName = dto.FullName,
                Phone = dto.Phone,
                JoinedAt = DateTime.UtcNow,
                LastActiveAt = DateTime.UtcNow,
                Role = "Customer"
            };

            _db.Customers.Add(customer);

            // Create welcome alert in database
            _db.Notifications.AddRange(
                new Notification
                {
                    CustomerId = user.Id,
                    Channel = NotificationChannel.InApp,
                    MessageType = MessageType.SystemAlert,
                    Content = $"Welcome to Serendib Trails, {dto.FullName}! Your AI multi-agent travel concierge is active and ready.",
                    Status = NotificationStatus.Sent,
                    SentAt = DateTime.UtcNow
                },
                new Notification
                {
                    CustomerId = user.Id,
                    Channel = NotificationChannel.InApp,
                    MessageType = MessageType.TripUpdate,
                    Content = "Discover Sri Lanka: Explore curated tours in Ella, Sigiriya, Mirissa, and Yala National Park.",
                    Status = NotificationStatus.Sent,
                    SentAt = DateTime.UtcNow.AddSeconds(1)
                }
            );
            await _db.SaveChangesAsync();

            var token = await GenerateJwtTokenAsync(user);

            return Created("", new
            {
                message = "Registration successful.",
                token,
                userId = user.Id,
                email = user.Email,
                fullName = customer.FullName
            });
        }

        /// <summary>
        /// Register a new staff account (TravelAgent or Admin).
        /// Requires a secret staff code if unauthenticated, or allows authenticated staff to invite colleagues.
        /// </summary>
        [HttpPost("register-staff")]
        [AllowAnonymous]
        [ProducesResponseType(StatusCodes.Status201Created)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        public async Task<IActionResult> RegisterStaff([FromBody] RegisterStaffDto dto)
        {
            if (!ModelState.IsValid)
            {
                var errors = ModelState.Values.SelectMany(v => v.Errors).Select(e => e.ErrorMessage).ToList();
                return BadRequest(new { message = "Validation failed.", errors = errors });
            }

            // Only Administrators can invite staff, or unauthenticated initial setup with the secret code
            var isAuthenticated = User.Identity?.IsAuthenticated == true;
            var isAdminCaller = isAuthenticated && User.IsInRole("Admin");

            if (isAuthenticated && !isAdminCaller)
            {
                return StatusCode(StatusCodes.Status403Forbidden, new { message = "Only administrators can invite or register new staff accounts." });
            }

            var correctCode = _configuration["StaffSecretCode"];
            if (!isAdminCaller && string.IsNullOrWhiteSpace(correctCode))
                return StatusCode(StatusCodes.Status503ServiceUnavailable, new { message = "Staff registration is not configured." });

            if (!isAdminCaller && (string.IsNullOrWhiteSpace(dto.StaffSecretCode) || dto.StaffSecretCode != correctCode))
                return BadRequest(new { message = "Invalid staff secret code." });

            // Only allow valid roles
            var allowedRoles = new[] { "TravelAgent", "Admin" };
            if (!allowedRoles.Contains(dto.Role))
                return BadRequest(new { message = "Role must be 'TravelAgent' or 'Admin'." });

            var existingUser = await _userManager.FindByEmailAsync(dto.Email);
            if (existingUser != null)
                return BadRequest(new { message = "An account with this email already exists." });

            var user = new IdentityUser
            {
                UserName = dto.Email,
                Email = dto.Email,
                EmailConfirmed = true
            };

            var result = await _userManager.CreateAsync(user, dto.Password);
            if (!result.Succeeded)
                return BadRequest(new { message = "Registration failed.", errors = result.Errors.Select(e => e.Description) });

            // Assign role in ASP.NET Identity
            await _userManager.AddToRoleAsync(user, dto.Role);

            var customer = new Customer
            {
                Id = user.Id,
                FullName = dto.FullName,
                Phone = dto.Phone,
                JoinedAt = DateTime.UtcNow,
                LastActiveAt = DateTime.UtcNow,
                Role = dto.Role   // "TravelAgent" or "Admin"
            };

            _db.Customers.Add(customer);

            // Ensure TravelAgent record exists with department
            var dept = string.IsNullOrWhiteSpace(dto.Department) ? "Tour Operations" : dto.Department;
            _db.TravelAgents.Add(new TravelAgent
            {
                Id = user.Id,
                FullName = dto.FullName,
                Department = dept
            });

            await _db.SaveChangesAsync();

            var token = await GenerateJwtTokenAsync(user);

            return Created("", new
            {
                message = $"Staff account created with role '{dto.Role}'.",
                token,
                userId = user.Id,
                email = user.Email,
                fullName = customer.FullName,
                role = customer.Role,
                department = dept
            });
        }

        /// <summary>
        /// Login with email and password.
        /// </summary>
        [HttpPost("login")]
        [AllowAnonymous]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        public async Task<IActionResult> Login([FromBody] LoginDto dto)
        {
            if (!ModelState.IsValid)
            {
                var errors = ModelState.Values.SelectMany(v => v.Errors).Select(e => e.ErrorMessage).ToList();
                return BadRequest(new { message = "Validation failed.", errors = errors });
            }

            var user = await _userManager.FindByEmailAsync(dto.Email);
            if (user == null)
                return Unauthorized(new { message = "Invalid email or password." });

            var result = await _signInManager.CheckPasswordSignInAsync(user, dto.Password, false);
            if (!result.Succeeded)
                return Unauthorized(new { message = "Invalid email or password." });

            // Update LastActiveAt
            var customer = await _db.Customers.FindAsync(user.Id);
            if (customer != null)
            {
                customer.LastActiveAt = DateTime.UtcNow;
                await _db.SaveChangesAsync();
            }

            var roles = await _userManager.GetRolesAsync(user);
            var userRole = roles.FirstOrDefault() ?? customer?.Role ?? "Customer";
            if (roles.Contains("Admin")) userRole = "Admin";
            else if (roles.Contains("TravelAgent")) userRole = "TravelAgent";

            var token = await GenerateJwtTokenAsync(user);

            return Ok(new
            {
                message = "Login successful.",
                token,
                userId = user.Id,
                email = user.Email,
                role = userRole,
                fullName = customer?.FullName
            });
        }

        private async Task<string> GenerateJwtTokenAsync(IdentityUser user)
        {
            var jwtSettings = _configuration.GetSection("Jwt");
            var key = new Microsoft.IdentityModel.Tokens.SymmetricSecurityKey(
                System.Text.Encoding.UTF8.GetBytes(jwtSettings["Key"]!));

            var claims = new List<System.Security.Claims.Claim>
            {
                new System.Security.Claims.Claim(System.Security.Claims.ClaimTypes.NameIdentifier, user.Id),
                new System.Security.Claims.Claim(System.Security.Claims.ClaimTypes.Email, user.Email!),
                new System.Security.Claims.Claim(System.IdentityModel.Tokens.Jwt.JwtRegisteredClaimNames.Jti,
                    Guid.NewGuid().ToString())
            };

            // Add identity roles and customer table role to claims
            var roles = await _userManager.GetRolesAsync(user);
            foreach (var r in roles)
            {
                claims.Add(new System.Security.Claims.Claim(System.Security.Claims.ClaimTypes.Role, r));
            }

            var customer = await _db.Customers.FindAsync(user.Id);
            if (customer != null && !string.IsNullOrWhiteSpace(customer.Role) && !roles.Contains(customer.Role))
            {
                claims.Add(new System.Security.Claims.Claim(System.Security.Claims.ClaimTypes.Role, customer.Role));
            }

            var creds = new Microsoft.IdentityModel.Tokens.SigningCredentials(
                key, Microsoft.IdentityModel.Tokens.SecurityAlgorithms.HmacSha256);

            var token = new System.IdentityModel.Tokens.Jwt.JwtSecurityToken(
                issuer: jwtSettings["Issuer"],
                audience: jwtSettings["Audience"],
                claims: claims,
                expires: DateTime.UtcNow.AddMinutes(double.Parse(jwtSettings["ExpiryMinutes"] ?? "60")),
                signingCredentials: creds);

            return new System.IdentityModel.Tokens.Jwt.JwtSecurityTokenHandler().WriteToken(token);
        }
    }

    // ── Auth DTOs (co-located since they're small and auth-specific) ──

    public class RegisterDto
    {
        [Required]
        [EmailAddress]
        public string Email { get; set; } = string.Empty;

        [Required]
        [MinLength(6)]
        public string Password { get; set; } = string.Empty;

        [Required]
        [MaxLength(150)]
        public string FullName { get; set; } = string.Empty;

        [Required(ErrorMessage = "Phone number is required.")]
        [StringLength(10, MinimumLength = 10, ErrorMessage = "Phone number must be exactly 10 characters.")]
        [RegularExpression(@"^\d{10}$", ErrorMessage = "Phone number must contain exactly 10 digits.")]
        public string Phone { get; set; } = string.Empty;


    }

    public class LoginDto
    {
        [Required]
        [EmailAddress]
        public string Email { get; set; } = string.Empty;

        [Required]
        public string Password { get; set; } = string.Empty;
    }

    public class RegisterStaffDto
    {
        [Required]
        [EmailAddress]
        public string Email { get; set; } = string.Empty;

        [Required]
        [MinLength(6)]
        public string Password { get; set; } = string.Empty;

        [Required]
        [MaxLength(150)]
        public string FullName { get; set; } = string.Empty;

        [Required(ErrorMessage = "Phone number is required.")]
        [StringLength(10, MinimumLength = 10, ErrorMessage = "Phone number must be exactly 10 characters.")]
        [RegularExpression(@"^\d{10}$", ErrorMessage = "Phone number must contain exactly 10 digits.")]
        public string Phone { get; set; } = string.Empty;

        /// <summary>Role must be "TravelAgent" or "Admin".</summary>
        [Required]
        public string Role { get; set; } = "TravelAgent";

        /// <summary>Optional department for Travel Agents (defaults to Tour Operations).</summary>
        [MaxLength(100)]
        public string? Department { get; set; } = "Tour Operations";

        /// <summary>Secret code required to create staff accounts if unauthenticated.</summary>
        public string? StaffSecretCode { get; set; }
    }
}
