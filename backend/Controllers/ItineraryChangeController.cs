using System.Security.Claims;
using backend.DTOs;
using backend.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace backend.Controllers;

[ApiController, Authorize, Route("api/itinerary/{itineraryId:int}/changes")]
public sealed class ItineraryChangeController(ItineraryChangeService service) : ControllerBase
{
    [HttpGet("options")]
    public async Task<IActionResult> Options(int itineraryId, CancellationToken ct) =>
        await Handle(() => service.OptionsAsync(itineraryId, User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "", ct));

    [HttpPost]
    public async Task<IActionResult> RequestChanges(int itineraryId, ItineraryChangeRequestDto input, CancellationToken ct) =>
        await Handle(() => service.RequestAsync(itineraryId, User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "", input, Request.Headers.Authorization.ToString(), ct));

    private async Task<IActionResult> Handle<T>(Func<Task<T>> action)
    {
        try { return Ok(await action()); }
        catch (KeyNotFoundException ex) { return NotFound(new { message = ex.Message }); }
        catch (ArgumentException ex) { return BadRequest(new { message = ex.Message }); }
        catch (InvalidOperationException ex) { return Conflict(new { message = ex.Message }); }
        catch (HttpRequestException) { return StatusCode(503, new { message = "Road routing or the planning service is unavailable. Please retry." }); }
        catch (TaskCanceledException) { return StatusCode(503, new { message = "The planning service timed out. Please retry." }); }
    }
}
