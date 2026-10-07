namespace backend.DTOs;

/// <summary>
/// Destination selection exposed by the trip-request API and AI dispatch.
/// </summary>
public sealed class TripRequestDestinationDto
{
    public int Id { get; set; }

    public string Name { get; set; } = string.Empty;

    public int Order { get; set; }
}

/// <summary>
/// Structured destination input. The ID is authoritative; name is retained
/// for diagnostics and client round-tripping only.
/// </summary>
public sealed class TripRequestDestinationInputDto
{
    public int Id { get; set; }

    public string? Name { get; set; }

    public int? Order { get; set; }
}
