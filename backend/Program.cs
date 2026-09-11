using System.Text;
using backend.Data;
using backend.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using DotNetEnv;

Env.Load();

var builder = WebApplication.CreateBuilder(args);
builder.Configuration.AddEnvironmentVariables();

// Load environment variables from 'env' file if present
var envFilePath = Path.Combine(builder.Environment.ContentRootPath, "env");
if (!File.Exists(envFilePath))
{
    envFilePath = Path.Combine(Directory.GetCurrentDirectory(), "env");
}
if (File.Exists(envFilePath))
{
    foreach (var line in File.ReadAllLines(envFilePath))
    {
        if (string.IsNullOrWhiteSpace(line) || line.StartsWith("#")) continue;
        var parts = line.Split('=', 2);
        if (parts.Length == 2)
        {
            var key = parts[0].Trim();
            var val = parts[1].Trim().Trim('"').Trim('\'');
            Environment.SetEnvironmentVariable(key, val);
            builder.Configuration[key] = val;
        }
    }
}

var connectionString = builder.Configuration["SUPERBASE_URL"]
    ?? Environment.GetEnvironmentVariable("SUPERBASE_URL")
    ?? builder.Configuration.GetConnectionString("Default")
    ?? builder.Configuration["DATABASE_URL"]
    ?? builder.Configuration["ConnectionStrings:Default"];

// ── Database ──
builder.Services.AddDbContext<AppDbContext>(options =>
{
    if (!string.IsNullOrWhiteSpace(connectionString))
    {
        options.UseNpgsql(connectionString);
    }
    else
    {
        // Safe local default without sensitive credentials
        options.UseNpgsql("Host=localhost;Port=5432;Database=travel_booking_db;Username=postgres;Password=");
    }
});

// ── ASP.NET Identity ──
builder.Services.AddIdentity<IdentityUser, IdentityRole>(options =>
{
    options.Password.RequireDigit = true;
    options.Password.RequireLowercase = true;
    options.Password.RequireUppercase = true;
    options.Password.RequireNonAlphanumeric = false;
    options.Password.RequiredLength = 6;
    options.User.RequireUniqueEmail = true;
})
.AddEntityFrameworkStores<AppDbContext>()
.AddDefaultTokenProviders();

// ── JWT Authentication ──
var jwtSettings = builder.Configuration.GetSection("Jwt");
var jwtKey = jwtSettings["Key"] ?? throw new InvalidOperationException("JWT Key is not configured.");

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidateLifetime = true,
        ValidateIssuerSigningKey = true,
        ValidIssuer = jwtSettings["Issuer"],
        ValidAudience = jwtSettings["Audience"],
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey))
    };
});

builder.Services.AddAuthorization();

// ── Controllers ──
builder.Services.AddControllers();

// ── DI: Student A Services ──
builder.Services.AddScoped<ICustomerService, CustomerService>();
builder.Services.AddScoped<IPreferenceService, PreferenceService>();
builder.Services.AddScoped<INotificationService, NotificationService>();
builder.Services.AddScoped<ITripRequestService, TripRequestService>();
builder.Services.AddScoped<IItineraryService, ItineraryService>();

// ── DI: Student D Services ──
builder.Services.AddScoped<IBookingService, BookingService>();
builder.Services.AddScoped<IApprovalService, ApprovalService>();
builder.Services.AddScoped<IPaymentService, PaymentService>();

// ── Swagger / OpenAPI ──
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "AI Travel Planning & Booking API",
        Version = "v1",
        Description = "Backend API for the AI Travel Planning & Booking Management System."
    });

    // JWT support in Swagger UI
    options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        In = ParameterLocation.Header,
        Description = "Enter your JWT token"
    });

    options.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference
                {
                    Type = ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            Array.Empty<string>()
        }
    });
});

// ── CORS ──
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.WithOrigins(
                "http://localhost:5173",
                "http://127.0.0.1:5173",
                "http://localhost:3000",
                "http://127.0.0.1:3000")
              .AllowAnyMethod()
              .AllowAnyHeader()
              .AllowCredentials();
    });
});

builder.Services.AddScoped<DestinationService>();
builder.Services.AddScoped<TourService>();

// ── DI: Student C Services ──
builder.Services.AddScoped<IHotelService, HotelService>();
builder.Services.AddScoped<ITransportService, TransportService>();
builder.Services.AddScoped<IAvailabilityService, AvailabilityService>();

var app = builder.Build();

// ── Role Seeding on Startup ──
using (var scope = app.Services.CreateScope())
{
    var roleManager = scope.ServiceProvider.GetRequiredService<RoleManager<IdentityRole>>();
    string[] roles = ["Customer", "TravelAgent", "Admin"];
    foreach (var role in roles)
    {
        if (!await roleManager.RoleExistsAsync(role))
        {
            await roleManager.CreateAsync(new IdentityRole(role));
        }
    }
}

// ── Global Exception Handling ──
app.UseExceptionHandler(errorApp =>
{
    errorApp.Run(async context =>
    {
        context.Response.StatusCode = StatusCodes.Status500InternalServerError;
        context.Response.ContentType = "application/json";
        var response = new
        {
            statusCode = 500,
            message = "An unexpected internal server error occurred. Please try again later."
        };
        await context.Response.WriteAsJsonAsync(response);
    });
});

// ── Middleware Pipeline ──
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseCors("AllowAll");

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

// ── Health Check Endpoints (kept from original scaffold) ──

app.MapGet("/dbhealth", async (AppDbContext db) =>
{
    try
    {
        var connected = await db.Database.CanConnectAsync();
        return Results.Ok(new
        {
            connected,
            message = connected ? "Database connection is OK." : "Database connection failed."
        });
    }
    catch (Exception ex)
    {
        return Results.Problem(title: "Database connection error", detail: ex.Message);
    }
});

app.MapGet("/supabasehealth", async () =>
{
    var url = builder.Configuration["NEXT_PUBLIC_SUPABASE_URL"]
        ?? builder.Configuration["VITE_SUPABASE_URL"]
        ?? builder.Configuration["SUPABASE_URL"];
    var key = builder.Configuration["NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY"]
        ?? builder.Configuration["VITE_SUPABASE_ANON_KEY"]
        ?? builder.Configuration["SUPABASE_ANON_KEY"]
        ?? builder.Configuration["SUPABASE_KEY"];

    if (string.IsNullOrWhiteSpace(url) || string.IsNullOrWhiteSpace(key))
    {
        return Results.BadRequest(new { ok = false, message = "Supabase URL or key is missing." });
    }

    using var client = new HttpClient();
    client.DefaultRequestHeaders.Add("apikey", key);
    client.DefaultRequestHeaders.Add("Authorization", $"Bearer {key}");

    try
    {
        var response = await client.GetAsync($"{url}/rest/v1/");
        var body = await response.Content.ReadAsStringAsync();
        return Results.Ok(new
        {
            ok = response.IsSuccessStatusCode,
            statusCode = (int)response.StatusCode,
            message = response.IsSuccessStatusCode ? "Supabase API is reachable." : "Supabase API rejected the request.",
            body
        });
    }
    catch (Exception ex)
    {
        return Results.Problem(title: "Supabase health check failed", detail: ex.Message);
    }
});

app.Run();