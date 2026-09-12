using backend.Data;
using backend.DTOs;
using backend.Models;
using backend.Models.Enums;
using Microsoft.EntityFrameworkCore;

namespace backend.Services
{
    public class TripRequestService : ITripRequestService
    {
        private readonly AppDbContext _db;

        public TripRequestService(AppDbContext db)
        {
            _db = db;
        }

        public async Task<TripRequestDto> CreateAsync(string customerId, TripRequestCreateDto dto)
        {
            // ── Validation ──
            if (dto.TravellerCount < 1 || dto.TravellerCount > 100)
            {
                throw new ArgumentException("Traveller count must be between 1 and 100.");
            }

            if (dto.BudgetCeiling <= 0)
            {
                throw new ArgumentException("Budget ceiling must be greater than zero.");
            }

            // ── Preference Validation (Component A) ──
            // Cross-validate the incoming TripRequest against the customer's stored
            // Preference row (if one exists). Failures throw ArgumentException, which
            // the controller catches and converts to 400 Bad Request — exactly the
            // same pattern as the checks above.
            var preference = await _db.Preferences
                .FirstOrDefaultAsync(p => p.CustomerId == customerId);

            if (preference != null)
            {
                // Reject if the trip's budget ceiling is below the customer's minimum budget.
                // Only enforced when BudgetMin is a meaningful positive value.
                if (preference.BudgetMin > 0 && dto.BudgetCeiling < preference.BudgetMin)
                {
                    throw new ArgumentException(
                        $"Budget ceiling ({dto.BudgetCeiling:F2} {dto.Currency}) is below your " +
                        $"preferred minimum budget ({preference.BudgetMin:F2} {preference.Currency}). " +
                        $"Please raise your budget ceiling or update your preferences (BudgetMin).");
                }
            }

            // Date checks run unconditionally for every trip request,
            // regardless of whether the customer has a Preference row.

            // Reject if StartDate is in the past (UTC date-only comparison).
            if (dto.StartDate.Date < DateTime.UtcNow.Date)
            {
                throw new ArgumentException(
                    $"Start date ({dto.StartDate:yyyy-MM-dd}) cannot be in the past. " +
                    $"Today's date (UTC) is {DateTime.UtcNow:yyyy-MM-dd}.");
            }

            // Reject if StartDate is not strictly before EndDate.
            if (dto.StartDate.Date >= dto.EndDate.Date)
            {
                throw new ArgumentException(
                    $"Start date ({dto.StartDate:yyyy-MM-dd}) must be strictly before " +
                    $"end date ({dto.EndDate:yyyy-MM-dd}).");
            }

            // If DestinationId is provided, verify it exists
            if (dto.DestinationId.HasValue)
            {
                var destinationExists = await _db.Destinations.AnyAsync(d => d.Id == dto.DestinationId.Value);
                if (!destinationExists)
                {
                    throw new ArgumentException("The specified destination does not exist.");
                }
            }

            var tripRequest = new TripRequest
            {
                CustomerId = customerId,
                DestinationId = dto.DestinationId,
                RawRequestText = dto.RawRequestText,
                StartDate = dto.StartDate,
                EndDate = dto.EndDate,
                TravellerCount = dto.TravellerCount,
                BudgetCeiling = dto.BudgetCeiling,
                Currency = dto.Currency,
                Status = TripRequestStatus.Pending,
                RetryCount = 0,
                CreatedAt = DateTime.UtcNow
            };

            _db.TripRequests.Add(tripRequest);
            await _db.SaveChangesAsync();

            // Reload with navigation
            var created = await _db.TripRequests
                .Include(t => t.Destination)
                .FirstAsync(t => t.Id == tripRequest.Id);

            return MapToDto(created);
        }

        public async Task<List<TripRequestDto>> GetByCustomerIdAsync(string customerId, int page, int pageSize)
        {
            return await _db.TripRequests
                .Include(t => t.Destination)
                .Where(t => t.CustomerId == customerId)
                .OrderByDescending(t => t.CreatedAt)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(t => MapToDto(t))
                .ToListAsync();
        }

        public async Task<int> GetCountByCustomerIdAsync(string customerId)
        {
            return await _db.TripRequests.CountAsync(t => t.CustomerId == customerId);
        }

