using backend.Data;
using backend.DTOs;
using backend.Models;
using backend.Models.Enums;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using System.Data;

namespace backend.Services
{
    public class ApprovalService : IApprovalService
    {
        private readonly AppDbContext _db;
        private readonly UserManager<IdentityUser> _userManager;
        private readonly IAgentLogStreamService? _logStream;
        private readonly INotificationService _notifications;

        public ApprovalService(
            AppDbContext db,
            UserManager<IdentityUser> userManager,
            IAgentLogStreamService? logStream = null,
            INotificationService? notifications = null)
        {
            _db = db;
            _userManager = userManager;
            _logStream = logStream;
            _notifications = notifications ?? new NotificationService(db);
        }

        public async Task<ApprovalDto> CreateApprovalAsync(string travelAgentUserId, ApprovalCreateDto dto)
        {
            if (dto == null)
                throw new ArgumentNullException(nameof(dto));

            await using var transaction = await _db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
            if (_db.Database.ProviderName?.Contains("Npgsql", StringComparison.OrdinalIgnoreCase) == true)
            {
                var tripId = await _db.Bookings.Where(b => b.Id == dto.BookingId)
                    .Select(b => b.Itinerary.TripRequestId).SingleOrDefaultAsync();
                await _db.Database.ExecuteSqlRawAsync("SELECT pg_advisory_xact_lock({0})", new object[] { tripId });
            }
            var booking = await _db.Bookings
                .Include(b => b.Itinerary)
                    .ThenInclude(i => i.TripRequest)
                .FirstOrDefaultAsync(b => b.Id == dto.BookingId);
            if (booking == null)
                throw new KeyNotFoundException($"Booking with ID {dto.BookingId} not found.");
            if (CustomerRevisionContract.Pending(CustomerRevisionContract.Read(booking.Itinerary.TripRequest)))
                throw new InvalidOperationException("The customer requested changes. Please review the revised proposal once planning finishes.");

            // Rule 1: Booking must be in AwaitingApproval status to receive human approval decision
            if (booking.Status != BookingStatus.AwaitingApproval)
            {
                throw new InvalidOperationException($"Cannot record approval for booking with status '{booking.Status}'. Booking must be in 'AwaitingApproval' status.");
            }

            // Ensure TravelAgent profile exists
            var travelAgent = await _db.TravelAgents.FindAsync(travelAgentUserId);
            if (travelAgent == null)
            {
                var identityUser = await _userManager.FindByIdAsync(travelAgentUserId);
                travelAgent = new TravelAgent
                {
                    Id = travelAgentUserId,
                    FullName = identityUser?.UserName ?? "Travel Agent",
                    Department = "Operations",
                    HireDate = DateTime.UtcNow
                };
                _db.TravelAgents.Add(travelAgent);
                await _db.SaveChangesAsync();
            }

            // Rule 4: BookingApproval rows are permanent audit trail (never edited or deleted)
            var approval = new BookingApproval
            {
                BookingId = dto.BookingId,
                TravelAgentId = travelAgentUserId,
                Decision = dto.Decision,
                Comment = dto.Comment ?? string.Empty,
                DecidedAt = DateTime.UtcNow
            };

            _db.BookingApprovals.Add(approval);

            // Update Booking status based on human decision
            switch (dto.Decision)
            {
                case ApprovalDecision.Approved:
                    await RoomInventory.ValidateConfirmationAsync(_db, booking.Id);
                    await TransportInventory.ValidateConfirmationAsync(_db, booking.Id);
                    booking.Status = BookingStatus.Confirmed;
                    booking.Itinerary.Status = ItineraryStatus.Accepted;
                    booking.Itinerary.TripRequest.Status = TripRequestStatus.Approved;
                    booking.Itinerary.TripRequest.FailureReason = null;
                    break;
                case ApprovalDecision.Rejected:
                    booking.Status = BookingStatus.Rejected;
                    booking.Itinerary.Status = ItineraryStatus.Discarded;
                    booking.Itinerary.TripRequest.Status = TripRequestStatus.Rejected;
                    break;
                case ApprovalDecision.RevisionRequested:
                    // Preserve this proposal and its audit history. A later agent callback
                    // creates a new itinerary/booking for the same TripRequest.
                    booking.Status = BookingStatus.Cancelled;
                    booking.Itinerary.Status = ItineraryStatus.Discarded;
                    booking.Itinerary.TripRequest.Status = TripRequestStatus.Planning;
                    booking.Itinerary.TripRequest.PlanJson = null;
                    booking.Itinerary.TripRequest.RetryCount = 0;
                    booking.Itinerary.TripRequest.FailureReason = dto.Comment;
                    break;
            }

            booking.UpdatedAt = DateTime.UtcNow;
            var trip = booking.Itinerary.TripRequest;
            var (messageType, content, eventKey) = dto.Decision switch
            {
                ApprovalDecision.Approved => (
                    MessageType.TripApproved,
                    "Your itinerary has been approved and your booking is confirmed.",
                    $"trip:{trip.Id}:approved"),
                ApprovalDecision.Rejected => (
                    MessageType.TripRejected,
                    "Your itinerary was not approved. You can submit a new trip request.",
                    $"trip:{trip.Id}:rejected"),
                ApprovalDecision.RevisionRequested => (
                    MessageType.TripRevisionRequested,
                    "Your itinerary needs changes. We are preparing a revised plan.",
                    $"trip:{trip.Id}:revision-requested:booking:{booking.Id}"),
                _ => throw new ArgumentOutOfRangeException()
            };
            await _notifications.CreateEventNotificationAsync(
                trip.CustomerId,
                messageType,
                content,
                "TripRequest",
                trip.Id.ToString(),
                eventKey);
            await _db.SaveChangesAsync();
            await transaction.CommitAsync();
            _logStream?.PublishTripStatus(
                booking.Itinerary.TripRequest.Id,
                booking.Itinerary.TripRequest.Status.ToString(),
                booking.Itinerary.TripRequest.FailureReason);

            return new ApprovalDto
            {
                Id = approval.Id,
                BookingId = approval.BookingId,
                TravelAgentId = approval.TravelAgentId,
                TravelAgentName = travelAgent.FullName,
                Decision = approval.Decision,
                Comment = approval.Comment,
                DecidedAt = DateTimeContract.AsStoredUtc(approval.DecidedAt)
            };
        }

