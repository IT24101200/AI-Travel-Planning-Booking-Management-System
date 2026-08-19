using System.Security.Claims;
using backend.DTOs;
using backend.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace backend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class NotificationController : ControllerBase
    {
        private readonly INotificationService _notificationService;

        public NotificationController(INotificationService notificationService)
        {
            _notificationService = notificationService;
        }

        /// <summary>
        /// List notifications for the current customer with optional filters.
        /// </summary>
        [HttpGet]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> GetMyNotifications(
            [FromQuery] string? status,
            [FromQuery] DateTime? from,
            [FromQuery] DateTime? to,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 20)
        {
            if (page < 1) page = 1;
            if (pageSize < 1) pageSize = 20;
            if (pageSize > 100) pageSize = 100;

            var userId = GetUserId();
            var notifications = await _notificationService.GetByCustomerIdAsync(userId, status, from, to, page, pageSize);
            var totalCount = await _notificationService.GetCountAsync(userId, status, from, to);

            return Ok(new
            {
                data = notifications,
                totalCount,
                page,
                pageSize,
                totalPages = (int)Math.Ceiling((double)totalCount / pageSize)
            });
        }

        /// <summary>
        /// Mark a specific notification as read.
        /// </summary>
        [HttpPatch("{id}/read")]
        [ProducesResponseType(typeof(NotificationDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> MarkAsRead(Guid id)
        {
            var userId = GetUserId();
            var result = await _notificationService.MarkAsReadAsync(id, userId);

            if (result == null)
                return NotFound(new { message = "Notification not found." });

            return Ok(result);
        }

        /// <summary>
        /// Mark a specific notification as unread.
        /// </summary>
        [HttpPatch("{id}/unread")]
        [ProducesResponseType(typeof(NotificationDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> MarkAsUnread(Guid id)
        {
            var userId = GetUserId();
            var result = await _notificationService.MarkAsUnreadAsync(id, userId);

            if (result == null)
                return NotFound(new { message = "Notification not found." });

            return Ok(result);
        }

        /// <summary>
        /// Mark all notifications as read for the current customer.
        /// </summary>
        [HttpPost("mark-all-read")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> MarkAllAsRead()
        {
            var userId = GetUserId();
            var count = await _notificationService.MarkAllAsReadAsync(userId);

            return Ok(new { message = $"{count} notification(s) marked as read." });
        }

        /// <summary>
        /// Resend a failed notification.
        /// </summary>
        [HttpPost("{id}/resend")]
        [ProducesResponseType(typeof(NotificationDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> ResendFailed(Guid id)
        {
            var userId = GetUserId();

            try
            {
                var result = await _notificationService.ResendFailedAsync(id, userId);

                if (result == null)
                    return NotFound(new { message = "Notification not found." });

                return Ok(result);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        private string GetUserId()
        {
            return User.FindFirstValue(ClaimTypes.NameIdentifier)
                ?? throw new UnauthorizedAccessException("User ID not found in token.");
        }
    }
}
