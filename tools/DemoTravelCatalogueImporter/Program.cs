using System.Text.Json;
using backend.Data;
using backend.Services;
using Microsoft.EntityFrameworkCore;

namespace DemoTravelCatalogueImporter;

public static class Program
{
    public static async Task<int> Main(string[] args)
    {
        var applyRequested = args.Any(arg => string.Equals(arg, "--apply", StringComparison.OrdinalIgnoreCase));
        if (args.Any(arg => arg is "--help" or "-h"))
        {
            PrintUsage();
            return 0;
        }

        var repositoryRoot = FindRepositoryRoot(Directory.GetCurrentDirectory());
        var environment = EnvironmentLoader.Load(repositoryRoot);
        var connectionString = EnvironmentLoader.GetConnectionString(environment);
        if (string.IsNullOrWhiteSpace(connectionString))
        {
            Console.Error.WriteLine("BLOCKED - SUPABASE_DB_CONNECTION/DATABASE_URL is not configured.");
            return 2;
        }

        DatabaseTargetInfo target;
        try
        {
            target = EnvironmentLoader.Describe(environment, connectionString);
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"BLOCKED - database connection configuration could not be parsed: {ex.Message}");
            return 2;
        }

        PrintTarget(target, applyRequested);

        var cataloguePath = Path.Combine(repositoryRoot, "tools", "DemoTravelCatalogueImporter", "catalogue.json");
        var catalogueJson = await File.ReadAllTextAsync(cataloguePath);
        var document = JsonSerializer.Deserialize<CatalogueDocument>(catalogueJson, new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        }) ?? throw new InvalidOperationException("catalogue.json did not contain a catalogue document.");

        await using var db = new AppDbContext(DatabaseSnapshotReader.CreateOptions(connectionString));
        if (!await db.Database.CanConnectAsync())
        {
            Console.Error.WriteLine("BLOCKED - database connection failed.");
            return 2;
        }

        var snapshot = await DatabaseSnapshotReader.ReadAsync(db, CancellationToken.None);
        var plan = CataloguePlanner.Build(snapshot, document, BusinessClock.Today);
        ReportWriter.WriteAll(repositoryRoot, target, document, snapshot, plan, applyRequested);

        PrintSummary(snapshot, plan);

        if (!applyRequested)
        {
            Console.WriteLine("DRY RUN COMPLETE - no database mutation was attempted.");
            return 0;
        }

        if (target.ProductionConflict)
        {
            Console.Error.WriteLine("ENVIRONMENT_CONFLICT - an authoritative production/shared signal is present.");
            Console.Error.WriteLine("Catalogue writes remain blocked.");
            return 3;
        }

        if (!target.EnvironmentAllowed || !target.WriteApprovalEnabled)
        {
            Console.Error.WriteLine("BLOCKED - DEMO_CATALOGUE_ENVIRONMENT and DEMO_CATALOGUE_WRITE_ENABLED=true are both required.");
            return 3;
        }

        Console.WriteLine("Environment allowed: YES");
        Console.WriteLine("Catalogue write approval enabled: YES");
        var applyResult = await ImportExecutor.ApplyAsync(db, plan, CancellationToken.None);
        ReportWriter.WriteAll(repositoryRoot, target, document, snapshot, plan, applyRequested, applyResult);
        Console.WriteLine($"Applied destinations={applyResult.DestinationsInserted}, hotels={applyResult.HotelsInserted}, rooms={applyResult.RoomsInserted}, tours={applyResult.ToursInserted}, transport={applyResult.TransportInserted}.");
        return applyResult.FailedBatches == 0 ? 0 : 4;
    }

    private static void PrintTarget(DatabaseTargetInfo target, bool applyRequested)
    {
        Console.WriteLine($"Host: {target.Host}");
        Console.WriteLine($"Port: {target.Port}");
        Console.WriteLine($"Database: {target.Database}");
        Console.WriteLine($"Schema: {target.Schema}");
        Console.WriteLine($"SSL: {target.Ssl}");
        Console.WriteLine($"Configuration source: {target.ConfigurationSource}");
        Console.WriteLine($"Environment classification: {target.EnvironmentClassification}");
        Console.WriteLine($"Classification source: {target.ClassificationSource}");
        Console.WriteLine($"Environment allowed: {(target.EnvironmentAllowed ? "YES" : "NO")}");
        Console.WriteLine($"Catalogue write approval enabled: {(target.WriteApprovalEnabled ? "YES" : "NO")}");
        Console.WriteLine($"Production conflict: {(target.ProductionConflict ? "YES" : "NO")}");
        Console.WriteLine($"Write flag: {(applyRequested ? "--apply" : "dry-run (default)")}");
    }

    private static void PrintSummary(CatalogueSnapshot snapshot, ImportPlan plan)
    {
        Console.WriteLine($"Current counts: destinations={snapshot.Destinations.Count}, hotels={snapshot.Hotels.Count}, rooms={snapshot.Rooms.Count}, tours={snapshot.Tours.Count}, transport={snapshot.TransportOptions.Count}.");
        Console.WriteLine($"Planned inserts: destinations={plan.DestinationsToInsert.Count}, hotels={plan.HotelsToInsert.Count}, rooms={plan.RoomsToInsert.Count}, tours={plan.ToursToInsert.Count}, transport={plan.TransportToInsert.Count}.");
        Console.WriteLine($"Verification/duplicate outcomes: {plan.Issues.Count}.");
        Console.WriteLine($"Schedule window: {plan.WindowStart:yyyy-MM-dd} through {plan.WindowEnd:yyyy-MM-dd} (local wall-clock values).");
    }

    private static string FindRepositoryRoot(string start)
    {
        var directory = new DirectoryInfo(Path.GetFullPath(start));
        while (directory is not null)
        {
            if (Directory.Exists(Path.Combine(directory.FullName, "backend")) &&
                File.Exists(Path.Combine(directory.FullName, "DEMO_TRAVEL_CATALOGUE_PROPOSAL.md")))
            {
                return directory.FullName;
            }

            directory = directory.Parent;
        }

        throw new DirectoryNotFoundException("Could not locate the repository root.");
    }

    private static void PrintUsage()
    {
        Console.WriteLine("DemoTravelCatalogueImporter");
        Console.WriteLine("  (no flags)  read-only dry run; this is the default");
        Console.WriteLine("  --apply     apply only to an explicitly DEMO/DEVELOPMENT/TEST target");
    }
}
