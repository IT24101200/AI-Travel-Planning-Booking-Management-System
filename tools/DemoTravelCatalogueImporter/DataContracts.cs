using System.Text.Json.Serialization;

namespace DemoTravelCatalogueImporter;

public sealed class CatalogueDocument
{
    public List<DestinationSeed> Destinations { get; set; } = [];
    public List<HotelSeed> Hotels { get; set; } = [];
    public List<TourSeed> Tours { get; set; } = [];
}

public sealed class DestinationSeed
{
    public string Name { get; set; } = string.Empty;
    public string Country { get; set; } = "Sri Lanka";
    public string Description { get; set; } = string.Empty;
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public bool Verified { get; set; }
    public string SourceUrl { get; set; } = string.Empty;
    public string VerificationNote { get; set; } = string.Empty;
}

public sealed class HotelSeed
{
    public string Name { get; set; } = string.Empty;
    public string Destination { get; set; } = string.Empty;
    public string Tier { get; set; } = "Mid-range";
    public string? Address { get; set; }
    public string? ContactPhone { get; set; }
    public string? ContactEmail { get; set; }
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
    public int StarRating { get; set; }
    public bool IdentityVerified { get; set; }
    public bool CoordinatesVerified { get; set; }
    public string SourceUrl { get; set; } = string.Empty;
    public string VerificationNote { get; set; } = string.Empty;
}

public sealed class TourSeed
{
    public string Name { get; set; } = string.Empty;
    public string Destination { get; set; } = string.Empty;
    public string Category { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public double DurationHours { get; set; }
    public decimal Price { get; set; }
    public string Currency { get; set; } = "LKR";
    public string? ImageUrl { get; set; }
    public bool IdentityVerified { get; set; }
    public string SourceUrl { get; set; } = string.Empty;
}

public sealed record ExistingDestination(int Id, string Name, string NormalizedName);

public sealed record ExistingHotel(int Id, int DestinationId, string Name, string Status);

public sealed record ExistingRoom(int Id, int HotelId, string RoomType, string Status);

public sealed record ExistingTour(int Id, int DestinationId, string Name, string Status);

public sealed record ExistingTransport(
    int Id,
    string Provider,
    string RouteFrom,
    string RouteTo,
    DateTime DepartureTime,
    string Status);

public sealed class CatalogueSnapshot
{
    public List<ExistingDestination> Destinations { get; init; } = [];
    public List<ExistingHotel> Hotels { get; init; } = [];
    public List<ExistingRoom> Rooms { get; init; } = [];
    public List<ExistingTour> Tours { get; init; } = [];
    public List<ExistingTransport> TransportOptions { get; init; } = [];
    public int BookingItemRoomReferences { get; init; }
    public int BookingItemTourReferences { get; init; }
    public int BookingItemTransportReferences { get; init; }
}

public sealed class PlannedRoom
{
    public string Hotel { get; init; } = string.Empty;
    public string RoomType { get; init; } = string.Empty;
    public int Capacity { get; init; }
    public int TotalRooms { get; init; }
    public decimal PricePerNight { get; init; }
    public string Currency { get; init; } = "LKR";
    public string RateNotes { get; init; } = string.Empty;
}

public sealed class PlannedTransport
{
    public string Provider { get; init; } = string.Empty;
    public string RouteFrom { get; init; } = string.Empty;
    public string RouteTo { get; init; } = string.Empty;
    public DateTime DepartureTime { get; init; }
    public DateTime ArrivalTime { get; init; }
    public int Capacity { get; init; }
    public decimal Price { get; init; }
    public string Currency { get; init; } = "LKR";
    public string Type { get; init; } = "Van";
}

public sealed record PlanIssue(string Entity, string Key, string Code, string Detail);

public sealed class ImportPlan
{
    public DateOnly WindowStart { get; init; }
    public DateOnly WindowEnd { get; init; }
    public List<DestinationSeed> DestinationsToInsert { get; init; } = [];
    public List<HotelSeed> HotelsToInsert { get; init; } = [];
    public List<PlannedRoom> RoomsToInsert { get; init; } = [];
    public List<TourSeed> ToursToInsert { get; init; } = [];
    public List<PlannedTransport> TransportToInsert { get; init; } = [];
    public List<PlanIssue> Issues { get; init; } = [];
}

public sealed record DatabaseTargetInfo(
    string Host,
    string Port,
    string Database,
    string Schema,
    string Ssl,
    string ConfigurationSource,
    string EnvironmentClassification,
    string ClassificationSource,
    bool EnvironmentAllowed,
    bool WriteApprovalEnabled,
    bool ProductionConflict,
    bool WriteApproved);
