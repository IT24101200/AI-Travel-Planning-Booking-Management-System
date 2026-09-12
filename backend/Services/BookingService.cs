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
        // True when running against PostgreSQL (production). False for SQLite/InMemory (tests).
        private bool IsPostgres => _db.Database.ProviderName?.Contains("Npgsql") == true;

        public BookingService(AppDbContext db)
        {
            _db = db;
        }

        public async Task<BookingDto> CreateBookingAsync(BookingCreateDto dto)
        {
            if (dto == null)
                throw new ArgumentNullException(nameof(dto));

            var customer = await _db.Customers.FindAsync(dto.CustomerId);
            if (customer == null)
                throw new KeyNotFoundException($"Customer with ID '{dto.CustomerId}' not found.");

            var itinerary = await _db.Itineraries.FindAsync(dto.ItineraryId);
            if (itinerary == null)
                throw new KeyNotFoundException($"Itinerary with ID {dto.ItineraryId} not found.");

            if (dto.Items == null || !dto.Items.Any())
                throw new ArgumentException("Booking must contain at least one item.");

            // Rule 6: Validate items
            decimal calculatedTotal = 0;
            var bookingItems = new List<BookingItem>();

            foreach (var item in dto.Items)
            {
                int fkCount = (item.TourId.HasValue ? 1 : 0) +
                              (item.RoomId.HasValue ? 1 : 0) +
                              (item.TransportOptionId.HasValue ? 1 : 0);

                if (fkCount != 1)
                {
                    throw new ArgumentException("BookingItem must have exactly one of TourId, RoomId, or TransportOptionId set matching ItemType.");
                }

                if (item.ItemType == BookingItemType.Room && (!item.CheckInDate.HasValue || !item.CheckOutDate.HasValue))
                {
                    throw new ArgumentException("CheckInDate and CheckOutDate are required when ItemType is Room.");
                }

                var subtotal = item.UnitPrice * item.Quantity;
                calculatedTotal += subtotal;

                bookingItems.Add(new BookingItem
                {
                    ItemType = item.ItemType,
                    TourId = item.TourId,
                    RoomId = item.RoomId,
                    TransportOptionId = item.TransportOptionId,
                    CheckInDate = item.CheckInDate,
                    CheckOutDate = item.CheckOutDate,
                    Quantity = item.Quantity,
                    UnitPrice = item.UnitPrice,
                    Subtotal = subtotal
                });
            }

            var totalCost = dto.TotalCost > 0 ? dto.TotalCost : calculatedTotal;
            var bookingRef = await GenerateUniqueBookingReferenceAsync();

            // ── Concurrency-safe write (Component C fix) ──
            // Open a REPEATABLE READ transaction and lock each requested Room row
            // with SELECT ... FOR UPDATE before re-checking availability.
            // This ensures only one of two simultaneous requests for the last
            // available unit can succeed: the second waits for the lock, then
            // re-counts and finds zero available, and receives a clear 400 error.
            await using var transaction = await _db.Database
                .BeginTransactionAsync(IsolationLevel.RepeatableRead);
            try
            {
                var activeStatuses = new[]
                {
                    BookingStatus.Draft,
                    BookingStatus.AwaitingApproval,
                    BookingStatus.Confirmed
                };

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

                    // Re-count overlapping active bookings under the lock —
                    // this read is now serialised with any concurrent writer.
                    var bookedCount = await _db.BookingItems
                        .Where(bi => bi.RoomId          == item.RoomId
                                  && bi.ItemType        == BookingItemType.Room
                                  && bi.CheckInDate.HasValue
                                  && bi.CheckOutDate.HasValue
                                  && bi.CheckInDate.Value  < item.CheckOutDate!.Value
                                  && bi.CheckOutDate.Value > item.CheckInDate!.Value
                                  && activeStatuses.Contains(bi.Booking.Status))
                        .SumAsync(bi => bi.Quantity);

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
                foreach (var item in dto.Items.Where(i => i.ItemType == BookingItemType.Transport))
                {
                    TransportOption? lockedTransport;
                    if (IsPostgres)
                    {
                        lockedTransport = await _db.TransportOptions
                            .FromSqlRaw(
                                "SELECT * FROM \"TransportOptions\" WHERE \"Id\" = {0} FOR UPDATE",
                                item.TransportOptionId!.Value)
                            .AsNoTracking()
                            .FirstOrDefaultAsync();
                    }
                    else
                    {
                        lockedTransport = await _db.TransportOptions
                            .AsNoTracking()
                            .FirstOrDefaultAsync(t => t.Id == item.TransportOptionId!.Value);
                    }

                    if (lockedTransport is null)
                        throw new KeyNotFoundException(
                            $"TransportOption with ID {item.TransportOptionId} not found.");

                    // Re-count active bookings for this transport option under the lock.
                    var bookedSeats = await _db.BookingItems
                        .Where(bi => bi.TransportOptionId == item.TransportOptionId
                                  && bi.ItemType          == BookingItemType.Transport
                                  && activeStatuses.Contains(bi.Booking.Status))
                        .SumAsync(bi => bi.Quantity);

                    var availableSeats = lockedTransport.Capacity - bookedSeats;
                    if (availableSeats < item.Quantity)
                        throw new InvalidOperationException(
                            $"TransportOption '{lockedTransport.Provider}: " +
                            $"{lockedTransport.RouteFrom} \u2192 {lockedTransport.RouteTo}' " +
                            $"(ID {lockedTransport.Id}) has insufficient capacity. " +
                            $"Requested: {item.Quantity}, available: {Math.Max(0, availableSeats)}.");
                }

                // Rule 1: Always created in AwaitingApproval (or Draft if explicitly specified, never Confirmed)
                var booking = new Booking
                {
                    BookingReference = bookingRef,
                    CustomerId       = dto.CustomerId,
                    ItineraryId      = dto.ItineraryId,
                    Status           = BookingStatus.AwaitingApproval,
                    TotalCost        = totalCost,
                    Currency         = string.IsNullOrWhiteSpace(dto.Currency) ? "USD" : dto.Currency,
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
            var booking = await GetBookingEntityQueryable().FirstOrDefaultAsync(b => b.Id == id);
            if (booking == null)
                throw new KeyNotFoundException($"Booking with ID {id} not found.");

            // Rule 1: Enforce valid status transition logic
            ValidateStatusTransition(booking.Status, newStatus);

            booking.Status = newStatus;
            booking.UpdatedAt = DateTime.UtcNow;

            await _db.SaveChangesAsync();
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
                .Include(b => b.BookingItems)
                    .ThenInclude(bi => bi.Tour)
                .Include(b => b.BookingItems)
                    .ThenInclude(bi => bi.Room)
                .Include(b => b.BookingItems)
                    .ThenInclude(bi => bi.TransportOption)
                .Include(b => b.BookingApprovals)
                    .ThenInclude(ba => ba.TravelAgent)
                .Include(b => b.Payments);
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
                Status = b.Status,
                TotalCost = b.TotalCost,
                Currency = b.Currency,
                CreatedAt = b.CreatedAt,
                UpdatedAt = b.UpdatedAt,
                BookingItems = b.BookingItems.Select(bi => new BookingItemDto
                {
                    Id = bi.Id,
                    BookingId = bi.BookingId,
                    ItemType = bi.ItemType,
                    TourId = bi.TourId,
                    TourName = bi.Tour?.Name,
                    RoomId = bi.RoomId,
                    TransportOptionId = bi.TransportOptionId,
                    CheckInDate = bi.CheckInDate,
                    CheckOutDate = bi.CheckOutDate,
                    Quantity = bi.Quantity,
                    UnitPrice = bi.UnitPrice,
                    Subtotal = bi.Subtotal
                }).ToList(),
                BookingApprovals = b.BookingApprovals.Select(ba => new ApprovalDto
                {
                    Id = ba.Id,
                    BookingId = ba.BookingId,
                    TravelAgentId = ba.TravelAgentId,
                    TravelAgentName = ba.TravelAgent?.FullName ?? string.Empty,
                    Decision = ba.Decision,
                    Comment = ba.Comment,
                    DecidedAt = ba.DecidedAt
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
                    PaymentDate = p.PaymentDate
                }).ToList(),
                AgentLogs = agentLogs
            };
        }
    }
}
