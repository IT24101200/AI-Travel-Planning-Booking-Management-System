using System.Data;
using backend.Data;
using backend.DTOs;
using backend.Models;
using backend.Models.Enums;
using Microsoft.EntityFrameworkCore;

namespace backend.Services
{
    public class BookingService : IBookingService
    {
        private readonly AppDbContext _db;
        private readonly ICurrencyConversionService _currency;
        private readonly INotificationService _notifications;
        // True when running against PostgreSQL (production). False for SQLite/InMemory (tests).
        private bool IsPostgres => _db.Database.ProviderName?.Contains("Npgsql") == true;

        public BookingService(
            AppDbContext db,
            ICurrencyConversionService? currency = null,
            INotificationService? notifications = null)
        {
            _db = db;
            _currency = currency ?? new CurrencyConversionService();
            _notifications = notifications ?? new NotificationService(db);
        }

        public async Task<BookingDto> CreateBookingAsync(BookingCreateDto dto)
        {
            if (dto == null)
                throw new ArgumentNullException(nameof(dto));

            var customer = await _db.Customers.FindAsync(dto.CustomerId);
            if (customer == null)
                throw new KeyNotFoundException($"Customer with ID '{dto.CustomerId}' not found.");

            var itinerary = await _db.Itineraries
                .Include(item => item.TripRequest)
                .FirstOrDefaultAsync(item => item.Id == dto.ItineraryId);
            if (itinerary == null)
                throw new KeyNotFoundException($"Itinerary with ID {dto.ItineraryId} not found.");

            var authoritativeCurrency = _currency.Normalize(itinerary.Currency, "Itinerary currency");
            if (!string.IsNullOrWhiteSpace(dto.Currency) &&
                !_currency.IsSupported(dto.Currency) ||
                !string.IsNullOrWhiteSpace(dto.Currency) &&
                !string.Equals(_currency.Normalize(dto.Currency), authoritativeCurrency, StringComparison.OrdinalIgnoreCase))
            {
                throw new ArgumentException("Booking currency must match the itinerary currency.");
            }

            if (dto.Items == null || !dto.Items.Any())
                throw new ArgumentException("Booking must contain at least one item.");

            // Client UnitPrice and TotalCost are retained on the wire for
            // compatibility only. Commercial values are resolved from the
            // referenced catalogue entities by one centralized routine.
            var pricing = await BuildAuthoritativeBookingItemsAsync(
                dto.Items,
                authoritativeCurrency,
                itinerary.TripRequest);
            var bookingItems = pricing.Items;
            var calculatedTotal = pricing.Total;
            var totalCost = calculatedTotal;
            var bookingRef = await GenerateUniqueBookingReferenceAsync();

            // Proposals check confirmed room occupancy but do not reserve stock.
            // Confirmation rechecks rooms in a serializable transaction. Transport
            // retains its existing reservation policy and row locks.
            await using var transaction = await _db.Database
                .BeginTransactionAsync(IsolationLevel.RepeatableRead);
            try
            {
                foreach (var item in dto.Items.Where(i => i.ItemType == BookingItemType.Room))
                {
                    Room? lockedRoom;
                    if (IsPostgres)
                    {
                        // PostgreSQL: acquire an advisory row-level lock so concurrent
                        // transactions serialise on this row.  The second waiter will
                        // block until we COMMIT/ROLLBACK, then re-count and find 0 left.
                        lockedRoom = await _db.Rooms
                            .FromSqlRaw(
                                "SELECT * FROM \"Rooms\" WHERE \"Id\" = {0} FOR UPDATE",
                                item.RoomId!.Value)
                            .AsNoTracking()
                            .FirstOrDefaultAsync();
                    }
                    else
                    {
                        // SQLite / InMemory (tests): no FOR UPDATE syntax, but the
                        // serializable transaction + capacity re-check below still
                        // catches the second concurrent writer correctly.
                        lockedRoom = await _db.Rooms
                            .AsNoTracking()
                            .FirstOrDefaultAsync(r => r.Id == item.RoomId!.Value);
                    }

                    if (lockedRoom is null)
                        throw new KeyNotFoundException(
                            $"Room with ID {item.RoomId} not found.");

                    if (lockedRoom.Status != RoomStatus.Active ||
                        !await _db.Hotels.AnyAsync(h => h.Id == lockedRoom.HotelId && h.Status == HotelStatus.Active))
                        throw new InvalidOperationException("This hotel is no longer accepting new bookings.");

                    // Check peak confirmed occupancy for the requested dates.
                    // this read is now serialised with any concurrent writer.
                    var bookedCount = await RoomInventory.BookedPeakAsync(
                        _db, lockedRoom.Id, item.CheckInDate!.Value, item.CheckOutDate!.Value);

                    var available = lockedRoom.TotalRooms - bookedCount;
                    if (available < item.Quantity)
                        throw new InvalidOperationException(
                            $"Room '{lockedRoom.RoomType}' (ID {lockedRoom.Id}) is no longer " +
                            $"available for the requested dates " +
                            $"({item.CheckInDate:yyyy-MM-dd} \u2013 {item.CheckOutDate:yyyy-MM-dd}). " +
                            $"Requested: {item.Quantity}, available: {Math.Max(0, available)}.");
                }

                // ── Transport capacity lock (same pattern as Room above) ──
                // Acquire a PostgreSQL row-level lock on the TransportOption row
                // so that two concurrent requests for the last available seat
                // are serialised: the second waits for the first to commit,
                // then re-counts and finds zero seats remaining.
                foreach (var transportGroup in dto.Items
                             .Where(i => i.ItemType == BookingItemType.Transport)
                             .Where(i => i.TransportOptionId.HasValue)
                             .GroupBy(i => i.TransportOptionId!.Value)
                             .OrderBy(group => group.Key))
                {
                    var transportOptionId = transportGroup.Key;
                    var requestedQuantity = transportGroup.Sum(item => item.Quantity);
                    TransportOption? lockedTransport;
                    if (IsPostgres)
                    {
                        lockedTransport = await _db.TransportOptions
                            .FromSqlRaw(
                                "SELECT * FROM \"TransportOptions\" WHERE \"Id\" = {0} FOR UPDATE",
                                transportOptionId)
                            .AsNoTracking()
                            .FirstOrDefaultAsync();
                    }
                    else
                    {
                        lockedTransport = await _db.TransportOptions
                            .AsNoTracking()
                            .FirstOrDefaultAsync(t => t.Id == transportOptionId);
                    }

                    if (lockedTransport is null)
                        throw new KeyNotFoundException(
                            $"TransportOption with ID {transportOptionId} not found.");

                    if (lockedTransport.Status != TransportStatus.Active)
                        throw new TransportBusinessException(
                            "TRANSPORT_INACTIVE",
                            "The selected transport option is no longer active.");

                    // Re-count active bookings for this transport option under the lock.
                    var bookedSeats = await TransportInventory.CountReservedSeatsAsync(
                        _db,
                        transportOptionId);

                    var availableSeats = lockedTransport.Capacity - bookedSeats;
                    if (availableSeats < requestedQuantity)
                        throw new InvalidOperationException(
                            $"TransportOption '{lockedTransport.Provider}: " +
                            $"{lockedTransport.RouteFrom} \u2192 {lockedTransport.RouteTo}' " +
                            $"(ID {lockedTransport.Id}) has insufficient capacity. " +
                            $"Requested: {requestedQuantity}, available: {Math.Max(0, availableSeats)}.");
                }

                // Rule 1: Always created in AwaitingApproval (or Draft if explicitly specified, never Confirmed)
                var booking = new Booking
                {
                    BookingReference = bookingRef,
                    CustomerId       = dto.CustomerId,
                    ItineraryId      = dto.ItineraryId,
                    Status           = BookingStatus.AwaitingApproval,
                    TotalCost        = totalCost,
                    Currency         = authoritativeCurrency,
                    ExchangeRateToLkr = _currency.ExchangeRateToLkr(authoritativeCurrency),
                    CreatedAt        = DateTime.UtcNow,
                    UpdatedAt        = DateTime.UtcNow,
                    BookingItems     = bookingItems
                };

                _db.Bookings.Add(booking);
                await _db.SaveChangesAsync();
                await transaction.CommitAsync();

                return await MapToDtoAsync(booking);
            }
            catch
            {
                await transaction.RollbackAsync();
                throw; // Re-throw so the controller's existing catch blocks produce the correct 400/404
            }
        }

