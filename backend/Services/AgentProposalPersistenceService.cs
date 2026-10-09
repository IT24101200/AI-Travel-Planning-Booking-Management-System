using System.Data;
using System.Globalization;
using System.Text.Json;
using backend.Data;
using backend.Models;
using backend.Models.Enums;
using Microsoft.EntityFrameworkCore;

namespace backend.Services;

/// <summary>
/// The single automatic persistence owner for a final AI proposal.
/// Python produces a proposal; this service revalidates catalogue data and
/// atomically creates the itinerary, itinerary items, booking, and booking items.
/// </summary>
public sealed class AgentProposalPersistenceService : IAgentProposalPersistenceService
{
    private sealed record ValidatedTransportSelection(
        int? LegIndex,
        TransportOption Entity,
        decimal UnitPrice,
        decimal Total);
    private sealed record ValidatedRoomStay(Room Entity, DateTime CheckIn, DateTime CheckOut, decimal Total);

    private readonly AppDbContext _db;
    private readonly ICurrencyConversionService _currency;
    private readonly IAgentLogStreamService? _logStream;
    private readonly INotificationService _notifications;

    public AgentProposalPersistenceService(
        AppDbContext db,
        ICurrencyConversionService? currency = null,
        IAgentLogStreamService? logStream = null,
        INotificationService? notifications = null)
    {
        _db = db;
        _currency = currency ?? new CurrencyConversionService();
        _logStream = logStream;
        _notifications = notifications ?? new NotificationService(db);
    }

