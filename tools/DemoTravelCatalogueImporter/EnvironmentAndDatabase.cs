using backend.Data;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace DemoTravelCatalogueImporter;

public sealed class EnvironmentValues
{
    public Dictionary<string, string> Values { get; init; } = new(StringComparer.OrdinalIgnoreCase);
    public string ConnectionSource { get; init; } = "not configured";
}

public static class EnvironmentLoader
{
    private static readonly string[] DatabaseClassificationKeys =
    [
        "DEMO_CATALOGUE_ENVIRONMENT",
        "TRAVEL_DATABASE_ENVIRONMENT",
        "SUPABASE_PROJECT_ENVIRONMENT",
        "DATABASE_ENVIRONMENT",
        "DATABASE_TARGET",
        "DEMO_DATABASE"
    ];

    private static readonly string[] AuthoritativeEnvironmentKeys =
    [
        .. DatabaseClassificationKeys,
        "ASPNETCORE_ENVIRONMENT",
        "DOTNET_ENVIRONMENT"
    ];

    public static EnvironmentValues Load(string repositoryRoot)
    {
        var values = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        var envFile = Path.Combine(repositoryRoot, "backend", ".env");

        if (File.Exists(envFile))
        {
            foreach (var rawLine in File.ReadAllLines(envFile))
            {
                var line = rawLine.Trim();
                if (line.Length == 0 || line.StartsWith('#'))
                {
                    continue;
                }

                var separator = line.IndexOf('=');
                if (separator <= 0)
                {
                    continue;
                }

                var key = line[..separator].Trim();
                var value = line[(separator + 1)..].Trim().Trim('"', '\'');
                values[key] = value;
            }
        }

        foreach (var key in new[]
                 {
                     "SUPABASE_DB_CONNECTION",
                     "DATABASE_URL",
                     "TRAVEL_DATABASE_ENVIRONMENT",
                     "SUPABASE_PROJECT_ENVIRONMENT",
                     "DATABASE_ENVIRONMENT",
                     "DATABASE_TARGET",
                     "DEMO_DATABASE",
                     "DEMO_CATALOGUE_ENVIRONMENT",
                     "DEMO_CATALOGUE_WRITE_ENABLED",
                     "ASPNETCORE_ENVIRONMENT",
                     "DOTNET_ENVIRONMENT"
                 })
        {
            var processValue = Environment.GetEnvironmentVariable(key);
            if (!string.IsNullOrWhiteSpace(processValue))
            {
                values[key] = processValue;
            }
        }

        var source = !string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("SUPABASE_DB_CONNECTION")) ||
                     !string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("DATABASE_URL"))
            ? "process environment"
            : values.ContainsKey("SUPABASE_DB_CONNECTION")
                ? "backend/.env:SUPABASE_DB_CONNECTION"
                : values.ContainsKey("DATABASE_URL")
                    ? "backend/.env:DATABASE_URL"
                    : "not configured";

        return new EnvironmentValues
        {
            ConnectionSource = source,
            Values = values
        };
    }

    public static string? GetConnectionString(EnvironmentValues values)
    {
        return FirstNonEmpty(values.Values, "SUPABASE_DB_CONNECTION", "DATABASE_URL");
    }

    public static DatabaseTargetInfo Describe(EnvironmentValues values, string connectionString)
    {
        var builder = new NpgsqlConnectionStringBuilder(connectionString);
        var schema = string.IsNullOrWhiteSpace(builder.SearchPath) ? "public" : builder.SearchPath;
        var signals = AuthoritativeEnvironmentKeys
            .Where(key => values.Values.TryGetValue(key, out var value) && !string.IsNullOrWhiteSpace(value))
            .Select(key => (Key: key, Value: values.Values[key]))
            .ToArray();
        var productionSignal = signals.FirstOrDefault(signal => IsProduction(signal.Key, signal.Value));
        var productionConflict = productionSignal != default;
        var selectedSignal = signals
            .Where(signal => DatabaseClassificationKeys.Contains(signal.Key, StringComparer.OrdinalIgnoreCase))
            .Select(signal => (signal.Key, signal.Value, Classification: Classify(signal.Key, signal.Value)))
            .FirstOrDefault(signal => signal.Classification is not null);
        var classification = productionConflict
            ? "PRODUCTION/SHARED"
            : selectedSignal.Classification ?? "UNKNOWN";
        var classificationSource = productionConflict
            ? productionSignal.Key
            : selectedSignal.Key ?? "not configured";
        var environmentAllowed = classification is "DEMO" or "DEVELOPMENT" or "TEST";
        var writeApprovalEnabled = IsTrue(values.Values.GetValueOrDefault("DEMO_CATALOGUE_WRITE_ENABLED"));

        return new DatabaseTargetInfo(
            builder.Host ?? string.Empty,
            builder.Port.ToString(),
            builder.Database ?? string.Empty,
            schema,
            builder.SslMode.ToString(),
            values.ConnectionSource,
            classification,
            classificationSource,
            environmentAllowed,
            writeApprovalEnabled,
            productionConflict,
            environmentAllowed && writeApprovalEnabled && !productionConflict);
    }

    private static string? FirstNonEmpty(Dictionary<string, string> values, params string[] keys)
    {
        foreach (var key in keys)
        {
            if (values.TryGetValue(key, out var value) && !string.IsNullOrWhiteSpace(value))
            {
                return value;
            }
        }

        return null;
    }

    private static string? Classify(string key, string marker)
    {
        var normalized = marker.Trim().ToUpperInvariant();
        if (key.Equals("DEMO_DATABASE", StringComparison.OrdinalIgnoreCase) && IsTrue(marker))
        {
            return "DEMO";
        }

        if (key.Equals("DEMO_DATABASE", StringComparison.OrdinalIgnoreCase) &&
            !normalized.Contains("DEMO"))
        {
            return null;
        }

        if (normalized.Contains("DEMO"))
        {
            return "DEMO";
        }

        if (normalized.Contains("DEV"))
        {
            return "DEVELOPMENT";
        }

        if (normalized.Contains("TEST") || normalized.Contains("CI"))
        {
            return "TEST";
        }

        return null;
    }

    private static bool IsProduction(string key, string value)
    {
        var normalized = value.Trim().ToUpperInvariant();
        return normalized.Contains("PROD") ||
               normalized.Contains("SHARED") ||
               (key.Equals("DEMO_DATABASE", StringComparison.OrdinalIgnoreCase) &&
                normalized.Equals("PRODUCTION", StringComparison.OrdinalIgnoreCase));
    }

    private static bool IsTrue(string? value)
    {
        return value is not null &&
               (value.Trim().Equals("true", StringComparison.OrdinalIgnoreCase) ||
                value.Trim().Equals("1", StringComparison.OrdinalIgnoreCase) ||
                value.Trim().Equals("yes", StringComparison.OrdinalIgnoreCase) ||
                value.Trim().Equals("on", StringComparison.OrdinalIgnoreCase));
    }
}