        public async Task<BookingDto?> GetBookingByIdAsync(int id, string? userId = null, bool isStaff = false)
        {
            var booking = await GetBookingEntityQueryable()
                .FirstOrDefaultAsync(b => b.Id == id);

            if (booking == null)
                return null;

            // IDOR Protection: Customers can only view their own bookings
            if (!string.IsNullOrEmpty(userId) && !isStaff && booking.CustomerId != userId)
            {
                throw new UnauthorizedAccessException("You are not authorized to view this booking.");
            }

            return await MapToDtoAsync(booking);
        }

        public async Task<IEnumerable<BookingDto>> GetBookingsAsync(string? customerId = null, BookingStatus? status = null)
        {
            var query = GetBookingEntityQueryable();

            if (!string.IsNullOrEmpty(customerId))
            {
                query = query.Where(b => b.CustomerId == customerId);
            }

            if (status.HasValue)
            {
                query = query.Where(b => b.Status == status.Value);
            }

            var list = await query.OrderByDescending(b => b.CreatedAt).ToListAsync();
            var dtos = new List<BookingDto>();
            foreach (var b in list)
            {
                dtos.Add(await MapToDtoAsync(b));
            }
            return dtos;
        }

        public async Task<BookingDto> UpdateBookingStatusAsync(int id, BookingStatus newStatus)
        {
            await using var transaction = await _db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
            var booking = await GetBookingEntityQueryable().FirstOrDefaultAsync(b => b.Id == id);
            if (booking == null)
                throw new KeyNotFoundException($"Booking with ID {id} not found.");

            // Rule 1: Enforce valid status transition logic
            ValidateStatusTransition(booking.Status, newStatus);

            if (newStatus == BookingStatus.Confirmed)
            {
                await RoomInventory.ValidateConfirmationAsync(_db, booking.Id);
                await TransportInventory.ValidateConfirmationAsync(_db, booking.Id);
            }

            var statusChanged = booking.Status != newStatus;
            booking.Status = newStatus;
            booking.UpdatedAt = DateTime.UtcNow;

            if (statusChanged)
            {
                var automaticEvent = newStatus switch
                {
                    BookingStatus.Confirmed => (
                        MessageType.BookingConfirmed,
                        "Your booking has been confirmed.",
                        $"booking:{booking.Id}:confirmed"),
                    BookingStatus.Rejected => (
                        MessageType.BookingRejected,
                        "Your booking was not approved.",
                        $"booking:{booking.Id}:rejected"),
                    BookingStatus.Cancelled => (
                        MessageType.BookingCancelled,
                        "Your booking has been cancelled.",
                        $"booking:{booking.Id}:cancelled"),
                    _ => ((MessageType Type, string Content, string EventKey)?)null
                };
                if (automaticEvent.HasValue)
                {
                    await _notifications.CreateEventNotificationAsync(
                        booking.CustomerId,
                        automaticEvent.Value.Type,
                        automaticEvent.Value.Content,
                        "Booking",
                        booking.Id.ToString(),
                        automaticEvent.Value.EventKey);
                }
            }

            await _db.SaveChangesAsync();
            await transaction.CommitAsync();
            return await MapToDtoAsync(booking);
        }

