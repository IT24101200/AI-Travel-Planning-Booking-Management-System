using backend.Data;
using backend.DTOs;
using backend.Models;
using backend.Models.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using System.Data;
using System.Text.Json;

namespace backend.Services
{
    public class TripRequestService : ITripRequestService
    {
        private readonly AppDbContext _db;
        private readonly ICurrencyConversionService _currency;
        private readonly IAgentLogStreamService? _logStream;

        public TripRequestService(
            AppDbContext db,
            ICurrencyConversionService? currency = null,
            IAgentLogStreamService? logStream = null)
        {
            _db = db;
            _currency = currency ?? new CurrencyConversionService();
            _logStream = logStream;
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

            dto.Currency = _currency.Normalize(dto.Currency);

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
                var preferredMinimum = _currency.Convert(preference.BudgetMin, preference.Currency, dto.Currency);
                if (preference.BudgetMin > 0 && dto.BudgetCeiling < preferredMinimum)
                {
                    throw new ArgumentException(
                        $"Budget ceiling ({dto.BudgetCeiling:F2} {dto.Currency}) is below your " +
                        $"preferred minimum budget ({preferredMinimum:F2} {dto.Currency}). " +
                        $"Please raise your budget ceiling or update your preferences (BudgetMin).");
                }
            }

            // Ensure dates are parsed as UTC for PostgreSQL timestamptz compatibility
            var startUtc = dto.StartDate.Kind == DateTimeKind.Unspecified
                ? DateTime.SpecifyKind(dto.StartDate, DateTimeKind.Utc)
                : dto.StartDate.ToUniversalTime();

            var endUtc = dto.EndDate.Kind == DateTimeKind.Unspecified
                ? DateTime.SpecifyKind(dto.EndDate, DateTimeKind.Utc)
                : dto.EndDate.ToUniversalTime();

            // Date checks run unconditionally for every trip request,
            // regardless of whether the customer has a Preference row.

            // Reject if StartDate is in the past (UTC date-only comparison).
            if (startUtc.Date < DateTime.UtcNow.Date)
            {
                throw new ArgumentException(
                    $"Start date ({startUtc:yyyy-MM-dd}) cannot be in the past. " +
                    $"Today's date (UTC) is {DateTime.UtcNow:yyyy-MM-dd}.");
            }

            // Reject if StartDate is not strictly before EndDate.
            if (startUtc.Date >= endUtc.Date)
            {
                throw new ArgumentException(
                    $"Start date ({startUtc:yyyy-MM-dd}) must be strictly before " +
                    $"end date ({endUtc:yyyy-MM-dd}).");
            }

            var destinationIds = NormalizeDestinationIds(dto);
            var destinationEntities = destinationIds.Count == 0
                ? new List<Destination>()
                : await _db.Destinations
                    .Where(d => destinationIds.Contains(d.Id))
                    .ToListAsync();

            // Validate the complete structured list before persisting anything.
            if (destinationEntities.Count != destinationIds.Count)
            {
                var foundIds = destinationEntities.Select(d => d.Id).ToHashSet();
                var missingIds = destinationIds.Where(id => !foundIds.Contains(id));
                throw new ArgumentException(
                    $"The specified destination(s) do not exist: {string.Join(", ", missingIds)}.");
            }

            var destinationsById = destinationEntities.ToDictionary(d => d.Id);
            var selections = destinationIds
                .Select((id, order) => new TripRequestDestinationSelection
                {
                    Id = id,
                    Name = destinationsById[id].Name,
                    Order = order
                })
                .ToList();