        public async Task<TripRequestDto?> GetByIdAsync(int tripRequestId)
        {
            var trip = await _db.TripRequests
                .Include(t => t.Destination)
                .FirstOrDefaultAsync(t => t.Id == tripRequestId);

            return trip == null ? null : MapToDto(trip);
        }

        public async Task<TripRequestDto?> GetStatusAsync(int tripRequestId, string customerId)
        {
            var trip = await _db.TripRequests
                .Include(t => t.Destination)
                .FirstOrDefaultAsync(t => t.Id == tripRequestId && t.CustomerId == customerId);

            return trip == null ? null : MapToDto(trip);
        }

        public async Task<TripRequestDto?> CancelAsync(int tripRequestId, string customerId)
        {
            var trip = await _db.TripRequests
                .Include(t => t.Destination)
                .FirstOrDefaultAsync(t => t.Id == tripRequestId && t.CustomerId == customerId);

            if (trip == null) return null;

            // Only allow cancellation for requests that haven't been completed or already cancelled
            var nonCancellableStatuses = new[]
            {
                TripRequestStatus.Cancelled,
                TripRequestStatus.Approved,
                TripRequestStatus.Rejected
            };

            if (nonCancellableStatuses.Contains(trip.Status))
            {
                throw new InvalidOperationException(
                    $"Cannot cancel a trip request with status '{trip.Status}'.");
            }

            trip.Status = TripRequestStatus.Cancelled;
            await _db.SaveChangesAsync();

            return MapToDto(trip);
        }

        public async Task<List<AgentLogDto>> GetAgentLogsAsync(int tripRequestId, string customerId)
        {
            // Verify ownership
            var ownsTrip = await _db.TripRequests
                .AnyAsync(t => t.Id == tripRequestId && t.CustomerId == customerId);

            if (!ownsTrip)
            {
                return new List<AgentLogDto>();
            }

            return await _db.AgentLogs
                .Where(a => a.TripRequestId == tripRequestId)
                .OrderBy(a => a.Timestamp)
                .Select(a => new AgentLogDto
                {
                    Id = a.Id,
                    TripRequestId = a.TripRequestId,
                    AgentName = a.AgentName,
                    StepName = a.StepName,
                    Input = a.Input,
                    Output = a.Output,
                    Status = a.Status,
                    Timestamp = a.Timestamp
                })
                .ToListAsync();
        }

        public async Task<List<TripRequestDto>> SearchAsync(string? customerId, int? destinationId, string? status, string? sortBy, bool descending, int page, int pageSize)
        {
            var query = _db.TripRequests
                .Include(t => t.Destination)
                .AsQueryable();

            if (!string.IsNullOrWhiteSpace(customerId))
                query = query.Where(t => t.CustomerId == customerId);
            
            if (destinationId.HasValue)
                query = query.Where(t => t.DestinationId == destinationId.Value);

            if (!string.IsNullOrWhiteSpace(status) && Enum.TryParse<TripRequestStatus>(status, true, out var parsedStatus))
                query = query.Where(t => t.Status == parsedStatus);

            query = sortBy?.ToLower() switch
            {
                "startdate" => descending ? query.OrderByDescending(t => t.StartDate) : query.OrderBy(t => t.StartDate),
                "budget" => descending ? query.OrderByDescending(t => t.BudgetCeiling) : query.OrderBy(t => t.BudgetCeiling),
                _ => descending ? query.OrderByDescending(t => t.CreatedAt) : query.OrderBy(t => t.CreatedAt)
            };

            var trips = await query
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync();

            return trips.Select(MapToDto).ToList();
        }
        private static TripRequestDto MapToDto(TripRequest t)
        {
            return new TripRequestDto
            {
                Id = t.Id,
                CustomerId = t.CustomerId,
                DestinationId = t.DestinationId,
                DestinationName = t.Destination?.Name,
                RawRequestText = t.RawRequestText,
                StartDate = t.StartDate,
                EndDate = t.EndDate,
                TravellerCount = t.TravellerCount,
                BudgetCeiling = t.BudgetCeiling,
                Currency = t.Currency,
                Status = t.Status.ToString(),
                RetryCount = t.RetryCount,
                PlanJson = t.PlanJson,
                FailureReason = t.FailureReason,
                CreatedAt = t.CreatedAt
            };
        }
    }
}
