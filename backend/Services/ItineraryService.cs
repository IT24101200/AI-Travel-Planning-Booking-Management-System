using Microsoft.EntityFrameworkCore;
using backend.Data;
using backend.DTOs;
using backend.Models;
using backend.Models.Enums;

namespace backend.Services
{
    /// <summary>
    /// Implements itinerary management: CRUD for Itineraries and scheduling
    /// ItineraryItems with time-overlap validation and cost recalculation.
    /// </summary>
    public class ItineraryService : IItineraryService
    {
        private readonly AppDbContext _context;
        private readonly ICurrencyConversionService _currency;

        public ItineraryService(AppDbContext context, ICurrencyConversionService? currency = null)
        {
            _context = context;
            _currency = currency ?? new CurrencyConversionService();
        }

        /// <summary>
        /// Creates a new Itinerary in Draft status with TotalEstimatedCost = 0.
        /// </summary>
        public async Task<ItineraryDto> CreateItineraryAsync(
            string customerId, int tripRequestId,
            DateTime startDate, DateTime endDate, string currency)
        {
            var itinerary = new Itinerary
            {
                CustomerId       = customerId,
                TripRequestId    = tripRequestId,
                StartDate        = startDate,
                EndDate          = endDate,
                Status           = ItineraryStatus.Draft,
                TotalEstimatedCost = 0,
                Currency         = _currency.Normalize(currency),
                ExchangeRateToLkr = _currency.ExchangeRateToLkr(currency),
                CreatedAt        = DateTime.UtcNow
            };

            _context.Itineraries.Add(itinerary);
            await _context.SaveChangesAsync();

            return (await GetItineraryByIdAsync(itinerary.Id))!;
        }

        /// <summary>
        /// Retrieves one Itinerary by Id, including its ItineraryItems and each
        /// item's related Tour (for display purposes such as TourName).
        /// Returns null if the itinerary does not exist.
        /// </summary>
        public async Task<ItineraryDto?> GetItineraryByIdAsync(int itineraryId)
        {
            return await ReadItineraries()
                .FirstOrDefaultAsync(i => i.Id == itineraryId);
        }

        /// <summary>
        /// Returns all Itineraries belonging to the given customer,
        /// ordered by CreatedAt descending, with their items and tours loaded.
        /// </summary>
        public async Task<List<ItineraryDto>> GetItinerariesByCustomerAsync(string customerId)
        {
            return await ReadItineraries()
                .Where(i => i.CustomerId == customerId)
                .OrderByDescending(i => i.CreatedAt)
                .ToListAsync();
        }

