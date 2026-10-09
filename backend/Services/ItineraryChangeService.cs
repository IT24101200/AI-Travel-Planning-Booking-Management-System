using System.Data;
using System.Text.Json;
using System.Text.Json.Nodes;
using backend.Data;
using backend.DTOs;
using backend.Models;
using backend.Models.Enums;
using Microsoft.EntityFrameworkCore;

namespace backend.Services;

public sealed class ItineraryChangeService(AppDbContext db, IHotelRoadDistanceService roads,
    IRevisionPlanningService planner, ICurrencyConversionService currency, ILogger<ItineraryChangeService>? logger = null)
{
    private async Task<Booking> ContextAsync(int itineraryId, string customerId, CancellationToken ct)
    {
        var booking = await db.Bookings.Include(b => b.Itinerary).ThenInclude(i => i.TripRequest)
            .Include(b => b.BookingItems).ThenInclude(i => i.Room).ThenInclude(r => r!.Hotel)
            .Include(b => b.BookingItems).ThenInclude(i => i.TransportOption)
            .SingleOrDefaultAsync(b => b.ItineraryId == itineraryId && b.CustomerId == customerId, ct)
            ?? throw new KeyNotFoundException("Itinerary not found.");
        if (booking.Status is not (BookingStatus.Draft or BookingStatus.AwaitingApproval or BookingStatus.Confirmed) ||
            booking.Itinerary.Status == ItineraryStatus.Discarded)
            throw new InvalidOperationException("This itinerary is no longer available for changes.");
        if (CustomerRevisionContract.Pending(CustomerRevisionContract.Read(booking.Itinerary.TripRequest)))
            throw new InvalidOperationException("Your previous change request is still being planned.");
        if (booking.BookingItems.Any(i => i.ItemType == BookingItemType.Room &&
            (i.Room is null || !i.CheckInDate.HasValue || !i.CheckOutDate.HasValue)))
            throw new InvalidOperationException("This booking is missing dated hotel details. Please ask your travel agent to update it.");
        if (await db.Payments.AnyAsync(p => p.BookingId == booking.Id &&
            (p.Status == PaymentStatus.Paid || p.Status == PaymentStatus.Pending), ct))
            throw new InvalidOperationException("An itinerary with a payment or payment in progress needs your travel agent to arrange changes.");
        return booking;
    }

    public async Task<ItineraryChangeOptionsDto> OptionsAsync(int itineraryId, string customerId, CancellationToken ct = default)
    {
        var booking = await ContextAsync(itineraryId, customerId, ct);
        return await OptionsAsync(booking, ct);
    }

    private async Task<ItineraryChangeOptionsDto> OptionsAsync(Booking booking, CancellationToken ct)
    {
        var trip = booking.Itinerary.TripRequest;
        var result = new ItineraryChangeOptionsDto();
        var hotels = await db.Hotels.Where(h => h.Status == HotelStatus.Active).ToListAsync(ct);
        using var routingBudget = CancellationTokenSource.CreateLinkedTokenSource(ct);
        routingBudget.CancelAfter(TimeSpan.FromSeconds(8));
        foreach (var item in booking.BookingItems.Where(i => i.ItemType == BookingItemType.Room).OrderBy(i => i.CheckInDate))
        {
            if (item.Room?.Hotel is not Hotel origin || !item.CheckInDate.HasValue || !item.CheckOutDate.HasValue) continue;
            var group = new HotelChangeGroupDto { BookingItemId = item.Id, CurrentRoomId = item.RoomId!.Value,
                HotelName = origin.Name, CheckInDate = item.CheckInDate.Value.ToString("yyyy-MM-dd"),
                CheckOutDate = item.CheckOutDate.Value.ToString("yyyy-MM-dd") };
            Dictionary<int, double> distances;
            try
            {
                routingBudget.Token.ThrowIfCancellationRequested();
                distances = await roads.FromHotelAsync(origin, hotels, routingBudget.Token);
            }
            catch (Exception error) when (!ct.IsCancellationRequested && (error is HttpRequestException or OperationCanceledException))
            {
                logger?.LogWarning(error, "Could not verify nearby hotel distances for Hotel #{HotelId}.", origin.Id);
                // Same-building rooms need no external distance lookup. Other
                // hotels remain unavailable until their road distance is verified.
                distances = new Dictionary<int, double> { [origin.Id] = 0 };
                group.AvailabilityNotice = "Nearby hotel distances could not be verified. Showing rooms at your current hotel only. Retry to load nearby hotels; transport choices remain available.";
            }
            var nearIds = distances.Where(pair => pair.Value <= 15).Select(pair => pair.Key).ToList();
            var rooms = await db.Rooms.Include(r => r.Hotel).Where(r => nearIds.Contains(r.HotelId) &&
                r.Status == RoomStatus.Active && r.Hotel.Status == HotelStatus.Active && r.Capacity >= trip.TravellerCount).ToListAsync(ct);
            foreach (var room in rooms)
            {
                if (await RoomInventory.BookedPeakAsync(db, room.Id, item.CheckInDate.Value, item.CheckOutDate.Value, booking.Id) >= room.TotalRooms) continue;
                group.Options.Add(new HotelChangeOptionDto { RoomId = room.Id, HotelId = room.HotelId,
                    HotelName = room.Hotel.Name, RoomType = room.RoomType, DistanceKm = Math.Round(distances[room.HotelId], 2),
                    Total = currency.Convert(room.PricePerNight, room.Currency, trip.Currency) *
                        Math.Max(1, (item.CheckOutDate.Value.Date - item.CheckInDate.Value.Date).Days), Currency = trip.Currency });
            }
            group.Options = group.Options.OrderBy(o => o.DistanceKm).ThenBy(o => o.Total).ThenBy(o => o.RoomId).ToList();
            result.Hotels.Add(group);
        }
        foreach (var item in booking.BookingItems.Where(i => i.ItemType == BookingItemType.Transport).OrderBy(i => i.TransportLegIndex))
        {
            if (item.TransportOption is not TransportOption current) continue;
            var from = current.RouteFrom.Trim(); var to = current.RouteTo.Trim();
            var day = current.DepartureTime.Date; var next = day.AddDays(1);
            var options = await db.TransportOptions.Where(t => t.Status == TransportStatus.Active && t.Type == current.Type &&
                t.RouteFrom.Trim() == from && t.RouteTo.Trim() == to && t.Capacity >= trip.TravellerCount &&
                t.DepartureTime >= day && t.DepartureTime < next && t.ArrivalTime > t.DepartureTime &&
                t.ArrivalTime.Date <= trip.EndDate.Date).OrderBy(t => t.DepartureTime).ThenBy(t => t.Id).ToListAsync(ct);
            var group = new TransportChangeGroupDto { BookingItemId = item.Id, CurrentTransportOptionId = current.Id,
                LegIndex = item.TransportLegIndex, RouteFrom = current.RouteFrom, RouteTo = current.RouteTo };
            foreach (var option in options)
            {
                var seats = await TransportInventory.CountReservedSeatsAsync(db, option.Id, booking.Id, ct);
                if (seats + trip.TravellerCount > option.Capacity) continue;
                group.Options.Add(new TransportChangeOptionDto { TransportOptionId = option.Id, Type = option.Type.ToString(),
                    Provider = option.Provider, DepartureTime = option.DepartureTime, ArrivalTime = option.ArrivalTime,
                    Total = currency.Convert(option.Price, option.Currency, trip.Currency) * trip.TravellerCount, Currency = trip.Currency });
            }
            group.Options = group.Options.OrderBy(o => o.Total).ThenBy(o => o.DepartureTime).ThenBy(o => o.TransportOptionId).ToList();
            result.Transports.Add(group);
        }
        return result;
    }

    public async Task<object> RequestAsync(int itineraryId, string customerId, ItineraryChangeRequestDto input,
        string authorization, CancellationToken ct = default)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        // Serialize requests for the same trip with its final persistence callback.
        var tripId = await db.Itineraries.Where(i => i.Id == itineraryId && i.CustomerId == customerId).Select(i => (int?)i.TripRequestId).SingleOrDefaultAsync(ct)
            ?? throw new KeyNotFoundException("Itinerary not found.");
        if (db.Database.ProviderName?.Contains("Npgsql") == true)
            await db.Database.ExecuteSqlRawAsync("SELECT pg_advisory_xact_lock({0})", new object[] { tripId }, ct);
        var booking = await ContextAsync(itineraryId, customerId, ct);
        var trip = booking.Itinerary.TripRequest;
        var saved = JsonNode.Parse(trip.PlanJson ?? "{}") as JsonObject ?? new JsonObject();
        if (saved["itinerary"] is not JsonObject baseline || baseline["route_destination_ids"] is not JsonArray)
            throw new InvalidOperationException("Request a new geographic plan before changing this older itinerary.");
        if (input.Hotels.Count > 100 || input.Transports.Count > 100 || input.Hotels.Select(h => h.BookingItemId).Distinct().Count() != input.Hotels.Count ||
            input.Transports.Select(t => t.BookingItemId).Distinct().Count() != input.Transports.Count)
            throw new ArgumentException("Each booking item can be changed only once per request.");
        var options = await OptionsAsync(booking, ct);
        foreach (var selection in input.Hotels)
            if (!options.Hotels.Any(g => g.BookingItemId == selection.BookingItemId && g.Options.Any(o => o.RoomId == selection.RoomId)))
                throw new ArgumentException("A selected hotel room is unavailable or outside the 15 km road range.");
        foreach (var selection in input.Transports)
            if (!options.Transports.Any(g => g.BookingItemId == selection.BookingItemId && g.Options.Any(o => o.TransportOptionId == selection.TransportOptionId)))
                throw new ArgumentException("A selected transport is unavailable or does not match this route, date and vehicle type.");
        var changed = input.Hotels.Any(s => booking.BookingItems.Any(i => i.Id == s.BookingItemId && i.RoomId != s.RoomId)) ||
            input.Transports.Any(s => booking.BookingItems.Any(i => i.Id == s.BookingItemId && i.TransportOptionId != s.TransportOptionId));
        if (!changed && string.IsNullOrWhiteSpace(input.Notes)) throw new ArgumentException("Select an alternative or enter instructions before requesting changes.");
        var revision = JsonSerializer.SerializeToNode(new {
            id = Guid.NewGuid().ToString("N"), status = "Pending", booking_id = booking.Id,
            original_trip_status = trip.Status.ToString(), notes = input.Notes.Trim(),
            rooms = booking.BookingItems.Where(i => i.ItemType == BookingItemType.Room).Select(i => new {
                room_id = input.Hotels.FirstOrDefault(s => s.BookingItemId == i.Id)?.RoomId ?? i.RoomId,
                check_in = i.CheckInDate!.Value.ToString("yyyy-MM-dd"), check_out = i.CheckOutDate!.Value.ToString("yyyy-MM-dd") }),
            transports = booking.BookingItems.Where(i => i.ItemType == BookingItemType.Transport).Select(i => new {
                transport_option_id = input.Transports.FirstOrDefault(s => s.BookingItemId == i.Id)?.TransportOptionId ?? i.TransportOptionId,
                leg_index = i.TransportLegIndex }),
            reserved_items = booking.BookingItems.Select(i => new { room_id = i.RoomId, transport_option_id = i.TransportOptionId,
                quantity = i.Quantity, check_in = i.CheckInDate?.ToString("yyyy-MM-dd"), check_out = i.CheckOutDate?.ToString("yyyy-MM-dd") }),
            baseline_itinerary = baseline.DeepClone(),
        })!;
        saved["revision_request"] = revision;
        trip.PlanJson = saved.ToJsonString(); trip.Status = TripRequestStatus.Planning; trip.FailureReason = null; trip.RetryCount = 0;
        db.AgentLogs.Add(new AgentLog { TripRequestId = trip.Id, AgentName = "Customer change request", StepName = "Requested hotel and transport changes",
            Input = revision.ToJsonString(), Output = "Preparing a revised proposal; current booking remains available.", Status = "Started", Timestamp = DateTime.UtcNow });
        await db.SaveChangesAsync(ct);
        await planner.TriggerAsync(trip.Id, input.Notes.Trim(), authorization, ct);
        await transaction.CommitAsync(ct);
        return new { tripRequestId = trip.Id, status = "Planning", message = "Your change request has been sent to the planning agents." };
    }
}
