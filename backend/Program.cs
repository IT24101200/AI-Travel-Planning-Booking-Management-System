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
AppContext.SetSwitch("Npgsql.EnableLegacyTimestampBehavior", true);

var builder = WebApplication.CreateBuilder(args);
builder.Configuration.AddEnvironmentVariables();

string? ResolveEnvFilePath()
{
    var candidates = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

    void AddCandidate(string path)
    {
        if (!string.IsNullOrWhiteSpace(path))
        {
            candidates.Add(Path.GetFullPath(path));
        }
    }

    AddCandidate(Path.Combine(builder.Environment.ContentRootPath, ".env"));
    AddCandidate(Path.Combine(builder.Environment.ContentRootPath, "env"));
    AddCandidate(Path.Combine(Directory.GetCurrentDirectory(), ".env"));
    AddCandidate(Path.Combine(Directory.GetCurrentDirectory(), "env"));

    var currentDir = new DirectoryInfo(builder.Environment.ContentRootPath);
    while (currentDir != null)
    {
        AddCandidate(Path.Combine(currentDir.FullName, ".env"));
        AddCandidate(Path.Combine(currentDir.FullName, "env"));
        currentDir = currentDir.Parent;
    }

    foreach (var candidate in candidates)
    {
        if (File.Exists(candidate))
        {
            return candidate;
        }
    }

    return null;
}

var envFilePath = ResolveEnvFilePath();
if (!string.IsNullOrWhiteSpace(envFilePath))
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

// ── Controllers & Consistent Validation Errors ──
builder.Services.AddControllers()
    .ConfigureApiBehaviorOptions(options =>
    {
        options.InvalidModelStateResponseFactory = context =>
        {
            var errors = context.ModelState
                .Where(e => e.Value != null && e.Value.Errors.Count > 0)
                .SelectMany(x => x.Value!.Errors)
                .Select(x => x.ErrorMessage)
                .ToList();

            return new Microsoft.AspNetCore.Mvc.BadRequestObjectResult(new
            {
                message = "Validation failed.",
                errors = errors
            });
        };
    });
builder.Services.AddHttpClient();

// ── DI: Student A Services ──
builder.Services.AddScoped<ICustomerService, CustomerService>();
builder.Services.AddScoped<IPreferenceService, PreferenceService>();
builder.Services.AddSingleton<ICurrencyConversionService, CurrencyConversionService>();
builder.Services.AddScoped<INotificationService, NotificationService>();
builder.Services.AddScoped<ITripRequestService, TripRequestService>();
builder.Services.AddScoped<IAgentProposalPersistenceService, AgentProposalPersistenceService>();
builder.Services.AddScoped<IItineraryService, ItineraryService>();

// ── DI: Student D Services ──
builder.Services.AddScoped<IBookingService, BookingService>();
builder.Services.AddScoped<IApprovalService, ApprovalService>();
builder.Services.AddScoped<IRevisionPlanningService, RevisionPlanningService>();
builder.Services.AddScoped<IPaymentService, PaymentService>();
builder.Services.AddScoped<IStripePaymentGateway, StripePaymentGateway>();

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
var configuredOrigins = builder.Configuration.GetSection("AllowedOrigins").Get<string[]>()
    ?? Array.Empty<string>();
var environmentOrigins = Environment.GetEnvironmentVariable("ALLOWED_ORIGINS")
    ?.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
    ?? Array.Empty<string>();
var allowedOrigins = environmentOrigins.Length > 0 ? environmentOrigins : configuredOrigins;

builder.Services.AddCors(options =>
{
    options.AddPolicy("ConfiguredOrigins", policy =>
    {
        if (allowedOrigins.Length > 0)
        {
            policy.SetIsOriginAllowed(origin =>
            {
                if (string.IsNullOrEmpty(origin)) return false;
                // Always permit localhost development origins (Flutter Web, React, etc.)
                if (origin.StartsWith("http://localhost:") || origin.StartsWith("https://localhost:") || origin == "http://localhost" || origin == "https://localhost")
                    return true;
                return allowedOrigins.Contains(origin, StringComparer.OrdinalIgnoreCase);
            })
            .AllowAnyMethod()
            .AllowAnyHeader();
        }
        else
        {
            policy.AllowAnyOrigin()
                .AllowAnyMethod()
                .AllowAnyHeader();
        }
    });
});

builder.Services.AddScoped<DestinationService>();
builder.Services.AddScoped<TourService>();

// ── DI: Student C Services ──
builder.Services.AddScoped<IHotelService, HotelService>();
builder.Services.AddScoped<ITransportService, TransportService>();
builder.Services.AddScoped<IAvailabilityService, AvailabilityService>();

var app = builder.Build();