        public async Task<IEnumerable<ApprovalDto>> GetApprovalsByBookingIdAsync(int bookingId)
        {
            var approvals = await _db.BookingApprovals
                .Include(ba => ba.TravelAgent)
                .Where(ba => ba.BookingId == bookingId)
                .OrderByDescending(ba => ba.DecidedAt)
                .ToListAsync();

            return approvals.Select(ba => new ApprovalDto
            {
                Id = ba.Id,
                BookingId = ba.BookingId,
                TravelAgentId = ba.TravelAgentId,
                TravelAgentName = ba.TravelAgent?.FullName ?? "Travel Agent",
                Decision = ba.Decision,
                Comment = ba.Comment,
                DecidedAt = DateTimeContract.AsStoredUtc(ba.DecidedAt)
            });
        }

        public async Task<int> GetTripRequestIdForBookingAsync(int bookingId)
        {
            var tripRequestId = await _db.Bookings
                .Where(b => b.Id == bookingId)
                .Select(b => (int?)b.Itinerary.TripRequestId)
                .SingleOrDefaultAsync();
            return tripRequestId ?? throw new KeyNotFoundException($"Booking with ID {bookingId} not found.");
        }

        public async Task<IEnumerable<ApprovalDto>> GetAllApprovalsAsync()
        {
            var approvals = await _db.BookingApprovals
                .Include(ba => ba.TravelAgent)
                .OrderByDescending(ba => ba.DecidedAt)
                .ToListAsync();

            return approvals.Select(ba => new ApprovalDto
            {
                Id = ba.Id,
                BookingId = ba.BookingId,
                TravelAgentId = ba.TravelAgentId,
                TravelAgentName = ba.TravelAgent?.FullName ?? "Travel Agent",
                Decision = ba.Decision,
                Comment = ba.Comment,
                DecidedAt = DateTimeContract.AsStoredUtc(ba.DecidedAt)
            });
        }
    }
}