        public async Task<IEnumerable<BookingDto>> GetPendingBookingsForApprovalAsync()
        {
            return await GetBookingsAsync(status: BookingStatus.AwaitingApproval);
        }

        public async Task<bool> DeleteBookingAsync(int id)
        {
            var booking = await _db.Bookings.FindAsync(id);
            if (booking == null)
                return false;

            _db.Bookings.Remove(booking);
            await _db.SaveChangesAsync();
            return true;
        }

        // ── Helper Methods ──

        private IQueryable<Booking> GetBookingEntityQueryable()
        {
            return _db.Bookings
                .Include(b => b.Customer)
                .Include(b => b.Itinerary)
                    .ThenInclude(i => i.TripRequest)
                        .ThenInclude(t => t.Destination)
                .Include(b => b.Itinerary)
                    .ThenInclude(i => i.ItineraryItems)
                        .ThenInclude(i => i.Tour)
                .Include(b => b.BookingItems)
                    .ThenInclude(bi => bi.Tour)
                .Include(b => b.BookingItems)
                    .ThenInclude(bi => bi.Room)
                        .ThenInclude(r => r!.Hotel)
                .Include(b => b.BookingItems)
                    .ThenInclude(bi => bi.TransportOption)
                .Include(b => b.BookingApprovals)
                    .ThenInclude(ba => ba.TravelAgent)
                .Include(b => b.Payments);
        }

