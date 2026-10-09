using System.Globalization;
using System.Text.Json;
using backend.DTOs;
using backend.Models;
using backend.Models.Enums;

namespace backend.Services;

internal static class TripConfirmationBuilder
{
    public static TripConfirmationDto Build(Booking booking)
    {
        var itinerary = booking.Itinerary;
        var result = new TripConfirmationDto
        {
            BookingId = booking.Id, ItineraryId = itinerary.Id,
            BookingReference = booking.BookingReference,
            StartDate = Date(itinerary.StartDate), EndDate = Date(itinerary.EndDate),
            Travellers = itinerary.TripRequest.TravellerCount,
            AmountPaid = booking.TotalCost, Currency = booking.Currency,
            Hotels = booking.BookingItems.Where(i => i.ItemType == BookingItemType.Room)
                .OrderBy(i => i.CheckInDate).ThenBy(i => i.Id).Select(i => new ConfirmedHotelDto
                {
                    Name = i.Room?.Hotel?.Name ?? "Booked accommodation",
                    Address = i.Room?.Hotel?.Address,
                    ContactPhone = i.Room?.Hotel?.ContactPhone,
                    ContactEmail = i.Room?.Hotel?.ContactEmail,
                    RoomType = i.Room?.RoomType, Rooms = i.Quantity,
                    CheckInDate = i.CheckInDate.HasValue ? Date(i.CheckInDate.Value) : null,
                    CheckOutDate = i.CheckOutDate.HasValue ? Date(i.CheckOutDate.Value) : null
                }).ToList(),
            Transports = booking.BookingItems.Where(i => i.ItemType == BookingItemType.Transport)
                .OrderBy(i => i.TransportLegIndex ?? int.MaxValue)
                .ThenBy(i => i.TransportDepartureTimeSnapshot ?? i.TransportOption?.DepartureTime)
                .ThenBy(i => i.Id).Select(i => new ConfirmedTransportDto
                {
                    LegIndex = i.TransportLegIndex,
                    Type = i.TransportTypeSnapshot ?? i.TransportOption?.Type.ToString(),
                    Provider = i.TransportProviderSnapshot ?? i.TransportOption?.Provider,
                    // Do not attach a different operator's contact to a saved booking.
                    ContactPhone = SameProvider(i) ? i.TransportOption?.ContactPhone : null,
                    ContactEmail = SameProvider(i) ? i.TransportOption?.ContactEmail : null,
                    From = i.TransportRouteFromSnapshot ?? i.TransportOption?.RouteFrom,
                    To = i.TransportRouteToSnapshot ?? i.TransportOption?.RouteTo,
                    DepartureTime = Local(i.TransportDepartureTimeSnapshot ?? i.TransportOption?.DepartureTime),
                    ArrivalTime = Local(i.TransportArrivalTimeSnapshot ?? i.TransportOption?.ArrivalTime),
                    Travellers = i.Quantity
                }).ToList()
        };

        for (var date = itinerary.StartDate.Date; date <= itinerary.EndDate.Date; date = date.AddDays(1))
        {
            var day = new ConfirmedDayDto { DayNumber = (date - itinerary.StartDate.Date).Days + 1, Date = Date(date) };
            foreach (var hotel in result.Hotels.Where(h => h.CheckOutDate == day.Date))
                day.Stops.Add(new() { Kind = "Check-out", Name = hotel.Name });
            foreach (var item in itinerary.ItineraryItems.Where(i => i.DayNumber == day.DayNumber)
                .OrderBy(i => i.SequenceOrder).ThenBy(i => i.Id))
                day.Stops.Add(new() { Kind = "Journey", Name = item.Tour?.Name ?? "Booked activity",
                    StartTime = item.StartTime.ToString(@"hh\:mm"), EndTime = item.EndTime.ToString(@"hh\:mm") });
            foreach (var hotel in result.Hotels.Where(h => h.CheckInDate == day.Date))
                day.Stops.Add(new() { Kind = "Check-in", Name = hotel.Name });
            result.Days.Add(day);
        }
        AddRoadRoutes(result, itinerary.TripRequest.PlanJson);
        return result;
    }

    private static void AddRoadRoutes(TripConfirmationDto result, string? planJson)
    {
        if (string.IsNullOrWhiteSpace(planJson)) return;
        try
        {
            using var doc = JsonDocument.Parse(planJson);
            var root = doc.RootElement;
            if (root.ValueKind != JsonValueKind.Object) return;
            var source = root.TryGetProperty("booking_details", out var details) && details.ValueKind == JsonValueKind.Object
                && details.TryGetProperty("itinerary", out var planned) ? planned
                : root.TryGetProperty("itinerary", out planned) ? planned : default;
            if (source.ValueKind != JsonValueKind.Object || !source.TryGetProperty("schedule", out var schedule)
                || schedule.ValueKind != JsonValueKind.Array) return;
            foreach (var entry in schedule.EnumerateArray())
            {
                if (entry.ValueKind != JsonValueKind.Object || !entry.TryGetProperty("day_number", out var number)
                    || number.ValueKind != JsonValueKind.Number || !number.TryGetInt32(out var index)) continue;
                var day = result.Days.FirstOrDefault(d => d.DayNumber == index);
                if (day is null || !entry.TryGetProperty("travel_legs", out var legs) || legs.ValueKind != JsonValueKind.Array) continue;
                foreach (var leg in legs.EnumerateArray().Where(l => l.ValueKind == JsonValueKind.Object))
                    day.Routes.Add(new() { From = Place(leg, "from"), To = Place(leg, "to"),
                        DistanceKm = Number(leg, "distance_km"), TravelMinutes = Number(leg, "duration_minutes") });
            }
        }
        catch (JsonException) { /* Legacy plans still include all persisted activities, stays and transport. */ }
    }

    private static string? Place(JsonElement leg, string name) =>
        leg.TryGetProperty(name, out var place) && place.ValueKind == JsonValueKind.Object
        && place.TryGetProperty("name", out var label) && label.ValueKind == JsonValueKind.String ? label.GetString() : null;
    private static double? Number(JsonElement element, string name) =>
        element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.Number && value.TryGetDouble(out var number) ? number : null;
    private static bool SameProvider(BookingItem item) => item.TransportProviderSnapshot is null ||
        string.Equals(item.TransportProviderSnapshot, item.TransportOption?.Provider, StringComparison.OrdinalIgnoreCase);
    private static string Date(DateTime date) => date.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
    private static string? Local(DateTime? date) => date?.ToString("yyyy-MM-dd'T'HH:mm:ss", CultureInfo.InvariantCulture);
}
