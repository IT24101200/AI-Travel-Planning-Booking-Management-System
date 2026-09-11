using backend.DTOs;
using backend.Models.Enums;

namespace backend.Services
{
    /// <summary>
    /// Defines operations for managing Itineraries and their scheduled ItineraryItems.
    /// </summary>
    public interface IItineraryService
    {
        /// <summary>
        /// Creates a new Itinerary in Draft status with zero estimated cost.
        /// </summary>
        Task<ItineraryDto> CreateItineraryAsync(string customerId, int tripRequestId, DateTime startDate, DateTime endDate, string currency);

        /// <summary>
        /// Retrieves a single Itinerary by its Id, including child ItineraryItems
        /// and each item's related Tour. Returns null if not found.
        /// </summary>
        Task<ItineraryDto?> GetItineraryByIdAsync(int itineraryId);

        /// <summary>
        /// Returns all Itineraries belonging to the specified customer,
        /// ordered by CreatedAt descending.
        /// </summary>
        Task<List<ItineraryDto>> GetItinerariesByCustomerAsync(string customerId);

        /// <summary>
        /// Adds a tour to an Itinerary as a new ItineraryItem.
        /// Validates that the itinerary and tour exist, that the tour is Active,
        /// and that the new item's time range does not overlap any existing item
        /// on the same DayNumber.
        /// Returns a result tuple: (Success, ErrorMessage, UpdatedItinerary).
        /// </summary>
        Task<(bool Success, string? ErrorMessage, ItineraryDto? Data)> AddItemToItineraryAsync(int itineraryId, ItineraryItemCreateDto dto);

        /// <summary>
        /// Removes an ItineraryItem from its parent Itinerary and recalculates the total cost.
        /// Returns a result tuple: (Success, ErrorMessage).
        /// </summary>
        Task<(bool Success, string? ErrorMessage)> RemoveItemFromItineraryAsync(int itineraryId, int itineraryItemId);

        /// <summary>
        /// Updates the Status of an existing Itinerary.
        /// Returns a result tuple: (Success, ErrorMessage).
        /// </summary>
        Task<(bool Success, string? ErrorMessage)> UpdateItineraryStatusAsync(int itineraryId, ItineraryStatus newStatus);
    }
}