    public async Task<AgentProposalPersistenceResult> PersistAsync(
        int tripRequestId,
        JsonElement planJson,
        int retryCount,
        CancellationToken cancellationToken = default)
    {
        await using var transaction = await _db.Database.BeginTransactionAsync(
            IsolationLevel.Serializable, cancellationToken);

        // PostgreSQL serializes callbacks for the same TripRequest even when
        // two workers submit the same final result concurrently.
        if (_db.Database.ProviderName?.Contains("Npgsql", StringComparison.OrdinalIgnoreCase) == true)
        {
            await _db.Database.ExecuteSqlRawAsync(
                "SELECT pg_advisory_xact_lock({0})", new object[] { tripRequestId }, cancellationToken);
        }

        var trip = await _db.TripRequests
            .FirstOrDefaultAsync(t => t.Id == tripRequestId, cancellationToken);
        if (trip is null)
            throw new ProposalPersistenceException("TRIP_NOT_FOUND", $"TripRequest {tripRequestId} was not found.");

        CustomerRevisionContract.ValidateCallback(trip, planJson);
        var revision = CustomerRevisionContract.Read(trip);
        Booking? revisionBooking = null;
        if (CustomerRevisionContract.Pending(revision))
        {
            var bookingId = revision!["booking_id"]!.GetValue<int>();
            revisionBooking = await _db.Bookings.Include(b => b.Itinerary).FirstOrDefaultAsync(b => b.Id == bookingId && b.CustomerId == trip.CustomerId && b.Itinerary.TripRequestId == trip.Id, cancellationToken);
            if (trip.Status != TripRequestStatus.Planning || revisionBooking is null ||
                revisionBooking.Status is not (BookingStatus.Draft or BookingStatus.AwaitingApproval or BookingStatus.Confirmed) ||
                await _db.Payments.AnyAsync(p => p.BookingId == bookingId && (p.Status == PaymentStatus.Paid || p.Status == PaymentStatus.Pending), cancellationToken))
                throw new ProposalPersistenceException("REVISION_STATE_CHANGED", "The booking changed while replanning. Please review the current booking.");
        }

        var existingItinerary = await _db.Itineraries
            .OrderByDescending(i => i.CreatedAt)
            .FirstOrDefaultAsync(i => i.TripRequestId == tripRequestId, cancellationToken);
        if (existingItinerary is not null)
        {
            var existingBooking = await _db.Bookings
                .FirstOrDefaultAsync(b => b.ItineraryId == existingItinerary.Id, cancellationToken);
            if (existingBooking is null)
                throw new ProposalPersistenceException("PARTIAL_PROPOSAL", "A prior itinerary exists without its booking.");

            if (revisionBooking is null && existingBooking.Status is not (BookingStatus.Cancelled or BookingStatus.Rejected))
            {
                await transaction.CommitAsync(cancellationToken);
                return new AgentProposalPersistenceResult
                {
                    TripRequestId = tripRequestId,
                    ItineraryId = existingItinerary.Id,
                    BookingId = existingBooking.Id,
                    BookingReference = existingBooking.BookingReference,
                    BookingStatus = existingBooking.Status.ToString(),
                    AlreadyPersisted = true
                };
            }
        }

        if (trip.Status is not (TripRequestStatus.Pending or TripRequestStatus.Planning or TripRequestStatus.Planned))
            throw new ProposalPersistenceException("INVALID_TRIP_STATE", $"TripRequest {tripRequestId} is already {trip.Status}.");

        if (planJson.ValueKind != JsonValueKind.Object)
            throw new ProposalPersistenceException("INVALID_JSON", "The final proposal must be a JSON object.");
        var root = planJson;
        var suppliedTripId = OptionalInt(root, "trip_request_id");
        if (suppliedTripId.HasValue && suppliedTripId.Value != trip.Id)
            throw new ProposalPersistenceException("TRIP_MISMATCH", "Proposal TripRequestId does not match the callback route.");

        var suppliedCustomerId = OptionalString(root, "customer_id");
        if (!string.IsNullOrWhiteSpace(suppliedCustomerId) && !string.Equals(suppliedCustomerId, trip.CustomerId, StringComparison.Ordinal))
            throw new ProposalPersistenceException("CUSTOMER_MISMATCH", "Proposal customer does not match the TripRequest customer.");

        var validation = OptionalObject(root, "validation");
        if (validation.HasValue && OptionalBool(validation.Value, "is_valid") == false)
            throw new ProposalPersistenceException("INVALID_PROPOSAL", OptionalString(validation.Value, "failure_reason") ?? "AI validation failed.");

        var itinerary = RequireObject(root, "itinerary");
        var bookingDetails = RequireObject(root, "booking_details");
        var requestedDestinationIds = ParseRequestedDestinationIds(trip);
        ValidateProposalDestinationContract(root, requestedDestinationIds);
        var starterLocationId = ParseStarterLocationId(trip);
        var currency = _currency.Normalize(trip.Currency, "TripRequest currency");
        var schedule = RequireArray(itinerary, "schedule");
        var tripDays = (trip.EndDate.Date - trip.StartDate.Date).Days + 1;
        var itineraryItems = new List<ItineraryItem>();
        var scheduledDestinationIds = new HashSet<int>();
        var visitedDestinations = new List<int>();
        var tourDestinations = new Dictionary<int, int>();
        decimal tourTotal = 0m;

        foreach (var day in schedule.EnumerateArray())
        {
            var dayObject = EnsureObject(day, "itinerary day");
            var dayNumber = RequiredInt(dayObject, "day_number");
            if (dayNumber < 1 || dayNumber > tripDays)
                throw new ProposalPersistenceException("INVALID_DAY", $"Itinerary day {dayNumber} is outside the trip dates.");

            var items = RequireArray(dayObject, "items");
            var ranges = new List<(TimeSpan Start, TimeSpan End)>();
            foreach (var item in items.EnumerateArray())
            {
                var itemObject = EnsureObject(item, "itinerary item");
                var tourId = RequiredInt(itemObject, "tour_id");
                var sequence = OptionalInt(itemObject, "sequence_order") ?? (ranges.Count + 1);
                if (sequence < 1)
                    throw new ProposalPersistenceException("INVALID_SEQUENCE", $"Tour {tourId} has an invalid sequence order.");
                var start = RequiredTime(itemObject, "start_time");
                var end = RequiredTime(itemObject, "end_time");
                if (end <= start)
                    throw new ProposalPersistenceException("INVALID_TIME_RANGE", $"Tour {tourId} has an invalid time range.");
                if (ranges.Any(existing => start < existing.End && end > existing.Start))
                    throw new ProposalPersistenceException("OVERLAPPING_TOURS", $"Tours overlap on day {dayNumber}.");
                ranges.Add((start, end));

                var tour = await _db.Tours.FirstOrDefaultAsync(t => t.Id == tourId, cancellationToken);
                if (tour is null || !string.Equals(tour.Status, "Active", StringComparison.OrdinalIgnoreCase))
                    throw new ProposalPersistenceException("INVALID_TOUR", $"Tour {tourId} is missing or inactive.");
                if (requestedDestinationIds.Count > 0 && !requestedDestinationIds.Contains(tour.DestinationId))
                    throw new ProposalPersistenceException("INVALID_TOUR_DESTINATION", $"Tour {tourId} is not in the requested destination.");
                scheduledDestinationIds.Add(tour.DestinationId);
                tourDestinations[tour.Id] = tour.DestinationId;
                if (visitedDestinations.LastOrDefault() != tour.DestinationId)
                    visitedDestinations.Add(tour.DestinationId);
                var transactionTourPrice = _currency.Convert(tour.Price, tour.Currency, currency);
                tourTotal += transactionTourPrice * trip.TravellerCount;
                itineraryItems.Add(new ItineraryItem
                {
                    TourId = tour.Id,
                    DayNumber = dayNumber,
                    SequenceOrder = sequence,
                    StartTime = start,
                    EndTime = end,
                    PriceAtSelection = transactionTourPrice,
                    Currency = currency
                });
            }
        }

        if (requestedDestinationIds.Count > 1)
        {
            var missingDestinationIds = requestedDestinationIds
                .Where(destinationId => !scheduledDestinationIds.Contains(destinationId))
                .ToList();
            if (missingDestinationIds.Count > 0)
            {
                throw new ProposalPersistenceException(
                    "MISSING_DESTINATION_COVERAGE",
                    $"The proposal does not contain every requested destination: {string.Join(", ", missingDestinationIds)}.");
            }
        }

        var routeDestinationIds = requestedDestinationIds;
        var suppliedRoute = OptionalArray(itinerary, "route_destination_ids");
        if (suppliedRoute.HasValue)
        {
            routeDestinationIds = suppliedRoute.Value.EnumerateArray().Select(value => value.GetInt32()).ToList();
            if (!IsValidRoutePermutation(
                    routeDestinationIds,
                    requestedDestinationIds,
                    starterLocationId,
                    trip.AirportPickup))
                throw new ProposalPersistenceException(
                    "DESTINATION_ORDER_CONTRACT_MISMATCH",
                    "The planned route must include every selected destination and respect the selected route origin.");
            if (!visitedDestinations.SequenceEqual(routeDestinationIds))
                throw new ProposalPersistenceException("DESTINATION_BACKTRACKING", "The route must visit every selected destination once and finish its journeys before moving on.");
            foreach (var day in schedule.EnumerateArray())
            {
                var driving = OptionalDecimal(day, "travel_minutes");
                if (!driving.HasValue || driving < 0 || driving > 600 || RequiredTime(day, "day_end_time") > TimeSpan.FromHours(20))
                    throw new ProposalPersistenceException("TRAVEL_TIME_INFEASIBLE", "Daily travel must fit within ten driving hours and finish by 20:00.");
            }
        }
        if (revisionBooking is not null)
        {
            var originalTours = await _db.ItineraryItems.Where(i => i.ItineraryId == revisionBooking.ItineraryId).Select(i => i.TourId).ToListAsync(cancellationToken);
            if (!originalTours.OrderBy(id => id).SequenceEqual(itineraryItems.Select(i => i.TourId).OrderBy(id => id)))
                throw new ProposalPersistenceException("REVISION_SELECTION_MISMATCH", "Hotel and transport changes must preserve the selected journeys.");
        }
        var validatedRoomStays = await ValidateRoomStaysAsync(bookingDetails, trip, currency, cancellationToken, revisionBooking?.Id);

        // Resolve and validate every leg before any itinerary or booking save.
        // Prices, route names, snapshots, capacity, and availability all come
        // from the database entities, never from AI-supplied presentation data.
        var validatedTransportSelections = await ValidateTransportSelectionsAsync(
            bookingDetails,
            routeDestinationIds,
            trip,
            currency,
            cancellationToken, revisionBooking?.Id);
        if (suppliedRoute.HasValue)
        {
            foreach (var selection in validatedTransportSelections.Where(s => s.LegIndex.HasValue))
            {
                var index = selection.LegIndex!.Value;
                var offset = trip.AirportPickup ? 1 : 0;
                var target = routeDestinationIds[index + 1 - offset];
                var firstVisit = itineraryItems.Where(item => tourDestinations[item.TourId] == target)
                    .Min(item => trip.StartDate.Date.AddDays(item.DayNumber - 1).Add(item.StartTime));
                if (selection.Entity.ArrivalTime > firstVisit)
                    throw new ProposalPersistenceException("TRANSPORT_TIMETABLE_INFEASIBLE", "Transport arrives after the first journey at its destination.");
                if (index >= offset)
                {
                    var source = routeDestinationIds[index - offset];
                    var lastVisit = itineraryItems.Where(item => tourDestinations[item.TourId] == source)
                        .Max(item => trip.StartDate.Date.AddDays(item.DayNumber - 1).Add(item.EndTime));
                    if (selection.Entity.DepartureTime < lastVisit)
                        throw new ProposalPersistenceException("TRANSPORT_TIMETABLE_INFEASIBLE", "Transport departs before all journeys at its source destination are complete.");
                }
                else if (selection.Entity.DepartureTime < trip.StartDate.Date.Add(trip.AirportArrivalTime).AddHours(1))
                    throw new ProposalPersistenceException("TRANSPORT_TIMETABLE_INFEASIBLE", "Airport pickup departs before the arrival allowance is complete.");
            }
        }

        var roomTotal = validatedRoomStays.Sum(stay => stay.Total);
        var transportTotal = validatedTransportSelections.Sum(selection => selection.Total);
        var calculatedTotal = tourTotal + roomTotal + transportTotal;
        var reportedItineraryTotal = OptionalDecimal(itinerary, "total_estimated_cost") ?? OptionalDecimal(itinerary, "total_cost");
        if (reportedItineraryTotal.HasValue && Math.Abs(reportedItineraryTotal.Value - tourTotal) > 0.01m)
            throw new ProposalPersistenceException("ITINERARY_TOTAL_MISMATCH", $"AI itinerary total {reportedItineraryTotal.Value} does not match trusted tour total {tourTotal}.");
        var reportedCurrency = OptionalString(bookingDetails, "currency");
        if (!string.IsNullOrWhiteSpace(reportedCurrency))
            RequireSameCurrency(currency, reportedCurrency, "Booking package");
        var reportedTotal = OptionalDecimal(bookingDetails, "total_package_cost") ?? OptionalDecimal(bookingDetails, "total_cost");
        if (reportedTotal.HasValue && Math.Abs(reportedTotal.Value - calculatedTotal) > 0.01m)
            throw new ProposalPersistenceException("TOTAL_MISMATCH", $"AI total {reportedTotal.Value} does not match trusted total {calculatedTotal}.");
        if (calculatedTotal > trip.BudgetCeiling)
            throw new ProposalPersistenceException("BUDGET_EXCEEDED", $"Trusted total {calculatedTotal} exceeds budget {trip.BudgetCeiling}.");

        if (revisionBooking is not null)
        {
            foreach (var pin in revision!["rooms"]!.AsArray())
            {
                var roomId = pin!["room_id"]!.GetValue<int>();
                var from = DateTime.Parse(pin["check_in"]!.GetValue<string>(), CultureInfo.InvariantCulture);
                var to = DateTime.Parse(pin["check_out"]!.GetValue<string>(), CultureInfo.InvariantCulture);
                for (var night = from; night < to; night = night.AddDays(1))
                    if (!validatedRoomStays.Any(s => s.Entity.Id == roomId && s.CheckIn <= night && s.CheckOut > night))
                        throw new ProposalPersistenceException("REVISION_SELECTION_MISMATCH", "The revised package did not use the requested hotel for its selected stay.");
            }
            foreach (var pin in revision["transports"]!.AsArray())
            {
                var leg = pin!["leg_index"]?.GetValue<int>();
                if (!validatedTransportSelections.Any(s => s.LegIndex == leg && s.Entity.Id == pin["transport_option_id"]!.GetValue<int>()))
                    throw new ProposalPersistenceException("REVISION_SELECTION_MISMATCH", "The revised package did not use the selected transport for its route leg.");
            }
            revisionBooking.Status = BookingStatus.Cancelled;
            revisionBooking.UpdatedAt = DateTime.UtcNow;
            revisionBooking.Itinerary.Status = ItineraryStatus.Discarded;
        }

        var itineraryEntity = new Itinerary
        {
            CustomerId = trip.CustomerId,
            TripRequestId = trip.Id,
            StartDate = trip.StartDate,
            EndDate = trip.EndDate,
            Status = ItineraryStatus.Proposed,
            TotalEstimatedCost = tourTotal,
            Currency = currency,
            ExchangeRateToLkr = _currency.ExchangeRateToLkr(currency),
            CreatedAt = DateTime.UtcNow,
            ItineraryItems = itineraryItems
        };
        _db.Itineraries.Add(itineraryEntity);
        await _db.SaveChangesAsync(cancellationToken);

        var booking = new Booking
        {
            BookingReference = await GenerateBookingReferenceAsync(cancellationToken),
            CustomerId = trip.CustomerId,
            ItineraryId = itineraryEntity.Id,
            Status = BookingStatus.AwaitingApproval,
            TotalCost = calculatedTotal,
            Currency = currency,
            ExchangeRateToLkr = _currency.ExchangeRateToLkr(currency),
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
            BookingItems = itineraryItems.Select(item => new BookingItem
                {
                    ItemType = BookingItemType.Tour,
                    TourId = item.TourId,
                    Quantity = trip.TravellerCount,
                    UnitPrice = item.PriceAtSelection,
                    Subtotal = item.PriceAtSelection * trip.TravellerCount,
                    Currency = currency
                }).Concat(validatedRoomStays.Select(stay => new BookingItem
                    {
                    ItemType = BookingItemType.Room,
                    RoomId = stay.Entity.Id,
                    CheckInDate = stay.CheckIn,
                    CheckOutDate = stay.CheckOut,
                    Quantity = 1,
                    UnitPrice = stay.Total,
                    Subtotal = stay.Total,
                    Currency = currency
                    })).Concat(validatedTransportSelections.Select(selection => new BookingItem
                {
                    ItemType = BookingItemType.Transport,
                    TransportOptionId = selection.Entity.Id,
                    TransportLegIndex = selection.LegIndex,
                    TransportTypeSnapshot = selection.Entity.Type.ToString(),
                    TransportProviderSnapshot = selection.Entity.Provider,
                    TransportRouteFromSnapshot = selection.Entity.RouteFrom,
                    TransportRouteToSnapshot = selection.Entity.RouteTo,
                    TransportDepartureTimeSnapshot = selection.Entity.DepartureTime,
                    TransportArrivalTimeSnapshot = selection.Entity.ArrivalTime,
                    Quantity = trip.TravellerCount,
                    UnitPrice = selection.UnitPrice,
                    Subtotal = selection.Total,
                    Currency = currency
                })).ToList()
        };
        _db.Bookings.Add(booking);
        if (revisionBooking is not null)
        {
            var canonical = System.Text.Json.Nodes.JsonNode.Parse(planJson.GetRawText())!;
            revision!["status"] = "Applied";
            canonical["revision_request"] = revision.DeepClone();
            trip.PlanJson = canonical.ToJsonString();
        }
        else trip.PlanJson = planJson.GetRawText();
        trip.RetryCount = retryCount;
        trip.Status = TripRequestStatus.AwaitingApproval;
        trip.FailureReason = null;
        var isRevision = existingItinerary is not null;
        var persistedLog = new AgentLog
        {
            TripRequestId = trip.Id,
            AgentName = "ASP.NET ProposalPersistence",
            StepName = "Persisted proposal awaiting human approval",
            Input = "Final validated AI proposal",
            Output = $"ItineraryId={itineraryEntity.Id}; BookingId={booking.Id}; BookingStatus={booking.Status}",
            Status = "Success",
            Timestamp = DateTime.UtcNow
        };
        _db.AgentLogs.Add(persistedLog);
        await _notifications.CreateEventNotificationAsync(
            trip.CustomerId,
            isRevision ? MessageType.TripRevisionReady : MessageType.TripPlanningReady,
            isRevision
                ? "Your revised itinerary is ready to review."
                : "Your itinerary is ready to review.",
            "TripRequest",
            trip.Id.ToString(),
            $"trip:{trip.Id}:{(isRevision ? "revision-ready" : "planning-ready")}:{itineraryEntity.Id}",
            cancellationToken);
        await _db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);