        private async Task<(List<BookingItem> Items, decimal Total)> BuildAuthoritativeBookingItemsAsync(
            IEnumerable<BookingItemCreateDto> requestedItems,
            string bookingCurrency,
            TripRequest trip)
        {
            var requestedItemList = requestedItems.ToList();
            ValidateTransportLegContract(requestedItemList, trip);
            var bookingItems = new List<BookingItem>();
            decimal calculatedTotal = 0m;

            foreach (var item in requestedItemList)
            {
                if (item.Quantity <= 0)
                    throw new ArgumentException("Booking item quantity must be positive.");

                var foreignKeyCount = (item.TourId.HasValue ? 1 : 0) +
                                      (item.RoomId.HasValue ? 1 : 0) +
                                      (item.TransportOptionId.HasValue ? 1 : 0);
                if (foreignKeyCount != 1)
                    throw new ArgumentException("BookingItem must have exactly one of TourId, RoomId, or TransportOptionId set.");

                decimal authoritativeUnitPrice;
                decimal subtotal;
                var bookingItem = new BookingItem
                {
                    ItemType = item.ItemType,
                    TourId = item.TourId,
                    RoomId = item.RoomId,
                    TransportOptionId = item.TransportOptionId,
                    TransportLegIndex = item.TransportLegIndex,
                    CheckInDate = item.CheckInDate,
                    CheckOutDate = item.CheckOutDate,
                    Quantity = item.Quantity,
                    Currency = bookingCurrency
                };

                switch (item.ItemType)
                {
                    case BookingItemType.Tour:
                    {
                        if (!item.TourId.HasValue)
                            throw new ArgumentException("Tour booking items require a TourId.");

                        var tour = await _db.Tours.AsNoTracking()
                            .FirstOrDefaultAsync(t => t.Id == item.TourId.Value);
                        if (tour is null || !string.Equals(tour.Status, "Active", StringComparison.OrdinalIgnoreCase))
                            throw new InvalidOperationException("The selected tour is no longer available.");

                        authoritativeUnitPrice = _currency.Convert(
                            tour.Price, tour.Currency, bookingCurrency);
                        subtotal = decimal.Round(
                            authoritativeUnitPrice * item.Quantity, 2, MidpointRounding.AwayFromZero);
                        break;
                    }
                    case BookingItemType.Room:
                    {
                        if (!item.RoomId.HasValue || !item.CheckInDate.HasValue || !item.CheckOutDate.HasValue)
                            throw new ArgumentException("Room booking items require RoomId, check-in, and check-out dates.");
                        if (item.CheckOutDate <= item.CheckInDate)
                            throw new ArgumentException("Check-out must be after check-in.");

                        var room = await _db.Rooms
                            .Include(r => r.Hotel)
                            .AsNoTracking()
                            .FirstOrDefaultAsync(r => r.Id == item.RoomId.Value);
                        if (room is null || room.Status != RoomStatus.Active || room.Hotel.Status != HotelStatus.Active)
                            throw new InvalidOperationException("The selected room is no longer available.");

                        authoritativeUnitPrice = _currency.Convert(
                            room.PricePerNight, room.Currency, bookingCurrency);
                        var nights = Math.Max(1, (item.CheckOutDate.Value.Date - item.CheckInDate.Value.Date).Days);
                        subtotal = decimal.Round(
                            authoritativeUnitPrice * nights * item.Quantity,
                            2,
                            MidpointRounding.AwayFromZero);
                        break;
                    }
                    case BookingItemType.Transport:
                    {
                        if (!item.TransportOptionId.HasValue)
                            throw new ArgumentException("Transport booking items require TransportOptionId.");

                        var transport = await _db.TransportOptions.AsNoTracking()
                            .FirstOrDefaultAsync(t => t.Id == item.TransportOptionId.Value);
                        if (transport is null || transport.Status != TransportStatus.Active)
                            throw new InvalidOperationException("The selected transport option is no longer available.");

                        await TransportCompatibility.ValidateAsync(
                            _db,
                            transport,
                            trip,
                            transportLegIndex: item.TransportLegIndex);
                        bookingItem.TransportTypeSnapshot = transport.Type.ToString();
                        bookingItem.TransportProviderSnapshot = transport.Provider;
                        bookingItem.TransportRouteFromSnapshot = transport.RouteFrom;
                        bookingItem.TransportRouteToSnapshot = transport.RouteTo;
                        bookingItem.TransportDepartureTimeSnapshot = transport.DepartureTime;
                        bookingItem.TransportArrivalTimeSnapshot = transport.ArrivalTime;

                        authoritativeUnitPrice = _currency.Convert(
                            transport.Price, transport.Currency, bookingCurrency);
                        subtotal = decimal.Round(
                            authoritativeUnitPrice * item.Quantity, 2, MidpointRounding.AwayFromZero);
                        break;
                    }
                    default:
                        throw new ArgumentException("Unsupported booking item type.");
                }

                // UnitPrice is the authoritative per-unit/per-night catalogue
                // amount. Room subtotal additionally includes stay nights.
                bookingItem.UnitPrice = authoritativeUnitPrice;
                bookingItem.Subtotal = subtotal;
                bookingItems.Add(bookingItem);
                calculatedTotal += subtotal;
            }

            return (bookingItems, decimal.Round(calculatedTotal, 2, MidpointRounding.AwayFromZero));
        }