            var tripRequest = new TripRequest
            {
                CustomerId = customerId,
                // Preserve the first selection for legacy singular consumers.
                DestinationId = destinationIds.Count == 0 ? null : destinationIds[0],
                DestinationSelectionsJson = selections.Count == 0
                    ? null
                    : JsonSerializer.Serialize(selections),
                RawRequestText = dto.RawRequestText,
                StartDate = startUtc,
                EndDate = endUtc,
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
            // Keep cancellation and the related state changes in one transaction.
            // InMemory is used by a few unit tests and does not support transactions.
            IDbContextTransaction? transaction = null;
            if (_db.Database.IsRelational())
            {
                transaction = await _db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
                if (_db.Database.ProviderName?.Contains("Npgsql", StringComparison.OrdinalIgnoreCase) == true)
                {
                    await _db.Database.ExecuteSqlRawAsync(
                        "SELECT pg_advisory_xact_lock({0})", new object[] { tripRequestId });
                }
            }

            try
            {
                var trip = await _db.TripRequests
                    .Include(t => t.Destination)
                    .FirstOrDefaultAsync(t => t.Id == tripRequestId && t.CustomerId == customerId);

                if (trip == null) return null;

                if (!IsCustomerCancellableStatus(trip.Status))
                {
                    throw new InvalidOperationException(trip.Status switch
                    {
                        TripRequestStatus.Cancelled => "This trip has already been cancelled.",
                        TripRequestStatus.Failed or TripRequestStatus.Rejected => "This trip can no longer be cancelled.",
                        _ => $"This trip can no longer be cancelled (current status: {trip.Status})."
                    });
                }

                var cancellationCutoff = DateTime.UtcNow.Date.AddDays(3);
                if (trip.StartDate.Date < cancellationCutoff)
                {
                    throw new InvalidOperationException(
                        "Trips can only be cancelled at least 3 days before the start date.");
                }

                var itineraries = await _db.Itineraries
                    .Where(i => i.TripRequestId == tripRequestId)
                    .Include(i => i.ItineraryItems)
                    .ToListAsync();
                var itineraryIds = itineraries.Select(i => i.Id).ToList();
                var bookings = itineraryIds.Count == 0
                    ? new List<Booking>()
                    : await _db.Bookings
                        .Where(b => itineraryIds.Contains(b.ItineraryId))
                        .Include(b => b.Payments)
                        .ToListAsync();

                // Validate every related record before mutating anything.
                foreach (var booking in bookings)
                {
                    if (booking.Payments.Any(payment => payment.Status == PaymentStatus.Paid))
                    {
                        throw new InvalidOperationException(
                            "This booking has already been paid and cannot be cancelled automatically. Please contact support.");
                    }

                    if (booking.Status == BookingStatus.Completed)
                    {
                        throw new InvalidOperationException(
                            "This completed trip can no longer be cancelled.");
                    }
                }

                trip.Status = TripRequestStatus.Cancelled;
                trip.FailureReason = null;

                foreach (var itinerary in itineraries.Where(i => i.Status is ItineraryStatus.Draft or ItineraryStatus.Proposed or ItineraryStatus.Accepted))
                {
                    // The domain has no separate Itinerary.Cancelled status; Discarded
                    // is the existing non-actionable historical state.
                    itinerary.Status = ItineraryStatus.Discarded;
                }

                foreach (var booking in bookings.Where(b => b.Status is BookingStatus.Draft or BookingStatus.AwaitingApproval or BookingStatus.Confirmed))
                {
                    booking.Status = BookingStatus.Cancelled;
                    booking.UpdatedAt = DateTime.UtcNow;
                }

                await _db.SaveChangesAsync();
                if (transaction != null) await transaction.CommitAsync();
                _logStream?.PublishTripStatus(trip.Id, trip.Status.ToString(), trip.FailureReason);
                return MapToDto(trip);
            }
            catch
            {
                if (transaction != null) await transaction.RollbackAsync();
                throw;
            }
            finally
            {
                if (transaction != null) await transaction.DisposeAsync();
            }
        }

        private static bool IsCustomerCancellableStatus(TripRequestStatus status) =>
            status is TripRequestStatus.Pending or
                TripRequestStatus.Planning or
                TripRequestStatus.Planned or
                TripRequestStatus.AwaitingApproval or
                TripRequestStatus.Approved;