        /// <summary>
        /// Adds a tour to an Itinerary as a new ItineraryItem.
        /// <para>
        /// Validation steps performed before creation:
        /// <list type="number">
        ///   <item>The parent Itinerary must exist.</item>
        ///   <item>The referenced Tour must exist and have Status == "Active".</item>
        ///   <item><b>Overlap check:</b> Fetches existing items on the same DayNumber
        ///         and rejects the request if the new item's [StartTime, EndTime)
        ///         overlaps any existing item's range. Two ranges overlap when
        ///         <c>newStart &lt; existingEnd AND newEnd &gt; existingStart</c>.</item>
        /// </list>
        /// </para>
        /// After a successful add, PriceAtSelection is snapshot from Tour.Price,
        /// and the parent Itinerary's TotalEstimatedCost is recalculated as the
        /// sum of all its items' PriceAtSelection values.
        /// </summary>
        public async Task<(bool Success, string? ErrorMessage, ItineraryDto? Data)>
            AddItemToItineraryAsync(int itineraryId, ItineraryItemCreateDto dto)
        {
            // 1. Validate itinerary exists
            var itinerary = await _context.Itineraries
                .Include(i => i.ItineraryItems)
                .FirstOrDefaultAsync(i => i.Id == itineraryId);

            if (itinerary is null)
                return (false, $"Itinerary with Id {itineraryId} was not found.", null);

            // 2. Validate tour exists and is active
            var tour = await _context.Tours.FindAsync(dto.TourId);
            if (tour is null)
                return (false, $"Tour with Id {dto.TourId} was not found.", null);

            if (tour.Status != "Active")
                return (false, $"Tour '{tour.Name}' (Id {tour.Id}) is not Active (current status: {tour.Status}).", null);

            // 3. Overlap check — two time ranges overlap when (newStart < existingEnd) AND (newEnd > existingStart)
            var sameDayItems = await _context.ItineraryItems
                .Where(item => item.ItineraryId == itineraryId && item.DayNumber == dto.DayNumber)
                .ToListAsync();

            var conflicting = sameDayItems.FirstOrDefault(existing =>
                dto.StartTime < existing.EndTime && dto.EndTime > existing.StartTime);

            if (conflicting is not null)
            {
                return (false,
                    $"Time conflict on Day {dto.DayNumber}: the requested range " +
                    $"{dto.StartTime}–{dto.EndTime} overlaps with existing item Id {conflicting.Id} " +
                    $"({conflicting.StartTime}–{conflicting.EndTime}).",
                    null);
            }

            // 4. Capture BEFORE Add() to avoid EF's automatic fixup double-counting the new item
            var existingItemsTotal = itinerary.ItineraryItems.Sum(item => item.PriceAtSelection);

            // 5. Create the ItineraryItem, snapshotting the tour's current price
            var newItem = new ItineraryItem
            {
                ItineraryId      = itineraryId,
                TourId           = dto.TourId,
                DayNumber        = dto.DayNumber,
                SequenceOrder    = dto.SequenceOrder,
                StartTime        = dto.StartTime,
                EndTime          = dto.EndTime,
                PriceAtSelection = _currency.Convert(tour.Price, tour.Currency, itinerary.Currency),
                Currency = itinerary.Currency
            };

            _context.ItineraryItems.Add(newItem);

            // 6. Recalculate total estimated cost (existing items + new item)
            itinerary.TotalEstimatedCost = existingItemsTotal + newItem.PriceAtSelection;

            await _context.SaveChangesAsync();

            return (true, null, await GetItineraryByIdAsync(itineraryId));
        }

        /// <summary>
        /// Removes the specified ItineraryItem if it belongs to the given Itinerary,
        /// then recalculates the parent Itinerary's TotalEstimatedCost.
        /// </summary>
        public async Task<(bool Success, string? ErrorMessage)>
            RemoveItemFromItineraryAsync(int itineraryId, int itineraryItemId)
        {
            var item = await _context.ItineraryItems
                .FirstOrDefaultAsync(i => i.Id == itineraryItemId && i.ItineraryId == itineraryId);

            if (item is null)
                return (false, $"ItineraryItem with Id {itineraryItemId} was not found in Itinerary {itineraryId}.");

            _context.ItineraryItems.Remove(item);

            // Recalculate: sum of remaining items (excluding the one being removed)
            var itinerary = await _context.Itineraries
                .Include(i => i.ItineraryItems)
                .FirstAsync(i => i.Id == itineraryId);

            itinerary.TotalEstimatedCost =
                itinerary.ItineraryItems
                    .Where(i => i.Id != itineraryItemId)
                    .Sum(i => i.PriceAtSelection);

            await _context.SaveChangesAsync();

            return (true, null);
        }