        private static void ValidateTransportLegContract(
            IReadOnlyCollection<BookingItemCreateDto> requestedItems,
            TripRequest trip)
        {
            var transportItems = requestedItems
                .Where(item => item.ItemType == BookingItemType.Transport)
                .ToList();
            var destinationIds = TransportCompatibility.ResolveDestinationIds(trip);
            var expectedLegCount = Math.Max(0, destinationIds.Count - 1);

            if (requestedItems.Any(item => item.ItemType != BookingItemType.Transport && item.TransportLegIndex.HasValue))
                throw new ArgumentException("TransportLegIndex is only valid for transport booking items.");

            if (expectedLegCount == 0)
            {
                if (transportItems.Any(item => item.TransportLegIndex.HasValue))
                    throw new ArgumentException("A single-destination transport item must not have a leg index.");
                return;
            }

            if (transportItems.Count != expectedLegCount)
                throw new ArgumentException(
                    $"A trip with {destinationIds.Count} destinations requires exactly {expectedLegCount} transport booking items.");

            var indexes = transportItems.Select(item => item.TransportLegIndex).ToList();
            if (indexes.Any(index => !index.HasValue || index < 0 || index >= expectedLegCount) ||
                indexes.Distinct().Count() != expectedLegCount)
            {
                throw new ArgumentException(
                    $"Transport leg indexes must be unique and continuous from 0 through {expectedLegCount - 1}.");
            }
        }

