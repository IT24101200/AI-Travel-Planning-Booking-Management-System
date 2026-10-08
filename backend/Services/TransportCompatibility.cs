using System.Text.Json;
using backend.Data;
using backend.Models;
using backend.Models.Enums;
using Microsoft.EntityFrameworkCore;

namespace backend.Services;

/// <summary>
/// A safe, stable transport business validation failure. The code is suitable
/// for translating into an API or agent error without exposing provider details.
/// </summary>
public sealed class TransportBusinessException : InvalidOperationException
{
    public TransportBusinessException(string code, string message)
        : base(message)
    {
        Code = code;
    }

    public string Code { get; }
}

/// <summary>
/// Applies the authoritative route/date contract for legacy single transport
/// items and explicitly ordered multi-leg transport items.
/// </summary>
public static class TransportCompatibility
{
    public static async Task ValidateAsync(
        AppDbContext db,
        TransportOption transport,
        TripRequest trip,
        CancellationToken cancellationToken = default,
        int? transportLegIndex = null,
        IReadOnlyList<int>? plannedDestinationIds = null)
    {
        if (transport.ArrivalTime <= transport.DepartureTime)
        {
            throw new TransportBusinessException(
                "TRANSPORT_DATE_INCOMPATIBLE",
                "The selected transport has an invalid schedule.");
        }

        if (trip.EndDate.Date < trip.StartDate.Date ||
            transport.DepartureTime.Date < trip.StartDate.Date ||
            transport.ArrivalTime.Date > trip.EndDate.Date)
        {
            throw new TransportBusinessException(
                "TRANSPORT_DATE_INCOMPATIBLE",
                "The selected transport schedule is outside the requested trip dates.");
        }

        var destinationIds = plannedDestinationIds?.ToList() ?? ResolveDestinationIds(trip);
        if (destinationIds.Count == 0)
        {
            throw new TransportBusinessException(
                "TRANSPORT_SEGMENT_UNRESOLVED",
                "The requested trip has no authoritative destination segment for transport validation.");
        }

        var destinations = await db.Destinations
            .AsNoTracking()
            .Where(destination => destinationIds.Contains(destination.Id))
            .ToListAsync(cancellationToken);

        if (destinations.Count != destinationIds.Count)
        {
            throw new TransportBusinessException(
                "TRANSPORT_SEGMENT_UNRESOLVED",
                "One or more requested destinations could not be resolved for transport validation.");
        }

        if ((destinationIds.Count > 1 || trip.AirportPickup) && !transportLegIndex.HasValue)
        {
            throw new TransportBusinessException(
                "TRANSPORT_MULTI_LEG_SCHEMA_REQUIRED",
                "A multi-destination transport item must identify its ordered leg.");
        }

        var orderedNames = destinationIds
            .Select(id => destinations.Single(destination => destination.Id == id).Name)
            .Select(Normalize)
            .ToList();
        if (trip.AirportPickup)
            orderedNames.Insert(0, AirportName(trip.AirportCode));

        if (orderedNames.Any(string.IsNullOrWhiteSpace))
        {
            throw new TransportBusinessException(
                "TRANSPORT_SEGMENT_UNRESOLVED",
                "The requested destination segment is not resolvable for transport validation.");
        }

        var routeFrom = Normalize(transport.RouteFrom);
        var routeTo = Normalize(transport.RouteTo);
        bool routeMatches;
        if (orderedNames.Count == 1)
        {
            if (transportLegIndex.HasValue)
            {
                throw new TransportBusinessException(
                    "TRANSPORT_LEG_INDEX_INVALID",
                    "A single-destination trip cannot contain an indexed transport leg.");
            }

            routeMatches = routeFrom == orderedNames[0] || routeTo == orderedNames[0];
        }
        else
        {
            var expectedLegCount = orderedNames.Count - 1;
            if (transportLegIndex is < 0 || transportLegIndex >= expectedLegCount)
            {
                throw new TransportBusinessException(
                    "TRANSPORT_LEG_INDEX_INVALID",
                    $"Transport leg index must be between 0 and {expectedLegCount - 1}.");
            }

            var resolvedLegIndex = transportLegIndex.GetValueOrDefault();
            var expectedFrom = orderedNames[resolvedLegIndex];
            var expectedTo = orderedNames[resolvedLegIndex + 1];
            routeMatches = routeFrom == expectedFrom && routeTo == expectedTo;
        }

        if (!routeMatches)
        {
            throw new TransportBusinessException(
                "TRANSPORT_ROUTE_INCOMPATIBLE",
                "The selected transport route is not compatible with the requested trip destinations.");
        }
    }

    public static List<int> ResolveDestinationIds(TripRequest trip)
    {
        if (!string.IsNullOrWhiteSpace(trip.DestinationSelectionsJson))
        {
            try
            {
                var selections = JsonSerializer.Deserialize<List<TripRequestDestinationSelection>>(
                    trip.DestinationSelectionsJson);
                if (selections is not null && selections.Count > 0)
                {
                    var ids = selections
                        .OrderBy(selection => selection.Order)
                        .Select(selection => selection.Id)
                        .ToList();
                    if (ids.Any(id => id <= 0) || ids.Distinct().Count() != ids.Count)
                    {
                        throw new TransportBusinessException(
                            "TRANSPORT_SEGMENT_UNRESOLVED",
                            "The requested destination segment is invalid for transport validation.");
                    }
                    return ResolvePlannedOrder(trip, ids);
                }
            }
            catch (JsonException)
            {
                // Legacy DestinationId remains the compatibility fallback below.
            }
        }

        return trip.DestinationId.HasValue
            ? new List<int> { trip.DestinationId.GetValueOrDefault() }
            : new List<int>();
    }

    public static string Normalize(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) return string.Empty;
        return string.Join(
            " ",
            value.Trim().Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries));
    }

    public static string AirportName(string code) => code == "HRI"
        ? "Mattala Rajapaksa International Airport" : "Bandaranaike International Airport";

    private static List<int> ResolvePlannedOrder(TripRequest trip, List<int> requested)
    {
        if (string.IsNullOrWhiteSpace(trip.PlanJson)) return requested;
        using var plan = JsonDocument.Parse(trip.PlanJson);
        if (!plan.RootElement.TryGetProperty("itinerary", out var itinerary) ||
            !itinerary.TryGetProperty("route_destination_ids", out var order)) return requested;
        var ids = order.EnumerateArray().Select(id => id.GetInt32()).ToList();
        if (!ids.OrderBy(id => id).SequenceEqual(requested.OrderBy(id => id)))
            throw new TransportBusinessException("TRANSPORT_SEGMENT_UNRESOLVED", "The planned route does not match the selected destinations.");
        return ids;
    }
}