        /// <summary>
        /// Applies the allowed status transitions for staff and the owning customer.
        /// </summary>
        public async Task<ItineraryStatusUpdateResult> UpdateItineraryStatusAsync(
            int itineraryId, string? requestedStatus, string? actorCustomerId, bool isStaff)
        {
            var itinerary = await _context.Itineraries.FindAsync(itineraryId);

            if (itinerary is null)
                return new(ItineraryStatusUpdateOutcome.NotFound,
                    $"Itinerary with Id {itineraryId} was not found.");

            if (!isStaff && (string.IsNullOrWhiteSpace(actorCustomerId) || itinerary.CustomerId != actorCustomerId))
                return new(ItineraryStatusUpdateOutcome.Forbidden,
                    "You do not have access to this itinerary.");

            var statusName = Enum.GetNames<ItineraryStatus>()
                .FirstOrDefault(name => string.Equals(name, requestedStatus?.Trim(), StringComparison.OrdinalIgnoreCase));
            if (statusName is null)
                return new(ItineraryStatusUpdateOutcome.Invalid,
                    "Invalid itinerary status. Use Draft, Proposed, Accepted, or Discarded.");

            var newStatus = Enum.Parse<ItineraryStatus>(statusName);

            if (itinerary.Status is ItineraryStatus.Accepted or ItineraryStatus.Discarded)
                return new(ItineraryStatusUpdateOutcome.Invalid,
                    $"An itinerary in {itinerary.Status} status cannot be changed.");

            var allowed = isStaff
                ? itinerary.Status switch
                {
                    ItineraryStatus.Draft => newStatus is ItineraryStatus.Draft or ItineraryStatus.Proposed or ItineraryStatus.Accepted or ItineraryStatus.Discarded,
                    ItineraryStatus.Proposed => newStatus is ItineraryStatus.Draft or ItineraryStatus.Proposed or ItineraryStatus.Accepted or ItineraryStatus.Discarded,
                    _ => false
                }
                : itinerary.Status switch
                {
                    ItineraryStatus.Draft => newStatus == ItineraryStatus.Discarded,
                    ItineraryStatus.Proposed => newStatus is ItineraryStatus.Accepted or ItineraryStatus.Draft or ItineraryStatus.Discarded,
                    _ => false
                };

            if (!allowed)
                return new(ItineraryStatusUpdateOutcome.Invalid,
                    $"Cannot change itinerary status from {itinerary.Status} to {newStatus}.");

            if (isStaff && (newStatus == ItineraryStatus.Proposed || newStatus == ItineraryStatus.Accepted) && itinerary.Status == ItineraryStatus.Draft &&
                !await _context.ItineraryItems.AnyAsync(item => item.ItineraryId == itineraryId))
                return new(ItineraryStatusUpdateOutcome.Invalid,
                    "Cannot approve an itinerary with no activities.");

            itinerary.Status = newStatus;
            await _context.SaveChangesAsync();

            return new(ItineraryStatusUpdateOutcome.Updated,
                $"Itinerary status updated to {newStatus}.");
        }

        /// <summary>
        /// Returns all itineraries ordered by CreatedAt descending for review queue.
        /// </summary>
        public async Task<List<ItineraryDto>> GetAllItinerariesAsync()
        {
            return await ReadItineraries()
                .OrderByDescending(i => i.CreatedAt)
                .ToListAsync();
        }

        // Read-only projection shared by the list and detail endpoints.

        private IQueryable<ItineraryDto> ReadItineraries() =>
            from itinerary in _context.Itineraries.AsNoTracking()
            join customer in _context.Customers on itinerary.CustomerId equals customer.Id into customers
            from customer in customers.DefaultIfEmpty()
            join tripRequest in _context.TripRequests on itinerary.TripRequestId equals tripRequest.Id into tripRequests
            from tripRequest in tripRequests.DefaultIfEmpty()
            select new ItineraryDto
            {
                Id = itinerary.Id,
                CustomerId = itinerary.CustomerId,
                CustomerName = customer == null ? null : customer.FullName,
                TripRequestId = itinerary.TripRequestId,
                TravellerCount = tripRequest == null ? null : (int?)tripRequest.TravellerCount,
                StartDate = itinerary.StartDate,
                EndDate = itinerary.EndDate,
                Status = itinerary.Status,
                TotalEstimatedCost = itinerary.TotalEstimatedCost,
                Currency = itinerary.Currency,
                ExchangeRateToLkr = itinerary.ExchangeRateToLkr,
                CreatedAt = itinerary.CreatedAt,
                Items = itinerary.ItineraryItems.Select(item => new ItineraryItemDto
                {
                    Id = item.Id,
                    TourId = item.TourId,
                    TourName = item.Tour == null ? string.Empty : item.Tour.Name,
                    DayNumber = item.DayNumber,
                    SequenceOrder = item.SequenceOrder,
                    StartTime = item.StartTime,
                    EndTime = item.EndTime,
                    PriceAtSelection = item.PriceAtSelection
                    ,Currency = item.Currency
                }).ToList()
            };
    }
}
