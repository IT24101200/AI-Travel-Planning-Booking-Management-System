using System.ComponentModel.DataAnnotations;

namespace backend.DTOs;

public sealed class ItineraryChangeRequestDto
{
    [MaxLength(1000)] public string Notes { get; set; } = "";
    public List<HotelChangeSelectionDto> Hotels { get; set; } = new();
    public List<TransportChangeSelectionDto> Transports { get; set; } = new();
}
public sealed class HotelChangeSelectionDto
{
    [Range(1, int.MaxValue)] public int BookingItemId { get; set; }
    [Range(1, int.MaxValue)] public int RoomId { get; set; }
}
public sealed class TransportChangeSelectionDto
{
    [Range(1, int.MaxValue)] public int BookingItemId { get; set; }
    [Range(1, int.MaxValue)] public int TransportOptionId { get; set; }
}
public sealed class ItineraryChangeOptionsDto
{
    public List<HotelChangeGroupDto> Hotels { get; set; } = new();
    public List<TransportChangeGroupDto> Transports { get; set; } = new();
}
public sealed class HotelChangeGroupDto
{
    public int BookingItemId { get; set; }
    public int CurrentRoomId { get; set; }
    public string HotelName { get; set; } = "";
    public string CheckInDate { get; set; } = "";
    public string CheckOutDate { get; set; } = "";
    public string? AvailabilityNotice { get; set; }
    public List<HotelChangeOptionDto> Options { get; set; } = new();
}
public sealed class HotelChangeOptionDto
{
    public int RoomId { get; set; }
    public int HotelId { get; set; }
    public string HotelName { get; set; } = "";
    public string RoomType { get; set; } = "";
    public double DistanceKm { get; set; }
    public decimal Total { get; set; }
    public string Currency { get; set; } = "";
}
public sealed class TransportChangeGroupDto
{
    public int BookingItemId { get; set; }
    public int CurrentTransportOptionId { get; set; }
    public int? LegIndex { get; set; }
    public string RouteFrom { get; set; } = "";
    public string RouteTo { get; set; } = "";
    public List<TransportChangeOptionDto> Options { get; set; } = new();
}
public sealed class TransportChangeOptionDto
{
    public int TransportOptionId { get; set; }
    public string Type { get; set; } = "";
    public string Provider { get; set; } = "";
    public DateTime DepartureTime { get; set; }
    public DateTime ArrivalTime { get; set; }
    public decimal Total { get; set; }
    public string Currency { get; set; } = "";
}
