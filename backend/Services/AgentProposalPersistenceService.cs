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

        var existingItinerary = await _db.Itineraries
            .OrderByDescending(i => i.CreatedAt)
            .FirstOrDefaultAsync(i => i.TripRequestId == tripRequestId, cancellationToken);
        if (existingItinerary is not null)
        {
            var existingBooking = await _db.Bookings
                .FirstOrDefaultAsync(b => b.ItineraryId == existingItinerary.Id, cancellationToken);
            if (existingBooking is null)
                throw new ProposalPersistenceException("PARTIAL_PROPOSAL", "A prior itinerary exists without its booking.");

            if (existingBooking.Status is not (BookingStatus.Cancelled or BookingStatus.Rejected))
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
        var currency = _currency.Normalize(trip.Currency, "TripRequest currency");
        var schedule = RequireArray(itinerary, "schedule");
        var tripDays = (trip.EndDate.Date - trip.StartDate.Date).Days + 1;
        var itineraryItems = new List<ItineraryItem>();
        var scheduledDestinationIds = new HashSet<int>();
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

        var nights = Math.Max(1, (trip.EndDate.Date - trip.StartDate.Date).Days);
        var room = RequireObject(bookingDetails, "selected_room");
        var roomId = RequiredInt(room, "room_id");
        var roomEntity = await _db.Rooms.Include(r => r.Hotel).FirstOrDefaultAsync(r => r.Id == roomId, cancellationToken);
        if (roomEntity is null || roomEntity.Status != RoomStatus.Active || roomEntity.Hotel.Status != HotelStatus.Active)
            throw new ProposalPersistenceException("INVALID_ROOM", $"Room {roomId} is missing or inactive.");
        if (roomEntity.Capacity < trip.TravellerCount)
            throw new ProposalPersistenceException("ROOM_CAPACITY", $"Room {roomId} cannot hold all travellers.");

        var activeStatuses = new[] { BookingStatus.Draft, BookingStatus.AwaitingApproval, BookingStatus.Confirmed };
        var bookedRooms = await _db.BookingItems
            .Where(item => item.RoomId == roomId && item.ItemType == BookingItemType.Room &&
                item.CheckInDate < trip.EndDate && item.CheckOutDate > trip.StartDate &&
                activeStatuses.Contains(item.Booking.Status))
            .SumAsync(item => item.Quantity, cancellationToken);
        if (bookedRooms >= roomEntity.TotalRooms)
            throw new ProposalPersistenceException("ROOM_UNAVAILABLE", $"Room {roomId} is not available for the requested dates.");

        var transport = RequireObject(bookingDetails, "selected_transport");
        var transportId = RequiredInt(transport, "transport_id");
        var transportEntity = await _db.TransportOptions.FirstOrDefaultAsync(t => t.Id == transportId, cancellationToken);
        if (transportEntity is null || transportEntity.Status != TransportStatus.Active)
            throw new ProposalPersistenceException("INVALID_TRANSPORT", $"Transport {transportId} is missing or inactive.");
        if (transportEntity.Capacity < trip.TravellerCount)
            throw new ProposalPersistenceException("TRANSPORT_CAPACITY", $"Transport {transportId} cannot hold all travellers.");
        var bookedSeats = await _db.BookingItems
            .Where(item => item.TransportOptionId == transportId && item.ItemType == BookingItemType.Transport &&
                activeStatuses.Contains(item.Booking.Status))
            .SumAsync(item => item.Quantity, cancellationToken);
        if (bookedSeats + trip.TravellerCount > transportEntity.Capacity)
            throw new ProposalPersistenceException("TRANSPORT_UNAVAILABLE", $"Transport {transportId} has insufficient capacity.");

        var roomNightlyPrice = _currency.Convert(roomEntity.PricePerNight, roomEntity.Currency, currency);
        var transportUnitPrice = _currency.Convert(transportEntity.Price, transportEntity.Currency, currency);
        var roomTotal = decimal.Round(roomNightlyPrice * nights, 2, MidpointRounding.AwayFromZero);
        var transportTotal = decimal.Round(transportUnitPrice * trip.TravellerCount, 2, MidpointRounding.AwayFromZero);
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
                }).Concat(new[]
                {
                    new BookingItem
                    {
                    ItemType = BookingItemType.Room,
                    RoomId = roomEntity.Id,
                    CheckInDate = trip.StartDate,
                    CheckOutDate = trip.EndDate,
                    Quantity = 1,
                    UnitPrice = roomTotal,
                    Subtotal = roomTotal,
                    Currency = currency
                    },
                    new BookingItem
                    {
                    ItemType = BookingItemType.Transport,
                    TransportOptionId = transportEntity.Id,
                    Quantity = trip.TravellerCount,
                    UnitPrice = transportUnitPrice,
                    Subtotal = transportTotal,
                    Currency = currency
                    }
                }).ToList()
        };
        _db.Bookings.Add(booking);
        trip.PlanJson = planJson.GetRawText();
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
            Timestamp = persistedLog.Timestamp
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

        if (!requestedDestinationIds.OrderBy(id => id).SequenceEqual(suppliedIds.Distinct().OrderBy(id => id)))
            throw new ProposalPersistenceException(
                "DESTINATION_CONTRACT_MISMATCH",
                "The proposal destination list does not match the TripRequest destination list.");
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
