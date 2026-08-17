using backend.Data;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

var connectionString = builder.Configuration.GetConnectionString("Default")
    ?? builder.Configuration["DATABASE_URL"]
    ?? builder.Configuration["ConnectionStrings:Default"];

// Add services to the container.
builder.Services.AddDbContext<AppDbContext>(options =>
{
    if (string.IsNullOrWhiteSpace(connectionString))
    {
        options.UseNpgsql("Host=localhost;Port=5432;Database=postgres;Username=postgres;Password=postgres");
    }
    else
    {
        options.UseNpgsql(connectionString);
    }
});

// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

var summaries = new[]
{
    "Freezing", "Bracing", "Chilly", "Cool", "Mild", "Warm", "Balmy", "Hot", "Sweltering", "Scorching"
};

app.MapGet("/weatherforecast", () =>
{
    var forecast =  Enumerable.Range(1, 5).Select(index =>
        new WeatherForecast
        (
            DateOnly.FromDateTime(DateTime.Now.AddDays(index)),
            Random.Shared.Next(-20, 55),
            summaries[Random.Shared.Next(summaries.Length)]
        ))
        .ToArray();
    return forecast;
})
.WithName("GetWeatherForecast")
.WithOpenApi();

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

record WeatherForecast(DateOnly Date, int TemperatureC, string? Summary)
{
    public int TemperatureF => 32 + (int)(TemperatureC / 0.5556);
}