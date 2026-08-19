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
            if (dto.StartDate.Date < DateTime.UtcNow.Date)
            {
                throw new ArgumentException("Start date cannot be in the past.");
            }

            if (dto.EndDate <= dto.StartDate)
            {
                throw new ArgumentException("End date must be after start date.");
            }

            if (dto.TravellerCount < 1 || dto.TravellerCount > 100)
            {
                throw new ArgumentException("Traveller count must be between 1 and 100.");
            }

            if (dto.BudgetCeiling <= 0)
            {
                throw new ArgumentException("Budget ceiling must be greater than zero.");
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
