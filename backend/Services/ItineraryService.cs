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

        public ItineraryService(AppDbContext context)
        {
            _context = context;
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
                Currency         = currency,
                CreatedAt        = DateTime.UtcNow
            };

            _context.Itineraries.Add(itinerary);
            await _context.SaveChangesAsync();

            return ToDto(itinerary);
        }

        /// <summary>
        /// Retrieves one Itinerary by Id, including its ItineraryItems and each
        /// item's related Tour (for display purposes such as TourName).
        /// Returns null if the itinerary does not exist.
        /// </summary>
        public async Task<ItineraryDto?> GetItineraryByIdAsync(int itineraryId)
        {
            var itinerary = await _context.Itineraries
                .Include(i => i.ItineraryItems)
                    .ThenInclude(item => item.Tour)
                .FirstOrDefaultAsync(i => i.Id == itineraryId);

            return itinerary is null ? null : ToDto(itinerary);
        }

        /// <summary>
        /// Returns all Itineraries belonging to the given customer,
        /// ordered by CreatedAt descending, with their items and tours loaded.
        /// </summary>
        public async Task<List<ItineraryDto>> GetItinerariesByCustomerAsync(string customerId)
        {
            var itineraries = await _context.Itineraries
                .Where(i => i.CustomerId == customerId)
                .Include(i => i.ItineraryItems)
                    .ThenInclude(item => item.Tour)
                .OrderByDescending(i => i.CreatedAt)
                .ToListAsync();

            return itineraries.Select(i => ToDto(i)).ToList();
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
                PriceAtSelection = tour.Price
            };

            _context.ItineraryItems.Add(newItem);

            // 6. Recalculate total estimated cost (existing items + new item)
            itinerary.TotalEstimatedCost = existingItemsTotal + newItem.PriceAtSelection;

            await _context.SaveChangesAsync();

            // Reload with Tour navigation for the response DTO
            var updated = await _context.Itineraries
                .Include(i => i.ItineraryItems)
                    .ThenInclude(item => item.Tour)
                .FirstAsync(i => i.Id == itineraryId);

            return (true, null, ToDto(updated));
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
        /// Updates the Status of an existing Itinerary to the specified value.
        /// Returns failure if the Itinerary does not exist.
        /// </summary>
        public async Task<(bool Success, string? ErrorMessage)>
            UpdateItineraryStatusAsync(int itineraryId, ItineraryStatus newStatus)
        {
            var itinerary = await _context.Itineraries.FindAsync(itineraryId);

            if (itinerary is null)
                return (false, $"Itinerary with Id {itineraryId} was not found.");

            itinerary.Status = newStatus;
            await _context.SaveChangesAsync();

            return (true, null);
        }

        // ── Mapping helpers ──────────────────────────────────────────────────

        private static ItineraryDto ToDto(Itinerary i) => new ItineraryDto
        {
            Id                 = i.Id,
            CustomerId         = i.CustomerId,
            TripRequestId      = i.TripRequestId,
            StartDate          = i.StartDate,
            EndDate            = i.EndDate,
            Status             = i.Status,
            TotalEstimatedCost = i.TotalEstimatedCost,
            Currency           = i.Currency,
            CreatedAt          = i.CreatedAt,
            Items              = i.ItineraryItems?.Select(item => ToItemDto(item)).ToList()
                                 ?? new List<ItineraryItemDto>()
        };

        private static ItineraryItemDto ToItemDto(ItineraryItem item) => new ItineraryItemDto
        {
            Id               = item.Id,
            TourId           = item.TourId,
            TourName         = item.Tour?.Name ?? string.Empty,
            DayNumber        = item.DayNumber,
            SequenceOrder    = item.SequenceOrder,
            StartTime        = item.StartTime,
            EndTime          = item.EndTime,
            PriceAtSelection = item.PriceAtSelection
        };
    }
}
