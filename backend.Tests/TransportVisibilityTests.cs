using System.Security.Claims;
using backend.Controllers;
using backend.Data;
using backend.Models;
using backend.Models.Enums;
using backend.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace backend.Tests;

public class TransportVisibilityTests
{
    private static AppDbContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new AppDbContext(options);
    }

    private static TransportController CreateController(
        AppDbContext context,
        params string[] roles)
    {
        var identity = new ClaimsIdentity(
            roles.Select(role => new Claim(ClaimTypes.Role, role)),
            authenticationType: roles.Length == 0 ? null : "Test");
        return new TransportController(
            new TransportService(context),
            new AvailabilityService(context))
        {
            ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext
                {
                    User = new ClaimsPrincipal(identity)
                }
            }
        };
    }

    private static async Task SeedAsync(AppDbContext context)
    {
        context.TransportOptions.AddRange(
            new TransportOption
            {
                Id = 1,
                Type = TransportType.Bus,
                Provider = "Active Bus",
                RouteFrom = "Colombo",
                RouteTo = "Kandy",
                DepartureTime = new DateTime(2026, 10, 10, 8, 0, 0),
                ArrivalTime = new DateTime(2026, 10, 10, 10, 0, 0),
                Capacity = 20,
                Price = 100,
                Status = TransportStatus.Active
            },
            new TransportOption
            {
                Id = 2,
                Type = TransportType.Train,
                Provider = "Inactive Train",
                RouteFrom = "Colombo",
                RouteTo = "Kandy",
                DepartureTime = new DateTime(2026, 10, 11, 8, 0, 0),
                ArrivalTime = new DateTime(2026, 10, 11, 11, 0, 0),
                Capacity = 20,
                Price = 120,
                Status = TransportStatus.Inactive
            });
        await context.SaveChangesAsync();
    }

    [Fact]
    public async Task AnonymousListAndAllStatusNeverExposeInactiveInventory()
    {
        await using var context = CreateContext();
        await SeedAsync(context);

        var result = await CreateController(context).Search(
            null, null, null, null, null, "All", null, false, 1, 50, null);

        var ok = Assert.IsType<OkObjectResult>(result);
        var payload = System.Text.Json.JsonSerializer.SerializeToDocument(ok.Value).RootElement;
        Assert.Equal(1, payload.GetProperty("totalCount").GetInt32());
        Assert.DoesNotContain("Inactive Train", payload.GetProperty("data").ToString());
    }

    [Fact]
    public async Task AnonymousDirectAndAvailabilityReadsHideInactiveInventory()
    {
        await using var context = CreateContext();
        await SeedAsync(context);
        var controller = CreateController(context);

        Assert.IsType<NotFoundResult>(await controller.GetById(2));
        Assert.IsType<NotFoundResult>(await controller.CheckAvailability(2));
    }

    [Fact]
    public async Task StaffCanExplicitlyReadInactiveInventory()
    {
        await using var context = CreateContext();
        await SeedAsync(context);
        var controller = CreateController(context, "TravelAgent");

        var result = await controller.Search(
            null, null, null, null, null, "Inactive", null, false, 1, 50, null);

        var ok = Assert.IsType<OkObjectResult>(result);
        var payload = System.Text.Json.JsonSerializer.SerializeToDocument(ok.Value).RootElement;
        Assert.Equal(1, payload.GetProperty("totalCount").GetInt32());
        Assert.Contains("Inactive Train", payload.GetProperty("data").ToString());
        Assert.IsType<OkObjectResult>(await controller.GetById(2));
        Assert.IsType<OkObjectResult>(await controller.CheckAvailability(2));
    }

    [Fact]
    public async Task InvalidEnumFiltersReturnBadRequest()
    {
        await using var context = CreateContext();
        await SeedAsync(context);
        var controller = CreateController(context);

        Assert.IsType<BadRequestObjectResult>(await controller.Search(
            "garbage", null, null, null, null, null, null, false, 1, 10, null));
        Assert.IsType<BadRequestObjectResult>(await controller.Search(
            null, null, null, null, null, "garbage", null, false, 1, 10, null));
    }
}