// ── Database Seeding on Startup (Disabled by default to preserve cleared state) ──
var seedOnStartup = app.Configuration.GetValue<bool>("SeedDatabaseOnStartup", false);
if (seedOnStartup && !app.Environment.IsEnvironment("Testing"))
{
    try
    {
        await backend.Data.DbInitializer.SeedAsync(app.Services);
    }
    catch (Exception ex)
    {
        // Log database connection warning without crashing application startup
        app.Logger.LogWarning("Could not seed database on startup: {Message}", ex.Message);
    }
}

// ── Global Exception Handling ──
app.UseExceptionHandler(errorApp =>
{
    errorApp.Run(async context =>
    {
        var exFeature = context.Features.Get<Microsoft.AspNetCore.Diagnostics.IExceptionHandlerPathFeature>();
        var ex = exFeature?.Error;
        app.Logger.LogError(ex, "Unhandled exception at {Path}: {Message}", context.Request.Path, ex?.Message);

        context.Response.StatusCode = StatusCodes.Status500InternalServerError;
        context.Response.ContentType = "application/json";
        var response = new
        {
            statusCode = 500,
            message = ex?.Message ?? "An unexpected internal server error occurred. Please try again later.",
            detail = ex?.ToString()
        };
        await context.Response.WriteAsJsonAsync(response);
    });
});

// ── Middleware Pipeline ──
// Enable Swagger documentation for all environments (including cloud deployment)
app.UseSwagger();
app.UseSwaggerUI(c =>
{
    c.SwaggerEndpoint("/swagger/v1/swagger.json", "AI Travel Planning API v1");
    c.RoutePrefix = "swagger";
});

// Root redirect to Swagger UI for instant access when deployed
app.MapGet("/", () => Results.Redirect("/swagger"));

if (!app.Environment.IsDevelopment())
{
    app.UseHttpsRedirection();
}
app.UseCors("ConfiguredOrigins");
app.UseStaticFiles();

// Also serve the uploads directory (for tour images, etc.)
var uploadsPath = Path.Combine(builder.Environment.ContentRootPath, "wwwroot", "uploads");
if (!Directory.Exists(uploadsPath))
{
    Directory.CreateDirectory(uploadsPath);
}
app.UseStaticFiles(new StaticFileOptions
{
    FileProvider = new Microsoft.Extensions.FileProviders.PhysicalFileProvider(uploadsPath),
    RequestPath = "/uploads"
});


app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

// ── Health Check Endpoints (kept from original scaffold) ──

app.MapGet("/health", () => Results.Ok(new
{
    status = "healthy",
    service = "AI Travel Planning API",
    environment = app.Environment.EnvironmentName
}));

app.MapGet("/dbhealth", async (AppDbContext db) =>
{
    try
    {
        var connected = await db.Database.CanConnectAsync();
        var conn = db.Database.GetDbConnection();
        return Results.Ok(new
        {
            connected,
            message = connected ? "Database connection is OK." : "Database connection failed.",
            server = conn.DataSource,
            database = conn.Database
        });
    }
    catch (Exception ex)
    {
        return Results.Problem(title: "Database connection error", detail: ex.Message);
    }
});

if (app.Environment.IsDevelopment())
{
    app.MapPost("/seed-db", async (IServiceProvider services) =>
    {
        try
        {
            await backend.Data.DbInitializer.SeedAsync(services);
            return Results.Ok(new { success = true, message = "Database seeded successfully." });
        }
        catch (Exception ex)
        {
            app.Logger.LogError(ex, "Development database seeding failed.");
            return Results.Problem(title: "Seeding error", detail: ex.Message);
        }
    });

    app.MapPost("/reset-db", async (IServiceProvider services) =>
    {
        try
        {
            await backend.Data.DbInitializer.ResetAndSeedAsync(services);
            return Results.Ok(new { success = true, message = "Database fully cleared and re-seeded with fresh data." });
        }
        catch (Exception ex)
        {
            app.Logger.LogError(ex, "Database reset and seeding failed.");
            return Results.Problem(title: "Reset error", detail: ex.Message);
        }
    });
}

app.MapPost("/setup-supabase-storage", async (AppDbContext db) =>
{
    try
    {
        await db.Database.ExecuteSqlRawAsync(@"
            INSERT INTO storage.buckets (id, name, public) 
            VALUES ('catalog-images', 'catalog-images', true) 
            ON CONFLICT (id) DO UPDATE SET public = true;
            
            DO $$
            BEGIN
                IF NOT EXISTS (
                    SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND policyname = 'Public Access for catalog-images'
                ) THEN
                    CREATE POLICY ""Public Access for catalog-images"" ON storage.objects FOR ALL USING (bucket_id = 'catalog-images') WITH CHECK (bucket_id = 'catalog-images');
                END IF;
            END
            $$;
        ");
        return Results.Ok(new { success = true, message = "Supabase storage bucket and policy created successfully." });
    }
    catch (Exception ex)
    {
        return Results.Problem(title: "Storage setup error", detail: ex.Message);
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

public partial class Program { }