public static class DatabaseSnapshotReader
{
    public static async Task<CatalogueSnapshot> ReadAsync(AppDbContext db, CancellationToken cancellationToken)
    {
        var destinations = (await db.Destinations
                .AsNoTracking()
                .ToListAsync(cancellationToken))
            .Select(d => new ExistingDestination(d.Id, d.Name, Normalizers.Name(d.Name)))
            .ToList();

        var hotels = (await db.Hotels.AsNoTracking().ToListAsync(cancellationToken))
            .Select(h => new ExistingHotel(h.Id, h.DestinationId, h.Name, h.Status.ToString()))
            .ToList();

        var rooms = (await db.Rooms.AsNoTracking().ToListAsync(cancellationToken))
            .Select(r => new ExistingRoom(r.Id, r.HotelId, r.RoomType, r.Status.ToString()))
            .ToList();

        var tours = (await db.Tours.AsNoTracking().ToListAsync(cancellationToken))
            .Select(t => new ExistingTour(t.Id, t.DestinationId, t.Name, t.Status))
            .ToList();

        var transports = (await db.TransportOptions.AsNoTracking().ToListAsync(cancellationToken))
            .Select(t => new ExistingTransport(t.Id, t.Provider, t.RouteFrom, t.RouteTo, t.DepartureTime, t.Status.ToString()))
            .ToList();

        var roomReferences = await db.BookingItems.AsNoTracking().CountAsync(item => item.RoomId != null, cancellationToken);
        var tourReferences = await db.BookingItems.AsNoTracking().CountAsync(item => item.TourId != null, cancellationToken);
        var transportReferences = await db.BookingItems.AsNoTracking().CountAsync(item => item.TransportOptionId != null, cancellationToken);

        return new CatalogueSnapshot
        {
            Destinations = destinations,
            Hotels = hotels,
            Rooms = rooms,
            Tours = tours,
            TransportOptions = transports,
            BookingItemRoomReferences = roomReferences,
            BookingItemTourReferences = tourReferences,
            BookingItemTransportReferences = transportReferences
        };
    }

    public static DbContextOptions<AppDbContext> CreateOptions(string connectionString)
    {
        AppContext.SetSwitch("Npgsql.EnableLegacyTimestampBehavior", true);
        return new DbContextOptionsBuilder<AppDbContext>()
            .UseNpgsql(connectionString)
            .Options;
    }
}
