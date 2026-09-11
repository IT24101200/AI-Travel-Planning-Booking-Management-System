using backend.Data;
using backend.DTOs;
using backend.Models;
using backend.Models.Enums;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace backend.Services
{
    public class ApprovalService : IApprovalService
    {
        private readonly AppDbContext _db;
        private readonly UserManager<IdentityUser> _userManager;

        public ApprovalService(AppDbContext db, UserManager<IdentityUser> userManager)
        {
            _db = db;
            _userManager = userManager;
        }

        public async Task<ApprovalDto> CreateApprovalAsync(string travelAgentUserId, ApprovalCreateDto dto)
        {
            if (dto == null)
                throw new ArgumentNullException(nameof(dto));

            var booking = await _db.Bookings.FindAsync(dto.BookingId);
            if (booking == null)
                throw new KeyNotFoundException($"Booking with ID {dto.BookingId} not found.");

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
                    booking.Status = BookingStatus.Confirmed;
                    break;
                case ApprovalDecision.Rejected:
                    booking.Status = BookingStatus.Rejected;
                    break;
                case ApprovalDecision.RevisionRequested:
                    booking.Status = BookingStatus.AwaitingApproval;
                    break;
            }

            booking.UpdatedAt = DateTime.UtcNow;
            await _db.SaveChangesAsync();

            return new ApprovalDto
            {
                Id = approval.Id,
                BookingId = approval.BookingId,
                TravelAgentId = approval.TravelAgentId,
                TravelAgentName = travelAgent.FullName,
                Decision = approval.Decision,
                Comment = approval.Comment,
                DecidedAt = approval.DecidedAt
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
                DecidedAt = ba.DecidedAt
            });
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
                DecidedAt = ba.DecidedAt
            });
        }
    }
}
