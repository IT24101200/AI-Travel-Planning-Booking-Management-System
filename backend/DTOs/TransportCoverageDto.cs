namespace backend.DTOs;

/// <summary>
/// Safe staff-only summary of transport catalogue coverage for one exact route
/// and dated trip window. It contains no customer or booking details.
/// </summary>
public sealed class TransportCoverageDto
{
    public string RouteFrom { get; set; } = string.Empty;
    public string RouteTo { get; set; } = string.Empty;
    public DateTime StartDate { get; set; }
    public DateTime EndDate { get; set; }
    public int Travellers { get; set; }
    public int TotalActive { get; set; }
    public int RouteMatches { get; set; }
    public int DateMatches { get; set; }
    public int CapacityMatches { get; set; }
    public int AvailableMatches { get; set; }
    public string Status { get; set; } = string.Empty;
    public string ReasonCode { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
}
