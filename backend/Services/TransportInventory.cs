using backend.Data;
using backend.Models;
using backend.Models.Enums;
using Microsoft.EntityFrameworkCore;

namespace backend.Services;

/// <summary>
/// Shared transport reservation-state and locking rules. Keeping this in one
/// place prevents create, availability, update, and confirmation paths from
/// counting different booking states.
/// </summary>
internal static class TransportInventory
{
    internal static readonly BookingStatus[] ActiveReservationStatuses =
    {
        BookingStatus.Draft,
        BookingStatus.AwaitingApproval,
        BookingStatus.Confirmed
    };

    internal static async Task<TransportOption?> LoadForUpdateAsync(
        AppDbContext db,
        int transportOptionId,
        CancellationToken cancellationToken = default)
    {
        if (db.Database.ProviderName?.Contains("Npgsql", StringComparison.OrdinalIgnoreCase) == true)
        {
            return await db.TransportOptions
                .FromSqlRaw(
                    "SELECT * FROM \"TransportOptions\" WHERE \"Id\" = {0} FOR UPDATE",
                    transportOptionId)
                .SingleOrDefaultAsync(cancellationToken);
        }

        return await db.TransportOptions
            .SingleOrDefaultAsync(option => option.Id == transportOptionId, cancellationToken);
    }

    internal static async Task<int> CountReservedSeatsAsync(
        AppDbContext db,
        int transportOptionId,
        int? excludingBookingId = null,
        CancellationToken cancellationToken = default)
    {
        var query = db.BookingItems
            .AsNoTracking()
            .Where(item => item.TransportOptionId == transportOptionId
                && item.ItemType == BookingItemType.Transport
                && ActiveReservationStatuses.Contains(item.Booking.Status));

        if (excludingBookingId.HasValue)
            query = query.Where(item => item.BookingId != excludingBookingId.Value);

        return await query.SumAsync(item => item.Quantity, cancellationToken);
    }

    internal static async Task ValidateConfirmationAsync(
        AppDbContext db,
        int bookingId,
        CancellationToken cancellationToken = default)
    {
        var booking = await db.Bookings
            .Include(item => item.Itinerary)
                .ThenInclude(item => item!.TripRequest)
            .AsNoTracking()
            .SingleOrDefaultAsync(item => item.Id == bookingId, cancellationToken);
        if (booking is null)
            throw new TransportBusinessException("TRANSPORT_SEGMENT_UNRESOLVED", "The booking could not be resolved for transport confirmation.");

        var proposedItems = await db.BookingItems
            .AsNoTracking()
            .Where(item => item.BookingId == bookingId && item.ItemType == BookingItemType.Transport)
            .ToListAsync(cancellationToken);

        ValidateLegContract(booking.Itinerary?.TripRequest, proposedItems);

        foreach (var group in proposedItems
                     .GroupBy(item => item.TransportOptionId)
                     .OrderBy(group => group.Key))
        {
            if (group.Key is not int transportOptionId)
            {
                throw new TransportBusinessException(
                    "TRANSPORT_SEGMENT_UNRESOLVED",
                    "A transport booking item is missing its transport option.");
            }

            var transport = await LoadForUpdateAsync(db, transportOptionId, cancellationToken);
            if (transport is null)
            {
                throw new TransportBusinessException(
                    "TRANSPORT_UNAVAILABLE",
                    "The requested transport option no longer exists.");
            }

            if (transport.Status != TransportStatus.Active)
            {
                throw new TransportBusinessException(
                    "TRANSPORT_INACTIVE",
                    "The requested transport option is no longer active.");
            }

            if (group.Any(item => item.Quantity <= 0))
            {
                throw new TransportBusinessException(
                    "TRANSPORT_QUANTITY_INVALID",
                    "Transport booking quantities must be positive.");
            }

            var currentBookingSeats = group.Sum(item => item.Quantity);
            var otherReservedSeats = await CountReservedSeatsAsync(
                db,
                transportOptionId,
                excludingBookingId: bookingId,
                cancellationToken);

            if (otherReservedSeats + currentBookingSeats > transport.Capacity)
            {
                throw new TransportBusinessException(
                    "TRANSPORT_CAPACITY_CONFLICT",
                    "The requested transport no longer has enough capacity for this booking.");
            }
        }
    }

    private static void ValidateLegContract(
        TripRequest? trip,
        IReadOnlyCollection<BookingItem> transportItems)
    {
        if (trip is null)
            throw new TransportBusinessException(
                "TRANSPORT_SEGMENT_UNRESOLVED",
                "The booking has no authoritative trip request for transport confirmation.");

        var destinationIds = TransportCompatibility.ResolveDestinationIds(trip);
        var expectedLegCount = Math.Max(0, destinationIds.Count - 1) + (trip.AirportPickup ? 1 : 0);
        if (expectedLegCount == 0)
        {
            if (transportItems.Any(item => item.TransportLegIndex.HasValue))
                throw new TransportBusinessException(
                    "TRANSPORT_LEG_INDEX_INVALID",
                    "A single-destination transport item must not have a leg index.");
            return;
        }

        var indexes = transportItems.Select(item => item.TransportLegIndex).ToList();
        if (transportItems.Count != expectedLegCount ||
            indexes.Any(index => !index.HasValue || index < 0 || index >= expectedLegCount) ||
            indexes.Distinct().Count() != expectedLegCount)
        {
            throw new TransportBusinessException(
                "TRANSPORT_LEG_COVERAGE_INCOMPLETE",
                $"The booking must contain exactly one transport item for each leg index 0 through {expectedLegCount - 1}.");
        }
    }
}