        private void ValidateStatusTransition(BookingStatus current, BookingStatus target)
        {
            if (current == target)
                return;

            // Rule 1: No skipping AwaitingApproval
            bool isValid = (current, target) switch
            {
                (BookingStatus.Draft, BookingStatus.AwaitingApproval) => true,
                (BookingStatus.Draft, BookingStatus.Cancelled) => true,
                (BookingStatus.AwaitingApproval, BookingStatus.Confirmed) => true,
                (BookingStatus.AwaitingApproval, BookingStatus.Rejected) => true,
                (BookingStatus.AwaitingApproval, BookingStatus.Cancelled) => true,
                (BookingStatus.Confirmed, BookingStatus.Completed) => true,
                (BookingStatus.Confirmed, BookingStatus.Cancelled) => true,
                _ => false
            };

            if (!isValid)
            {
                throw new InvalidOperationException($"Invalid booking status transition from '{current}' to '{target}'. Status cannot skip 'AwaitingApproval'.");
            }
        }

        private async Task<string> GenerateUniqueBookingReferenceAsync()
        {
            string reference;
            do
            {
                var randomPart = Guid.NewGuid().ToString("N").Substring(0, 6).ToUpper();
                reference = $"TRV-{DateTime.UtcNow:yyyyMMdd}-{randomPart}";
            }
            while (await _db.Bookings.AnyAsync(b => b.BookingReference == reference));

            return reference;
        }