        public async Task<List<AgentLogDto>> GetAgentLogsAsync(int tripRequestId, string? customerId)
        {
            // If customerId is provided (regular customer), verify ownership.
            // If customerId is null/empty (staff/agent), allow access to logs.
            if (!string.IsNullOrEmpty(customerId))
            {
                var ownsTrip = await _db.TripRequests
                    .AnyAsync(t => t.Id == tripRequestId && t.CustomerId == customerId);

                if (!ownsTrip)
                {
                    return new List<AgentLogDto>();
                }
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

        public async Task<AgentLogDto> AddAgentLogAsync(AgentLogCreateDto dto)
        {
            var log = new AgentLog
            {
                TripRequestId = dto.TripRequestId,
                AgentName = dto.AgentName,
                StepName = dto.StepName,
                Input = dto.Input,
                Output = dto.Output,
                Status = string.IsNullOrWhiteSpace(dto.Status) ? "Success" : dto.Status,
                Timestamp = dto.Timestamp ?? DateTime.UtcNow
            };

            _db.AgentLogs.Add(log);
            await _db.SaveChangesAsync();
            var result = new AgentLogDto
            {
                Id = log.Id,
                TripRequestId = log.TripRequestId,
                AgentName = log.AgentName,
                StepName = log.StepName,
                Input = log.Input,
                Output = log.Output,
                Status = log.Status,
                Timestamp = log.Timestamp
            };
            _logStream?.PublishAgentLog(result);
            return result;
        }

        public async Task<TripRequestDto?> UpdateAgentPlanAsync(int tripRequestId, TripRequestAgentUpdateDto dto)
        {
            var trip = await _db.TripRequests
                .Include(t => t.Destination)
                .FirstOrDefaultAsync(t => t.Id == tripRequestId);

            if (trip == null) return null;

            var parsedStatus = trip.Status;
            if (!string.IsNullOrWhiteSpace(dto.Status) && !Enum.TryParse<TripRequestStatus>(dto.Status, true, out parsedStatus))
            {
                throw new ArgumentException($"Unknown TripRequest status '{dto.Status}'.");
            }

            if (!string.IsNullOrWhiteSpace(dto.Status))
            {
                if (!IsAllowedAgentTransition(trip.Status, parsedStatus))
                    throw new InvalidOperationException($"Agent cannot transition TripRequest from {trip.Status} to {parsedStatus}.");

                if (parsedStatus == TripRequestStatus.Failed && string.IsNullOrWhiteSpace(dto.FailureReason))
                    throw new ArgumentException("A failure reason is required when an agent marks a request as Failed.");

                if (parsedStatus == TripRequestStatus.AwaitingApproval && !dto.PlanJson.HasValue)
                    throw new ArgumentException("A plan is required before a request can enter AwaitingApproval.");

                trip.Status = parsedStatus;
                if (parsedStatus == TripRequestStatus.Planning)
                    trip.FailureReason = null;
            }

            if (dto.PlanJson.HasValue)
            {
                trip.PlanJson = dto.PlanJson.Value.GetRawText();
            }

            if (dto.RetryCount.HasValue)
            {
                trip.RetryCount = dto.RetryCount.Value;
            }

            if (dto.FailureReason != null)
            {
                trip.FailureReason = dto.FailureReason;
            }

            await _db.SaveChangesAsync();
            var result = MapToDto(trip);
            if (!string.IsNullOrWhiteSpace(dto.Status))
                _logStream?.PublishTripStatus(trip.Id, result.Status, result.FailureReason);
            return result;
        }

        private static bool IsAllowedAgentTransition(TripRequestStatus current, TripRequestStatus next)
        {
            return current switch
            {
                TripRequestStatus.Pending => next is TripRequestStatus.Planning or TripRequestStatus.AwaitingApproval or TripRequestStatus.Failed,
                TripRequestStatus.Planning => next is TripRequestStatus.Planning or TripRequestStatus.Planned or TripRequestStatus.AwaitingApproval or TripRequestStatus.Failed,
                TripRequestStatus.Planned => next is TripRequestStatus.AwaitingApproval or TripRequestStatus.Failed,
                TripRequestStatus.Failed => next is TripRequestStatus.Planning,
                _ => false
            };
        }

        private static TripRequestDto MapToDto(TripRequest t)
        {
            var selections = ParseDestinationSelections(t);
            var primary = selections.FirstOrDefault(selection => selection.Id == t.DestinationId)
                ?? selections.FirstOrDefault();
            var destinationId = t.DestinationId ?? primary?.Id;
            return new TripRequestDto
            {
                Id = t.Id,
                CustomerId = t.CustomerId,
                DestinationId = destinationId,
                DestinationName = t.Destination?.Name ?? primary?.Name,
                DestinationIds = selections.Select(selection => selection.Id).ToList(),
                DestinationNames = selections.Select(selection => selection.Name).ToList(),
                Destinations = selections
                    .Select(selection => new TripRequestDestinationDto
                    {
                        Id = selection.Id,
                        Name = selection.Name,
                        Order = selection.Order
                    })
                    .ToList(),
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

        private static List<int> NormalizeDestinationIds(TripRequestCreateDto dto)
        {
            var ids = new List<int>();

            void Add(int id)
            {
                if (id <= 0)
                    throw new ArgumentException("Destination IDs must be positive database IDs.");
                if (!ids.Contains(id)) ids.Add(id);
            }

            foreach (var destination in dto.Destinations ?? new List<TripRequestDestinationInputDto>())
                Add(destination.Id);

            foreach (var id in dto.DestinationIds ?? new List<int>())
                Add(id);

            if (dto.DestinationId.HasValue)
            {
                if (dto.DestinationId.Value <= 0)
                    throw new ArgumentException("Destination IDs must be positive database IDs.");
                if (!ids.Contains(dto.DestinationId.Value))
                    ids.Insert(0, dto.DestinationId.Value);
            }

            return ids;
        }

        private static List<TripRequestDestinationSelection> ParseDestinationSelections(TripRequest t)
        {
            if (!string.IsNullOrWhiteSpace(t.DestinationSelectionsJson))
            {
                try
                {
                    var parsed = JsonSerializer.Deserialize<List<TripRequestDestinationSelection>>(
                        t.DestinationSelectionsJson);
                    if (parsed is not null && parsed.Count > 0)
                        return parsed.OrderBy(selection => selection.Order).ToList();
                }
                catch (JsonException)
                {
                    // Fall back to the legacy FK below for old/corrupt rows.
                }
            }

            return t.DestinationId.HasValue
                ? new List<TripRequestDestinationSelection>
                {
                    new()
                    {
                        Id = t.DestinationId.Value,
                        Name = t.Destination?.Name ?? string.Empty,
                        Order = 0
                    }
                }
                : new List<TripRequestDestinationSelection>();
        }
    }
}
