namespace backend.DTOs;

public sealed class TripConfirmationDto
{
    public int BookingId { get; set; }
    public int ItineraryId { get; set; }
    public string BookingReference { get; set; } = "";
    public string StartDate { get; set; } = "";
    public string EndDate { get; set; } = "";
    public int Travellers { get; set; }
    public decimal AmountPaid { get; set; }
    public string Currency { get; set; } = "";
    public List<ConfirmedHotelDto> Hotels { get; set; } = new();
    public List<ConfirmedTransportDto> Transports { get; set; } = new();
    public List<ConfirmedDayDto> Days { get; set; } = new();
}

public sealed class ConfirmedHotelDto
{
    public string Name { get; set; } = "";
    public string? Address { get; set; }
    public string? ContactPhone { get; set; }
    public string? ContactEmail { get; set; }
    public string? RoomType { get; set; }
    public int Rooms { get; set; }
    public string? CheckInDate { get; set; }
    public string? CheckOutDate { get; set; }
}

public sealed class ConfirmedTransportDto
{
    public int? LegIndex { get; set; }
    public string? Type { get; set; }
    public string? Provider { get; set; }
    public string? ContactPhone { get; set; }
    public string? ContactEmail { get; set; }
    public string? From { get; set; }
    public string? To { get; set; }
    public string? DepartureTime { get; set; }
    public string? ArrivalTime { get; set; }
    public int Travellers { get; set; }
}

public sealed class ConfirmedDayDto
{
    public int DayNumber { get; set; }
    public string Date { get; set; } = "";
    public List<ConfirmedStopDto> Stops { get; set; } = new();
    public List<ConfirmedRouteDto> Routes { get; set; } = new();
}

public sealed class ConfirmedStopDto
{
    public string Kind { get; set; } = "";
    public string Name { get; set; } = "";
    public string? StartTime { get; set; }
    public string? EndTime { get; set; }
}

public sealed class ConfirmedRouteDto
{
    public string? From { get; set; }
    public string? To { get; set; }
    public double? DistanceKm { get; set; }
    public double? TravelMinutes { get; set; }
}