        private async Task<BookingDto> MapToDtoAsync(Booking b)
        {
            // Fetch AgentLogs if itinerary is present
            var agentLogs = new List<AgentLogDto>();
            if (b.Itinerary != null)
            {
                var logs = await _db.AgentLogs
                    .Where(al => al.TripRequestId == b.Itinerary.TripRequestId)
                    .OrderBy(al => al.Timestamp)
                    .ToListAsync();

                agentLogs = logs.Select(al => new AgentLogDto
                {
                    Id = al.Id,
                    TripRequestId = al.TripRequestId,
                    AgentName = al.AgentName,
                    StepName = al.StepName,
                    Input = al.Input,
                    Output = al.Output,
                    Status = al.Status,
                    // Historical AgentLogs have mixed timestamp provenance;
                    // preserve the raw value until a safe data migration exists.
                    Timestamp = al.Timestamp
                }).ToList();
            }

            return new BookingDto
            {
                Id = b.Id,
                BookingReference = b.BookingReference,
                CustomerId = b.CustomerId,
                CustomerName = b.Customer?.FullName ?? string.Empty,
                ItineraryId = b.ItineraryId,
                TripRequestId = b.Itinerary?.TripRequestId ?? 0,
                TravellerCount = b.Itinerary?.TripRequest?.TravellerCount,
                DestinationName = b.Itinerary?.TripRequest?.Destination?.Name,
                RequestText = b.Itinerary?.TripRequest?.RawRequestText,
                StartDate = b.Itinerary?.StartDate,
                EndDate = b.Itinerary?.EndDate,
                Itinerary = b.Itinerary == null ? null : new ItineraryDto
                {
                    Id = b.Itinerary.Id,
                    CustomerId = b.CustomerId,
                    CustomerName = b.Customer?.FullName,
                    TripRequestId = b.Itinerary.TripRequestId,
                    TravellerCount = b.Itinerary.TripRequest?.TravellerCount,
                    StartDate = b.Itinerary.StartDate,
                    EndDate = b.Itinerary.EndDate,
                    Status = b.Itinerary.Status,
                    TotalEstimatedCost = b.Itinerary.TotalEstimatedCost,
                    Currency = b.Itinerary.Currency,
                    ExchangeRateToLkr = b.Itinerary.ExchangeRateToLkr,
                    CreatedAt = DateTimeContract.AsStoredUtc(b.Itinerary.CreatedAt),
                    Items = b.Itinerary.ItineraryItems.OrderBy(i => i.DayNumber).ThenBy(i => i.SequenceOrder)
                        .Select(i => new ItineraryItemDto
                        {
                            Id = i.Id, TourId = i.TourId, TourName = i.Tour?.Name ?? "Tour",
                            DayNumber = i.DayNumber, SequenceOrder = i.SequenceOrder,
                            StartTime = i.StartTime, EndTime = i.EndTime,
                            PriceAtSelection = i.PriceAtSelection, Currency = i.Currency
                        }).ToList()
                },
                Status = b.Status,
                TotalCost = b.TotalCost,
                Currency = b.Currency,
                ExchangeRateToLkr = b.ExchangeRateToLkr,
                CreatedAt = DateTimeContract.AsStoredUtc(b.CreatedAt),
                UpdatedAt = DateTimeContract.AsStoredUtc(b.UpdatedAt),
                BookingItems = b.BookingItems
                    .Where(bi => bi.ItemType != BookingItemType.Transport)
                    .Concat(b.BookingItems
                        .Where(bi => bi.ItemType == BookingItemType.Transport)
                        .OrderBy(bi => bi.TransportLegIndex ?? int.MaxValue)
                        .ThenBy(bi => bi.Id))
                    .Select(bi => new BookingItemDto
                {
                    Id = bi.Id,
                    BookingId = bi.BookingId,
                    ItemType = bi.ItemType,
                    TourId = bi.TourId,
                    TourName = bi.Tour?.Name,
                    RoomId = bi.RoomId,
                    TransportOptionId = bi.TransportOptionId,
                    TransportLegIndex = bi.TransportLegIndex,
                    HotelId = bi.Room?.HotelId,
                    HotelName = bi.Room?.Hotel?.Name,
                    HotelAddress = bi.Room?.Hotel?.Address,
                    HotelLatitude = bi.Room?.Hotel?.Latitude,
                    HotelLongitude = bi.Room?.Hotel?.Longitude,
                    RoomType = bi.Room?.RoomType,
                    RoomCapacity = bi.Room?.Capacity,
                    RateNotes = bi.Room?.RateNotes,
                    TransportType = bi.TransportTypeSnapshot ?? bi.TransportOption?.Type.ToString(),
                    TransportProvider = bi.TransportProviderSnapshot ?? bi.TransportOption?.Provider,
                    RouteFrom = bi.TransportRouteFromSnapshot ?? bi.TransportOption?.RouteFrom,
                    RouteTo = bi.TransportRouteToSnapshot ?? bi.TransportOption?.RouteTo,
                    DepartureTime = bi.TransportDepartureTimeSnapshot ?? bi.TransportOption?.DepartureTime,
                    ArrivalTime = bi.TransportArrivalTimeSnapshot ?? bi.TransportOption?.ArrivalTime,
                    CheckInDate = bi.CheckInDate,
                    CheckOutDate = bi.CheckOutDate,
                    Quantity = bi.Quantity,
                    UnitPrice = bi.UnitPrice,
                    Subtotal = bi.Subtotal,
                    Currency = bi.Currency
                }).ToList(),
                BookingApprovals = b.BookingApprovals.Select(ba => new ApprovalDto
                {
                    Id = ba.Id,
                    BookingId = ba.BookingId,
                    TravelAgentId = ba.TravelAgentId,
                    TravelAgentName = ba.TravelAgent?.FullName ?? string.Empty,
                    Decision = ba.Decision,
                    Comment = ba.Comment,
                    DecidedAt = DateTimeContract.AsStoredUtc(ba.DecidedAt)
                }).ToList(),
                Payments = b.Payments.Select(p => new PaymentDto
                {
                    Id = p.Id,
                    BookingId = p.BookingId,
                    BookingReference = b.BookingReference,
                    CustomerName = b.Customer?.FullName ?? string.Empty,
                    Amount = p.Amount,
                    Currency = p.Currency,
                    Status = p.Status,
                    StripeReference = p.StripeReference,
                    FailureReason = p.FailureReason,
                    ExchangeRateToLkr = p.ExchangeRateToLkr,
                    PaymentDate = DateTimeContract.AsStoredUtc(p.PaymentDate)
                }).ToList(),
                AgentLogs = agentLogs
            };
        }
    }
}