        _logStream?.PublishTripStatus(trip.Id, trip.Status.ToString(), trip.FailureReason);
        _logStream?.PublishAgentLog(new backend.DTOs.AgentLogDto
        {
            Id = persistedLog.Id,
            TripRequestId = persistedLog.TripRequestId,
            AgentName = persistedLog.AgentName,
            StepName = persistedLog.StepName,
            Input = persistedLog.Input,
            Output = persistedLog.Output,
            Status = persistedLog.Status,
            Timestamp = DateTimeContract.AsStoredUtc(persistedLog.Timestamp)
        });

        return new AgentProposalPersistenceResult
        {
            TripRequestId = trip.Id,
            ItineraryId = itineraryEntity.Id,
            BookingId = booking.Id,
            BookingReference = booking.BookingReference,
            BookingStatus = booking.Status.ToString(),
            AlreadyPersisted = false
        };
    }

    private async Task<List<ValidatedRoomStay>> ValidateRoomStaysAsync(
        JsonElement bookingDetails, TripRequest trip, string currency, CancellationToken cancellationToken, int? excludingBookingId = null)
    {
        var requested = new List<(int RoomId, DateTime CheckIn, DateTime CheckOut)>();
        var selections = OptionalArray(bookingDetails, "room_selections");
        if (selections.HasValue)
        {
            var next = trip.StartDate.Date;
            foreach (var value in selections.Value.EnumerateArray())
            {
                var stay = EnsureObject(value, "hotel stay");
                if (!DateTime.TryParse(OptionalString(stay, "check_in"), CultureInfo.InvariantCulture, DateTimeStyles.None, out var checkIn) ||
                    !DateTime.TryParse(OptionalString(stay, "check_out"), CultureInfo.InvariantCulture, DateTimeStyles.None, out var checkOut) ||
                    checkIn.Date != next || checkOut.Date <= checkIn.Date || checkOut.Date > trip.EndDate.Date)
                    throw new ProposalPersistenceException("INVALID_ROOM_STAYS", "Hotel stays must cover every trip night exactly once in date order.");
                requested.Add((RequiredInt(stay, "room_id"), checkIn.Date, checkOut.Date));
                next = checkOut.Date;
            }
            if (requested.Count == 0 || next != trip.EndDate.Date)
                throw new ProposalPersistenceException("INVALID_ROOM_STAYS", "Hotel stays must cover the complete trip.");
        }
        else
            requested.Add((RequiredInt(RequireObject(bookingDetails, "selected_room"), "room_id"), trip.StartDate, trip.EndDate));

        var result = new List<ValidatedRoomStay>();
        foreach (var stay in requested)
        {
            var room = await _db.Rooms.Include(r => r.Hotel).FirstOrDefaultAsync(r => r.Id == stay.RoomId, cancellationToken);
            if (room is null || room.Status != RoomStatus.Active || room.Hotel.Status != HotelStatus.Active)
                throw new ProposalPersistenceException("INVALID_ROOM", $"Room {stay.RoomId} is missing or inactive.");
            if (room.Capacity < trip.TravellerCount)
                throw new ProposalPersistenceException("ROOM_CAPACITY", $"Room {stay.RoomId} cannot hold all travellers.");
            var booked = await _db.BookingItems.Where(item => item.RoomId == stay.RoomId && item.ItemType == BookingItemType.Room &&
                (!excludingBookingId.HasValue || item.BookingId != excludingBookingId.Value) &&
                item.CheckInDate < stay.CheckOut && item.CheckOutDate > stay.CheckIn &&
                TransportInventory.ActiveReservationStatuses.Contains(item.Booking.Status)).SumAsync(item => item.Quantity, cancellationToken);
            if (booked >= room.TotalRooms)
                throw new ProposalPersistenceException("ROOM_UNAVAILABLE", $"Room {stay.RoomId} is not available for its planned stay dates.");
            var nightly = _currency.Convert(room.PricePerNight, room.Currency, currency);
            result.Add(new ValidatedRoomStay(room, stay.CheckIn, stay.CheckOut,
                decimal.Round(nightly * Math.Max(1, (stay.CheckOut.Date - stay.CheckIn.Date).Days), 2, MidpointRounding.AwayFromZero)));
        }
        return result;
    }

    private async Task<List<ValidatedTransportSelection>> ValidateTransportSelectionsAsync(
        JsonElement bookingDetails,
        IReadOnlyList<int> requestedDestinationIds,
        TripRequest trip,
        string currency,
        CancellationToken cancellationToken, int? excludingBookingId = null)
    {
        var requested = new List<(int? LegIndex, int TransportOptionId)>();
        if (requestedDestinationIds.Count > 1 || trip.AirportPickup)
        {
            var selections = OptionalArray(bookingDetails, "transport_selections");
            if (!selections.HasValue)
                throw new ProposalPersistenceException(
                    "INVALID_TRANSPORT_SELECTIONS",
                    "A multi-destination proposal must provide transport_selections for every adjacent leg.");

            foreach (var value in selections.Value.EnumerateArray())
            {
                var selection = EnsureObject(value, "transport selection");
                var legIndex = RequiredInt(selection, "leg_index", minimum: 0);
                var transportOptionId = OptionalInt(selection, "transport_option_id")
                    ?? OptionalInt(selection, "transport_id")
                    ?? throw new ProposalPersistenceException(
                        "INVALID_TRANSPORT_SELECTIONS",
                        "Every transport selection must contain transport_option_id.");
                requested.Add((legIndex, transportOptionId));
            }

            var expectedLegCount = requestedDestinationIds.Count - 1 + (trip.AirportPickup ? 1 : 0);
            var indexes = requested.Select(selection => selection.LegIndex).ToList();
            if (requested.Count != expectedLegCount ||
                indexes.Any(index => !index.HasValue || index < 0 || index >= expectedLegCount) ||
                indexes.Distinct().Count() != expectedLegCount)
            {
                throw new ProposalPersistenceException(
                    "TRANSPORT_LEG_COVERAGE_INCOMPLETE",
                    $"The proposal must contain exactly one transport selection for every leg index 0 through {expectedLegCount - 1}.");
            }
        }
        else
        {
            var selection = RequireObject(bookingDetails, "selected_transport");
            requested.Add((null, RequiredInt(selection, "transport_id")));
        }

        var validated = new List<ValidatedTransportSelection>();
        foreach (var selection in requested.OrderBy(item => item.LegIndex ?? int.MaxValue))
        {
            var transport = await _db.TransportOptions
                .FirstOrDefaultAsync(item => item.Id == selection.TransportOptionId, cancellationToken);
            if (transport is null || transport.Status != TransportStatus.Active)
                throw new ProposalPersistenceException(
                    "INVALID_TRANSPORT",
                    $"Transport {selection.TransportOptionId} is missing or inactive.");

            try
            {
                await TransportCompatibility.ValidateAsync(
                    _db,
                    transport,
                    trip,
                    cancellationToken,
                    selection.LegIndex,
                    requestedDestinationIds);
            }
            catch (TransportBusinessException ex)
            {
                throw new ProposalPersistenceException(ex.Code, ex.Message);
            }

            if (transport.Capacity < trip.TravellerCount)
                throw new ProposalPersistenceException(
                    "TRANSPORT_CAPACITY",
                    $"Transport {selection.TransportOptionId} cannot hold all travellers.");

            var bookedSeats = await TransportInventory.CountReservedSeatsAsync(
                _db,
                transport.Id,
                excludingBookingId,
                cancellationToken: cancellationToken);
            if (bookedSeats + trip.TravellerCount > transport.Capacity)
                throw new ProposalPersistenceException(
                    "TRANSPORT_UNAVAILABLE",
                    $"Transport {selection.TransportOptionId} has insufficient capacity.");

            var unitPrice = _currency.Convert(transport.Price, transport.Currency, currency);
            var total = decimal.Round(unitPrice * trip.TravellerCount, 2, MidpointRounding.AwayFromZero);
            validated.Add(new ValidatedTransportSelection(selection.LegIndex, transport, unitPrice, total));
        }

        return validated;
    }

    private async Task<string> GenerateBookingReferenceAsync(CancellationToken cancellationToken)
    {
        for (var attempt = 0; attempt < 10; attempt++)
        {
            var reference = $"ST-{DateTime.UtcNow:yyyyMMddHHmmss}-{Guid.NewGuid().ToString("N")[..8].ToUpperInvariant()}";
            if (!await _db.Bookings.AnyAsync(b => b.BookingReference == reference, cancellationToken))
                return reference;
        }
        throw new ProposalPersistenceException("REFERENCE_GENERATION_FAILED", "Could not generate a unique booking reference.");
    }

    private static JsonElement RequireObject(JsonElement parent, string name)
    {
        var value = RequiredProperty(parent, name);
        if (value.ValueKind != JsonValueKind.Object)
            throw new ProposalPersistenceException("INVALID_JSON", $"{name} must be an object.");
        return value;
    }

    private static JsonElement EnsureObject(JsonElement value, string name)
    {
        if (value.ValueKind != JsonValueKind.Object)
            throw new ProposalPersistenceException("INVALID_JSON", $"{name} must be an object.");
        return value;
    }

    private static JsonElement RequireArray(JsonElement parent, string name)
    {
        var value = RequiredProperty(parent, name);
        if (value.ValueKind != JsonValueKind.Array)
            throw new ProposalPersistenceException("INVALID_JSON", $"{name} must be an array.");
        return value;
    }

    private static JsonElement RequiredProperty(JsonElement parent, string name)
    {
        foreach (var property in parent.EnumerateObject())
            if (string.Equals(property.Name, name, StringComparison.OrdinalIgnoreCase))
                return property.Value;
        throw new ProposalPersistenceException("INVALID_JSON", $"Required proposal field '{name}' is missing.");
    }

    private static JsonElement? OptionalObject(JsonElement parent, string name)
    {
        foreach (var property in parent.EnumerateObject())
            if (string.Equals(property.Name, name, StringComparison.OrdinalIgnoreCase) && property.Value.ValueKind == JsonValueKind.Object)
                return property.Value;
        return null;
    }

    private static JsonElement? OptionalArray(JsonElement parent, string name)
    {
        foreach (var property in parent.EnumerateObject())
            if (string.Equals(property.Name, name, StringComparison.OrdinalIgnoreCase) && property.Value.ValueKind == JsonValueKind.Array)
                return property.Value;
        return null;
    }

    private static List<int> ParseRequestedDestinationIds(TripRequest trip)
    {
        if (!string.IsNullOrWhiteSpace(trip.DestinationSelectionsJson))
        {
            try
            {
                var selections = JsonSerializer.Deserialize<List<TripRequestDestinationSelection>>(
                    trip.DestinationSelectionsJson);
                if (selections is not null && selections.Count > 0)
                    return selections.OrderBy(selection => selection.Order).Select(selection => selection.Id).ToList();
            }
            catch (JsonException)
            {
                // Legacy rows fall back to the singular FK below.
            }
        }

        return trip.DestinationId.HasValue
            ? new List<int> { trip.DestinationId.Value }
            : new List<int>();
    }

    private static int? ParseStarterLocationId(TripRequest trip)
    {
        if (string.IsNullOrWhiteSpace(trip.DestinationSelectionsJson))
            return null;

        try
        {
            var selections = JsonSerializer.Deserialize<List<TripRequestDestinationSelection>>(
                trip.DestinationSelectionsJson);
            var starters = selections?
                .Where(selection => selection.IsStarter)
                .Select(selection => selection.Id)
                .ToList() ?? new List<int>();
            if (starters.Count > 1)
                throw new ProposalPersistenceException(
                    "INVALID_STARTER_LOCATION",
                    "A trip request cannot contain more than one selected starter location.");
            return starters.Count == 1 ? starters[0] : null;
        }
        catch (JsonException)
        {
            return null;
        }
    }

    private static void ValidateProposalDestinationContract(JsonElement root, IReadOnlyCollection<int> requestedDestinationIds)
    {
        if (requestedDestinationIds.Count <= 1) return;

        var supplied = OptionalArray(root, "requested_destinations");
        if (!supplied.HasValue) return;

        var suppliedIds = supplied.Value
            .EnumerateArray()
            .Select(item => item.ValueKind == JsonValueKind.Object
                ? OptionalInt(item, "destination_id") ?? OptionalInt(item, "id")
                : null)
            .Where(id => id.HasValue)
            .Select(id => id!.Value)
            .ToList();

        if (suppliedIds.Count != requestedDestinationIds.Count
            || suppliedIds.Distinct().Count() != requestedDestinationIds.Count
            || !suppliedIds.SequenceEqual(requestedDestinationIds))
            throw new ProposalPersistenceException(
                "DESTINATION_CONTRACT_MISMATCH",
                "The proposal destination list must preserve every selected destination and its submitted selection order.");
    }

    private static bool IsValidRoutePermutation(
        IReadOnlyList<int> plannedDestinationIds,
        IReadOnlyList<int> requestedDestinationIds,
        int? starterLocationId,
        bool airportPickup)
    {
        if (plannedDestinationIds.Count != requestedDestinationIds.Count || requestedDestinationIds.Count == 0)
            return false;

        if (plannedDestinationIds.Distinct().Count() != requestedDestinationIds.Count
            || !plannedDestinationIds.OrderBy(id => id).SequenceEqual(requestedDestinationIds.OrderBy(id => id)))
            return false;

        return !starterLocationId.HasValue || plannedDestinationIds[0] == starterLocationId.Value;
    }

    private static string? OptionalString(JsonElement parent, string name)
    {
        foreach (var property in parent.EnumerateObject())
            if (string.Equals(property.Name, name, StringComparison.OrdinalIgnoreCase) && property.Value.ValueKind == JsonValueKind.String)
                return property.Value.GetString();
        return null;
    }

    private static bool? OptionalBool(JsonElement parent, string name)
    {
        foreach (var property in parent.EnumerateObject())
            if (string.Equals(property.Name, name, StringComparison.OrdinalIgnoreCase) && (property.Value.ValueKind == JsonValueKind.True || property.Value.ValueKind == JsonValueKind.False))
                return property.Value.GetBoolean();
        return null;
    }

    private static int? OptionalInt(JsonElement parent, string name)
    {
        foreach (var property in parent.EnumerateObject())
            if (string.Equals(property.Name, name, StringComparison.OrdinalIgnoreCase) && property.Value.TryGetInt32(out var value))
                return value;
        return null;
    }

    private static decimal? OptionalDecimal(JsonElement parent, string name)
    {
        foreach (var property in parent.EnumerateObject())
            if (string.Equals(property.Name, name, StringComparison.OrdinalIgnoreCase) && property.Value.TryGetDecimal(out var value))
                return value;
        return null;
    }

    private static int RequiredInt(JsonElement parent, string name, int minimum = 1)
    {
        var value = OptionalInt(parent, name);
        if (!value.HasValue || value.Value < minimum)
            throw new ProposalPersistenceException("INVALID_REFERENCE", $"{name} must be a positive integer.");
        return value.Value;
    }

    private static TimeSpan RequiredTime(JsonElement parent, string name)
    {
        var value = OptionalString(parent, name);
        if (!TimeSpan.TryParse(value, CultureInfo.InvariantCulture, out var parsed))
            throw new ProposalPersistenceException("INVALID_TIME", $"{name} is invalid.");
        return parsed;
    }

    private void RequireSameCurrency(string expected, string? actual, string field)
    {
        var normalized = _currency.Normalize(actual, field);
        if (!string.Equals(expected, normalized, StringComparison.OrdinalIgnoreCase))
            throw new ProposalPersistenceException("CURRENCY_MISMATCH", $"{field} currency does not match {expected}.");
    }
}

public sealed class ProposalPersistenceException : InvalidOperationException
{
    public string Code { get; }

    public ProposalPersistenceException(string code, string message) : base(message)
    {
        Code = code;
    }
}
